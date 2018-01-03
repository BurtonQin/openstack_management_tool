#!/bin/bash
# -------------------------------------------------------------------------------
# Filename:    service.sh
# Revision:    1.0
# Date:        2017/06/21
# Author:      Qin Boqin
# Email:       bobbqqin#gmail.com
# Description: Manage openstack serivces
# Notes:       This plugin uses the "service" command
# -------------------------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root"
  exit
fi

# check if service.list exists; if true, source it.
file="service.list"
if [ ! -f "$file" ]; then
  echo $file not exits
  exit 1
fi
. $file

function usage()
{
  echo "service.sh {start|stop|restart|status} {network|mysql|mongo|keystone|glance|cinder|nova|neutron|ceilometer|horizon|all}"
}

if [[ $# -ne 2 ]]; then
  usage
  exit 1 
fi

if [[ ! "$1" =~ ^(start|stop|restart|status)$ ]]; then
  usage
  exit 1
fi

if [[ ! "$2" =~ ^(network|mysql|mongo|keystone|glance|cinder|nova|neutron|ceilometer|horizon|all)$ ]]; then
  usage
  exit 1
fi

action=$1
section=$2
function batchService()
{
  for s in $@;
  do
    service $s $action
  done
}
cmd=batchService

case $section in
  network)
    $cmd ${network[@]}
    ;;
  mysql)
    $cmd ${mysql[@]}
    ;;
  mongo)
    $cmd ${mongo[@]}
    ;;
  keystone)
    if [[ "$action" = "restart" ]]; then
      keystone-manage db_sync
      sleep 3
    fi
    $cmd ${keystone[@]}
    ;;
  glance)
    if [[ "$action" = "restart" ]]; then
      glance-manage db_sync
      sleep 3
    fi
    $cmd ${glance[@]}
    ;;
  cinder)
    if [[ "$action" = "restart" ]]; then
      cinder-manage db sync
      sleep 3
    fi
    $cmd ${cinder[@]}
    ;;
  nova)
    if [[ "$action" = "restart" ]]; then
      nova-manage db sync
      sleep 3
    fi
    $cmd ${nova[@]}
    ;;
  neutron)
    $cmd ${neutron[@]}
    ;;
  ceilometer)
    $cmd ${ceilometer[@]}
    ;;
  horizon)
    $cmd ${horizon[@]}
    ;;
  all)
    $cmd ${network[@]} ${mysql[@]} ${mongo[@]}
    if [[ "$action" = "restart" ]]; then
      keystone-manage db_sync
      sleep 3
    fi
    $cmd ${keystone[@]} 
    if [[ "$action" = "restart" ]]; then
      glance-manage db_sync
      sleep 3
    fi    
    $cmd ${glance[@]} 
    $cmd ${cinder[@]} 
    if [[ "$action" = "restart" ]]; then
      nova-manage db sync
      sleep 3
    fi
    $cmd ${nova[@]} 
    $cmd ${neutron[@]} ${ceilometer[@]} ${horizon[@]}
    ;;
  *)
    usage
    exit 1
    ;;
esac
