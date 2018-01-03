#!/bin/bash
# -------------------------------------------------------------------------------
# Filename:    deexec.sh
# Revision:    1.0
# Date:        2017/06/21
# Author:      Qin Boqin
# Email:       bobbqqin#gmail.com
# Description: Drop all openstack related databases
# Notes:       This plugin uses the "mysql" command
# -------------------------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root"
  exit
fi

function usage()
{
  echo "deexec.sh {ceilometer|mongo|neutron|nova|cinder|glance|keystone|mysql|all}"
}

if [[ $# -ne 1 ]]; then
  usage
  exit 1
fi

if [[ ! "$1" =~ ^(ceilometer|mongo|neutron|nova|cinder|glance|keystone|mysql|all)$ ]]; then
  usage
  exit 1
fi

function drop_keystone()
{
mysql -u root -p <<EOF
DROP DATABASE keystone;
EOF
}

function drop_glance()
{
mysql -u root -p <<EOF
DROP DATABASE glance;
EOF
}

function drop_cinder()
{
mysql -u root -p <<EOF
DROP DATABASE cinder;
EOF

vgremove cinder-volumes
pvremove /dev/loop2
rm -rf /etc/rc2.d/S10cinder-setup-backing-file
rm -rf /etc/init.d/cinder-setup-backing-file
losetup -d /dev/loop2
rm -rf /cinder-volumes
}

function drop_nova()
{
mysql -u root -p <<EOF
DROP DATABASE nova;
EOF
}
function drop_neutron()
{
mysql -u root -p <<EOF
DROP DATABASE neutron;
EOF
}

function drop_mysql()
{
mysql -u root -p <<EOF
DROP DATABASE neutron;
DROP DATABASE nova;
DROP DATABASE cinder;
DROP DATABASE glance;
DROP DATABASE keystone;
EOF
}

function drop_ceilometer()
{
file="setuprc"
if [ ! -f "$file" ]; then
  echo $file not exits
  exit 1
fi
. $file

local managementip=$SG_SERVICE_CONTROLLER_IP

mongo --host $managementip ceilometer --eval '
db.dropDatabase();
db.removeUser("ceilometer");
'
}

function drop_all()
{
drop_ceilometer
drop_mysql
}

case $1 in
  ceilometer)
    drop_ceilometer
    ;;
  mongo)
    drop_ceilometer
    ;;
  neutron)
    drop_neutron
    ;;
  nova)
    drop_nova
    ;;
  cinder)
    drop_cinder
    ;;
  glance)
    drop_glance
    ;;
  keystone)
    drop_keystone
    ;;
  mysql)
    drop_mysql
    ;;
  all)
    drop_all
    ;;
  *)
    usage
    exit 1
    ;;
esac

