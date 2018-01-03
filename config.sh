#!/bin/bash
# -------------------------------------------------------------------------------
# Filename:    config.sh
# Revision:    1.0
# Date:        2017/06/21
# Author:      Qin Boqin
# Email:       bobbqqin#gmail.com
# Description: Config openstack
# Notes:       This plugin uses the "sed" command
# -------------------------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root"
  exit
fi

function usage()
{
  echo "config.sh {setuprc|stackrc|network|mysql|mongo|keystone|glance|cinder|nova|neutron|ceilometer}"
}

if [[ $# -ne 1 ]]; then
  usage
  exit 1
fi

if [[ ! "$1" =~ ^(setuprc|stackrc|network|mysql|mongo|keystone|glance|cinder|nova|neutron|ceilometer)$ ]]; then
  usage
  exit 1
fi

function conf_setuprc()
{
file="setup.ini"
if [ ! -f "$file" ]; then
  echo $file not exits
  exit 1
fi
. $file
cat > setuprc <<EOF
# set up env variables for install
export OS_TENANT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=$password
export OS_AUTH_URL="http://$rigip:5000/v2.0/"
export OS_REGION_NAME=$region
export SG_SERVICE_CONTROLLER_IP=$rigip
export SG_SERVICE_CONTROLLER_NIC=$rignic
export SG_SERVICE_TENANT_NAME=service
export SG_SERVICE_EMAIL=$email
export SG_SERVICE_PASSWORD=$password
export SG_SERVICE_TOKEN=$token
export SG_SERVICE_REGION=$region
export LOOPSIZE=$loopsize
EOF
}

function conf_stackrc()
{
file="setuprc"
if [ ! -f "$file" ]; then
  echo $file not exits
  exit 1
fi
. $file

# some vars from the SG setup file getting locally reassigned 
local password=$SG_SERVICE_PASSWORD
local email=$SG_SERVICE_EMAIL
local token=$SG_SERVICE_TOKEN
local region=$SG_SERVICE_REGION
local managementip=$SG_SERVICE_CONTROLLER_IP

cat > stackrc <<EOF
# =================set env variables=================
export OS_TENANT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=$password
export OS_AUTH_URL="http://$managementip:5000/v2.0/"
export OS_REGION_NAME=$region

export ADMIN_PASSWORD=$password
export OS_ADMIN_PASSWORD=$password

export SERVICE_PASSWORD=$password
export OS_SERVICE_PASSWORD=$password

export SERVICE_TOKEN=$token
export OS_SERVICE_TOKEN=$token

export SERVICE_ENDPOINT="http://$managementip:35357/v2.0"
export OS_SERVICE_ENDPOINT="http://$managementip:35357/v2.0"

export SERVICE_TENANT_NAME=service
export OS_SERVICE_TENANT_NAME=service

export KEYSTONE_REGION=$region
export OS_KEYSTONE_REGION=$region
EOF
}

function save_restore()
{
  local confFile
  for confFile in "$@"
  do
    if [ -f "$confFile".orig ]; then
      echo "Original backup of "$confFile".orig exists. Your current configs will be modified by this script."
      cp "$confFile".orig "$confFile"
    else
      cp "$confFile" "$confFile".orig
  fi
  done
}

function conf_network()
{
# turn on forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward
sysctl net.ipv4.ip_forward=1

# modify timeserver configuration
local confFile="/etc/ntp.conf"

save_restore $confFile ;

sed -e "
/^server ntp.ubuntu.com/i server 127.127.1.0
/^server ntp.ubuntu.com/i fudge 127.127.1.0 stratum 10
/^server ntp.ubuntu.com/s/^.*$/server ntp.ubutu.com iburst/;
" -i $confFile
}

function conf_mysql()
{
local confFile="/etc/mysql/my.cnf"
local confFile2="/etc/mysql/conf.d/openstack.cnf"

if [ ! -f "$confFile2" ]; then
  touch "$confFile2"
fi

save_restore $confFile $confFile2

# make mysql listen on 0.0.0.0
sed -i '/^bind-address/s/127.0.0.1/0.0.0.0/g' $confFile

echo "
[mysqld]
default-storage-engine = innodb
innodb_file_per_table
collation-server = utf8_general_ci
init-connect = 'SET NAMES utf8'
character-set-server = utf8
" >> $confFile2
}

function conf_mongo()
{
file="setuprc"
if [ ! -f "$file" ]; then
  echo $file not exits
  exit 1
fi
. $file

local managementip=$SG_SERVICE_CONTROLLER_IP
local password=$SG_SERVICE_PASSWORD

local confFile="/etc/mongodb.conf"

save_restore $confFile

sed -e "
/^bind_ip =.*$/s/^.*$/bind_ip = $managementip/
" -i $confFile
}

function conf_keystone()
{
file="setuprc"
if [ ! -f "$file" ]; then
  echo $file not exits
  exit 1
fi
. $file

local token=$SG_SERVICE_TOKEN
local password=$SG_SERVICE_PASSWORD
local managementip=$SG_SERVICE_CONTROLLER_IP

local confFile="/etc/keystone/keystone.conf"

save_restore $confFile

sed -e "
/^#admin_token=.*$/s/^.*$/admin_token = $token/
/^connection =.*$/s/^.*$/connection = mysql:\/\/keystone:$password@$managementip\/keystone/
" -i $confFile
}

function conf_glance()
{
file="setuprc"
if [ ! -f "$file" ]; then
  echo $file not exits
  exit 1
fi
. $file

local password=$SG_SERVICE_PASSWORD
local managementip=$SG_SERVICE_CONTROLLER_IP

local confFile="/etc/glance/glance-api.conf"
local confFile2="/etc/glance/glance-registry.conf"

save_restore $confFile $confFile2

# do not unindent!

# TODO - need to delete the backend = sqlalchemy lines
# we sed out the mysql connection here, but then tack on the flavor info later on...
sed -e "
/^auth_port = 35357.*$/s/^.*$/auth_port = 5000/
/^sqlite_db =.*$/s/^.*$/connection = mysql:\/\/glance:$password@$managementip\/glance/
/^backend = sqlalchemy/d
/\[paste_deploy\]/a flavor = keystone
s,%SERVICE_TENANT_NAME%,service,g;
s,%SERVICE_USER%,glance,g;
s,%SERVICE_PASSWORD%,$password,g;
" -i $confFile2

echo "
[paste_deploy]
flavor = keystone
" >> $confFile2

sed -e "
/auth_port = 35357.*$/s/^.*$/auth_port = 5000/
/^sqlite_db =.*$/s/^.*$/connection = mysql:\/\/glance:$password@$managementip\/glance/
/^rabbit_host =.*$/s/^.*$/rabbit_host = $managementip/
/rabbit_use_ssl = false/a rpc_backend = rabbit
s,%SERVICE_TENANT_NAME%,service,g;
s,%SERVICE_USER%,glance,g;
s,%SERVICE_PASSWORD%,$password,g;
" -i $confFile
sed -e "/^backend = sqlalchemy/d" -i $confFile

# do not unindent!
echo "
[paste_deploy]
flavor = keystone
" >> $confFile
}

function conf_cinder()
{
file="setuprc"
if [ ! -f "$file" ]; then
  echo $file not exits
  exit 1
fi
. $file

local password=$SG_SERVICE_PASSWORD
local managementip=$SG_SERVICE_CONTROLLER_IP

local confFile="/etc/cinder/cinder.conf"

save_restore $confFile

echo "
rpc_backend = cinder.openstack.common.rpc.impl_kombu
rabbit_host = localhost
rabbit_port = 5672
rabbit_userid = guest
rabbit_password = guest

[database]
connection = mysql://cinder:$password@$managementip/cinder

[keystone_authtoken]
auth_uri = http://$managementip:5000
auth_host = $managementip
auth_port = 35357
auth_protocol = http
admin_tenant_name = service
admin_user = cinder
admin_password = $password
" >> $confFile
}

function conf_nova()
{
# source the setup file
file="setuprc"
if [ ! -f "$file" ]; then
  echo $file not exits
  exit 1
fi
. $file

# some vars from the SG setup file getting locally reassigned 
local password=$SG_SERVICE_PASSWORD
local managementip=$SG_SERVICE_CONTROLLER_IP

local confFile="/etc/nova/nova.conf"
save_restore $confFile

echo "
[DEFAULT]
logdir=/var/log/nova
state_path=/var/lib/nova
lock_path=/var/lock/nova
force_dhcp_release=True
iscsi_helper=tgtadm
libvirt_use_virtio_for_bridges=True
connection_type=libvirt
root_helper=sudo nova-rootwrap /etc/nova/rootwrap.conf
verbose=True
rpc_backend = nova.rpc.impl_kombu
rabbit_host = $managementip
my_ip = $managementip
vncserver_listen = $managementip
vncserver_proxyclient_address = $managementip
novncproxy_base_url=http://$managementip:6080/vnc_auto.html
glance_host = $managementip
auth_strategy=keystone

network_api_class=nova.network.neutronv2.api.API
neutron_url=http://$managementip:9696
neutron_auth_strategy=keystone
neutron_admin_tenant_name=service
neutron_admin_username=neutron
neutron_admin_password=$password
neutron_metadata_proxy_shared_secret=openstack
neutron_admin_auth_url=http://$managementip:35357/v2.0
linuxnet_interface_driver = nova.network.linux_net.LinuxOVSInterfaceDriver
firewall_driver=nova.virt.firewall.NoopFirewallDriver
security_group_api=neutron

vif_plugging_is_fatal: false
vif_plugging_timeout: 0

[database]
connection = mysql://nova:$password@$managementip/nova

[keystone_authtoken]
auth_uri = http://$managementip:5000
auth_host = $managementip
auth_port = 35357
auth_protocol = http
admin_tenant_name = service
admin_user = nova
admin_password = $password
" > $confFile
}

function conf_neutron()
{
# source the setup file
file="setuprc"
if [ ! -f "$file" ]; then
  echo $file not exits
  exit 1
fi
. $file

local password=$SG_SERVICE_PASSWORD
local managementip=$SG_SERVICE_CONTROLLER_IP
local regionname=$OS_REGION_NAME

local confFile="/etc/neutron/neutron.conf"
local confFile2="/etc/neutron/api-paste.ini"
local confFile3="/etc/neutron/plugins/ml2/ml2_conf.ini"
local confFile4="/etc/neutron/metadata_agent.ini"
local confFile5="/etc/neutron/dhcp_agent.ini"
local confFile6="/etc/neutron/l3_agent.ini"

save_restore $confFile $confFile2 $confFile3 $confFile4 $confFile5 $confFile6

sed -e "
/^\[DEFAULT\]/a core_plugin = ml2
/^\[DEFAULT\]/a notification_driver=neutron.openstack.common.notifier.rpc_notifier
/^\[DEFAULT\]/a verbose=True
/^\[DEFAULT\]/a rabbit_host=$managementip
/^\[DEFAULT\]/a rpc_backend=neutron.openstack.common.rpc.impl_kombu
/^\[DEFAULT\]/a service_plugins=router
/^\[DEFAULT\]/a allow_overlapping_ips=True
/^\[DEFAULT\]/a auth_strategy=keystone
/^\[DEFAULT\]/a neutron_metadata_proxy_shared_secret=openstack
/^\[DEFAULT\]/a service_neutron_metadata_proxy=True
/^\[DEFAULT\]/a nova_admin_password=$password
/^\[DEFAULT\]/a notify_nova_on_port_data_changes=True
/^\[DEFAULT\]/a notify_nova_on_port_status_changes=True
/^\[DEFAULT\]/a nova_admin_auth_url=http://$managementip:35357/v2.0
/^\[DEFAULT\]/a nova_admin_tenant_id=service
/^\[DEFAULT\]/a nova_url=http://$managementip:8774/v2
/^\[DEFAULT\]/a nova_admin_username=nova
/^\[keystone_authtoken\]/a rpc_backend = neutron.openstack.common.rpc.impl_kombu
/^\[keystone_authtoken\]/a rabbit_host = $managementip
/^\[keystone_authtoken\]/a rabbit_port = 5672
/^\[keystone_authtoken\]/a notify_nova_on_port_status_changes = True
/^\[keystone_authtoken\]/a notify_nova_on_port_data_changes = True
/^\[keystone_authtoken\]/a nova_url = http://$managementip:8774
/^\[keystone_authtoken\]/a nova_admin_username = nova
/^\[keystone_authtoken\]/a nova_admin_tenant_id = service
/^\[keystone_authtoken\]/a nova_admin_password = $password
/^\[keystone_authtoken\]/a nova_admin_auth_url = http://$managementip:35357/v2.0
/^connection = sqlite.*$/s/^.*$/connection = mysql:\/\/neutron:$password@$managementip\/neutron/
" -i $confFile

sed -e "
/^paste.filter_factory = keystoneclient.middleware.auth_token:filter_factory$/a admin_tenant_name=service
/^paste.filter_factory = keystoneclient.middleware.auth_token:filter_factory$/a admin_user=neutron
/^paste.filter_factory = keystoneclient.middleware.auth_token:filter_factory$/a admin_password=$password
" -i $confFile2

sed -e "
/^\[ml2\]/a type_drivers= local,flat
/^\[ml2\]/a mechanism_drivers = openvswitch,l2population

/^\[ml2_type_flat\]/a flat_networks=*
" -i $confFile3

# !!Modify the ml2_conf.ini to adjust to different environments!!
neutronrcFile="./neutronrc"
if [ ! -f "$neutronrcFile" ]; then
  echo $neutronrcFile not exits
  exit 1
fi
. $neutronrcFile

echo "
[ovs]
enable_tunneling = False
local_ip = $managementip
network_vlan_ranges = $network_vlan_ranges
bridge_mappings = $bridge_mappings
" >> $confFile3

sed -e "
/^\[DEFAULT\]/a auth_url = http://$managementip:5000/v2.0
/^\[DEFAULT\]/a auth_region = $regionname
/^admin_tenant_name.*$/s/^.*$/admin_tenant_name = service/
/^admin_user.*$/s/^.*$/admin_user = neutron/
/^admin_password.*$/s/^.*$/admin_password = $password/
/^\[DEFAULT\]/a metadata_proxy_shared_secret = metadata_pass
" -i $confFile4

sed -e "
/^\[DEFAULT\]/a interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver
/^\[DEFAULT\]/a dhcp_driver = neutron.agent.linux.dhcp.Dnsmasq
/^\[DEFAULT\]/a use_namespaces = True
" -i $confFile5

sed -e "
/^\[DEFAULT\]/a interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver
/^\[DEFAULT\]/a use_namespaces = True
/^\[DEFAULT\]/a gateway_external_network_id =
/^\[DEFAULT\]/a external_network_bridge =
" -i $confFile6
}

function conf_ceilometer()
{
file="setuprc"
if [ ! -f "$file" ]; then
  echo $file not exits
  exit 1
fi
. $file

local password=$SG_SERVICE_PASSWORD
local managementip=$SG_SERVICE_CONTROLLER_IP

local confFile="/etc/ceilometer/ceilometer.conf"
save_restore $confFile

echo "
[DEFAULT]
log_dir = /var/log/ceilometer
rabbit_host=$managementip
[database]
connection = mongodb://ceilometer:$password@$managementip:27017/ceilometer
[keystone_authtoken]
auth_uri = http://$managementip:5000
auth_host = $managementip
auth_port = 35357
auth_protocol = http
admin_tenant_name = service
admin_user = ceilometer
admin_password = $password
[service_credentials]
os_auth_url = http://$managementip:5000/v2.0
os_username = ceilometer
os_tenant_name = service
os_password = $password
" > $confFile
}

case $1 in
  setuprc)
    conf_setuprc
    ;;
  stackrc)
    conf_stackrc
    ;;
  network)
    conf_network
    ;;
  mysql)
    conf_mysql
    ;;
  mongo)
    conf_mongo
    ;;
  keystone)
    conf_keystone
    ;;
  glance)
    conf_glance
    ;;
  cinder)
    conf_cinder
    ;;
  nova)
    conf_nova
    ;;
  neutron)
    conf_neutron
    ;;  
  ceilometer)
    conf_ceilometer
    ;;
  *)
    usage
    exit 1
    ;;
esac
