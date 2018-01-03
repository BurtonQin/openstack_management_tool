#!/bin/bash
# -------------------------------------------------------------------------------
# Filename:    apt.sh
# Revision:    1.0
# Date:        2017/06/21
# Author:      Qin Boqin
# Email:       bobbqqin#gmail.com
# Description: Packet manager for openstack
# Notes:       This plugin uses the "apt-get" command
# -------------------------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root"
  exit
fi

# check if apt.list exists; if true, source it.
file="apt.list"
if [ ! -f "$file" ]; then
  echo $file not exits
  exit 1
fi
. $file

function usage()
{
  echo "apt.sh {install|purge} {test|basic|network|utils|mysql|mongo|keystone|glance|cinder|nova|neutron|ceilometer|horizon|all}"
}

if [[ $# -ne 2 ]]; then
  usage
  exit 1 
fi

if [[ ! "$1" =~ ^(install|purge)$ ]]; then
  usage
  exit 1
fi

if [[ ! "$2" =~ ^(test|basic|network|utils|mysql|mongo|keystone|glance|cinder|nova|neutron|ceilometer|horizon|all)$ ]]; then
  usage
  exit 1
fi

function kernel_listen()
{
  dpkg-statoverride --list | grep /boot/vmlinuz-$(uname -r)
  if [ $? -eq 0 ]; then
    echo "Kernel has already listened to us."
  else
    dpkg-statoverride  --update --add root root 0644 /boot/vmlinuz-$(uname -r)
  fi
}

function kernel_no_listen()
{
  dpkg-statoverride --list | grep /boot/vmlinuz-$(uname -r)
  if [ $? -eq 0 ]; then
    dpkg-statoverride  --remove /boot/vmlinuz-$(uname -r)
  else
    echo "Kernel has not listened to us."
  fi
}

cmd='apt-get -y'
action=$1
section=$2

if [[ "$action" = "install" ]]; then
  kernel_listen
elif [[ "$action" = "purge" ]]; then
  kernel_no_listen
fi

case $section in
  test)
    $cmd $action ${test[@]}
    ;;
  basic)
    $cmd $action ${basic[@]}
    ;;
  network)
    $cmd $1 ${network[@]}
    ;;
  utils)
    $cmd $action ${utils[@]}
    ;;
  mysql)
    $cmd $action ${mysql[@]}
    if [[ "$action" = "install" ]]; then
      # prompt to improve the security of mysql
      mysql_secure_installation
    fi
    ;;
  mongo)
    $cmd $action ${mongo[@]}
    ;;
  keystone)
    $cmd $action ${keystone[@]}
    ;;
  glance)
    $cmd $action ${glance[@]}
    ;;
  cinder)
    $cmd $action ${cinder[@]}
    ;;
  nova)
    $cmd $action ${nova[@]}
    ;;
  neutron)
    $cmd $action ${neutron[@]}
    ;;
  ceilometer)
    $cmd $action ${ceilometer[@]}
    ;;
  horizon)
    $cmd $action ${horizon[@]}
    if [[ "$action" = "install" ]]; then
      # remove the ubuntu theme - seriously this is fucking stupid it's still broken
      apt-get remove -y --purge openstack-dashboard-ubuntu-theme
    fi
    ;;
  all)
    # no test
    $cmd $action ${basic[@]} ${network[@]} ${utils[@]} ${mysql[@]} ${mongo[@]} ${keystone[@]} ${glance[@]} ${cinder[@]} ${nova[@]} ${neutron[@]} ${ceilometer[@]} ${horizon[@]}
    if [[ "$action" = "install" ]]; then
      # remove the ubuntu theme - seriously this is fucking stupid it's still broken
      apt-get remove -y --purge openstack-dashboard-ubuntu-theme
      # prompt to improve the security of mysql
      mysql_secure_installation
    fi
    ;;
  *)
    usage
    exit 1
    ;;
esac
