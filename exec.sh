#!/bin/bash
# -------------------------------------------------------------------------------
# Filename:    exec.sh
# Revision:    1.0
# Date:        2017/06/21
# Author:      Qin Boqin
# Email:       bobbqqin#gmail.com
# Description: Exceute openstack-related commands during installation
# Notes:       This plugin uses the "openstack-related" command
# -------------------------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root"
  exit
fi

function usage()
{
  echo "exec.sh {mysql|mongo|keystone|cinder}"
}

if [[ $# -ne 1 ]]; then
  usage
  exit 1
fi

if [[ ! "$1" =~ ^(mysql|mongo|keystone|cinder)$ ]]; then
  usage
  exit 1
fi

function exec_mysql()
{
file="setuprc"
if [ ! -f "$file" ]; then
  echo $file not exits
  exit 1
fi
. $file

local managementip=$SG_SERVICE_CONTROLLER_IP
local password=$SG_SERVICE_PASSWORD

mysql -u root -p <<EOF
CREATE DATABASE nova;
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY '$password';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY '$password';
CREATE DATABASE glance;
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY '$password';
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY '$password';
CREATE DATABASE keystone;
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY '$password';
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY '$password';
CREATE DATABASE cinder;
GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'%' IDENTIFIED BY '$password';
GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'localhost' IDENTIFIED BY '$password';
CREATE DATABASE neutron;
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY '$password';
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY '$password';
FLUSH PRIVILEGES;
EOF
}

function exec_mongo()
{
file="setuprc"
if [ ! -f "$file" ]; then
  echo $file not exits
  exit 1
fi
. $file

local managementip=$SG_SERVICE_CONTROLLER_IP
local password=$SG_SERVICE_PASSWORD

mongo --host $managementip --eval "
var pass = '$password'
db = db.getSiblingDB('ceilometer');
db.addUser({user: 'ceilometer',
            pwd: pass,
            roles: [ 'readWrite', 'dbAdmin' ]})"
}

function get_id () {
    echo `$@ | awk '/ id / { print $4 }'`
}

function exec_keystone()
{
file="setuprc"
if [ ! -f "$file" ]; then
  echo $file not exits
  exit 1
fi
. $file

file2="stackrc"
if [ ! -f "$file2" ]; then
  echo $file2 not exits
  exit 1
fi
. $file2

local email=$SG_SERVICE_EMAIL
local managementip=$SG_SERVICE_CONTROLLER_IP

# Users
keystone user-create --name=admin --pass="$ADMIN_PASSWORD" --email=$email
keystone user-create --name=demo --pass="$ADMIN_PASSWORD" --email=$email
keystone-manage db_sync
service keystone restart

sleep 5

# Roles
ADMIN_ROLE=$(get_id keystone role-create --name=admin)

# Tenants
ADMIN_TENANT=$(get_id keystone tenant-create --name=admin)
SERVICE_TENANT=$(get_id keystone tenant-create --name=service)
DEMO_TENANT=$(get_id keystone tenant-create --name=demo)

# Add Roles to Users in Tenants
keystone user-role-add --user=admin --role=admin --tenant=admin
keystone user-role-add --user=demo --role=_member_ --tenant=demo

# keystone 
KEYSTONE=$(get_id keystone service-create --name=keystone --type=identity --description=Identity )
keystone endpoint-create --region=$KEYSTONE_REGION --service-id=$KEYSTONE --publicurl='http://'"$managementip"':5000/v2.0' --adminurl='http://'"$managementip"':35357/v2.0' --internalurl='http://'"$managementip"':5000/v2.0'

# glance
keystone user-create --name=glance --pass="$SERVICE_PASSWORD" --email=$email
keystone user-role-add --user=glance --tenant=service --role=admin
GLANCE=$(get_id keystone service-create --name=glance --type=image --description=Image)
keystone endpoint-create --region=$KEYSTONE_REGION --service-id=$GLANCE --publicurl='http://'"$managementip"':9292' --adminurl='http://'"$managementip"':9292' --internalurl='http://'"$managementip"':9292'

# cinder
keystone user-create --name=cinder --pass="$SERVICE_PASSWORD" --email=$email
keystone user-role-add --tenant=service --user=cinder --role=admin
CINDER=$(get_id keystone service-create --name=cinder --type=volume --description=Volume )
keystone endpoint-create --region=$KEYSTONE_REGION --service-id=$CINDER --publicurl='http://'"$managementip"':8776/v1/$(tenant_id)s' --adminurl='http://'"$managementip"':8776/v1/$(tenant_id)s' --internalurl='http://'"$managementip"':8776/v1/$(tenant_id)s'
CINDER2=$(get_id keystone service-create --name=cinder --type=volumev2 --description=Volume2 )
keystone endpoint-create --region=$KEYSTONE_REGION --service-id=$CINDER2 --publicurl='http://'"$managementip"':8776/v2/$(tenant_id)s' --adminurl='http://'"$managementip"':8776/v2/$(tenant_id)s' --internalurl='http://'"$managementip"':8776/v2/$(tenant_id)s'

# nova
keystone user-create --name=nova --pass="$SERVICE_PASSWORD" --email=$email
keystone user-role-add --tenant=service --user=nova --role=admin
NOVA=$(get_id keystone service-create --name=nova --type=compute --description=Compute )
keystone endpoint-create --region=$KEYSTONE_REGION --service-id=$NOVA --publicurl='http://'"$managementip"':8774/v2/$(tenant_id)s' --adminurl='http://'"$managementip"':8774/v2/$(tenant_id)s' --internalurl='http://'"$managementip"':8774/v2/$(tenant_id)s'

# neutron
keystone user-create --name=neutron --pass="$SERVICE_PASSWORD" --email=$email
keystone user-role-add --tenant=service --user=neutron --role=admin
keystone service-create --name=neutron --type=network --description="OpenStack Networking Service"
keystone endpoint-create --service=neutron --publicurl='http://'"$managementip"':9696' --adminurl='http://'"$managementip"':9696' --internalurl='http://'"$managementip"':9696'

# ec2 compatability
EC2=$(get_id keystone service-create --name=ec2 --type=ec2 --description=EC2 )
keystone endpoint-create --region=$KEYSTONE_REGION --service-id=$EC2 --publicurl='http://'"$managementip"':8773/services/Cloud' --adminurl='http://'"$managementip"':8773/services/Admin' --internalurl='http://'"$managementip"':8773/services/Cloud'

# ceilometer
keystone user-create --name=ceilometer --pass="$SERVICE_PASSWORD" --email=$email
keystone user-role-add --tenant=service --user=ceilometer --role=admin
keystone service-create --name=ceilometer --type=metering --description="Telemetry"
keystone endpoint-create --service=ceilometer --publicurl='http://'"$managementip"':8777' --adminurl='http://'"$managementip"':8777' --internalurl='http://'"$managementip"':8777'

# create db tables and restart
keystone-manage db_sync
service keystone restart
}

function exec_cinder()
{
# source the setup file
file="setuprc"
if [ ! -f "$file" ]; then
  echo $file not exits
  exit 1
fi
. $file

# source the stackrc file
file2="stackrc"
if [ ! -f "$file2" ]; then
  echo $file2 not exits
  exit 1
fi
. $file2

local gigabytes=$LOOPSIZE
echo "Creating loopback file of size $gigabytes GB at /cinder-volumes..."
gigabytesly=$gigabytes"G"
dd if=/dev/zero of=/cinder-volumes bs=1 count=0 seek=$gigabytesly
echo;

# loop the file up
losetup /dev/loop2 /cinder-volumes

# create a rebootable remount of the file
echo "losetup /dev/loop2 /cinder-volumes; exit 0;" > /etc/init.d/cinder-setup-backing-file
chmod 755 /etc/init.d/cinder-setup-backing-file
ln -s /etc/init.d/cinder-setup-backing-file /etc/rc2.d/S10cinder-setup-backing-file

# create the physical volume and volume group
sudo pvcreate /dev/loop2
sudo vgcreate cinder-volumes /dev/loop2

# create storage type
sleep 2
cinder type-create Storage
}

case $1 in
  mysql)
    exec_mysql
    ;;
  mongo)
    exec_mongo
    ;;
  keystone)
    exec_keystone
    ;;
  cinder)
    exec_cinder
    ;;
  *)
    usage
    exit 1
    ;;
esac

