#!/bin/bash
# -------------------------------------------------------------------------------
# Filename:    deconfig.sh
# Revision:    1.0
# Date:        2017/06/21
# Author:      Qin Boqin
# Email:       bobbqqin#gmail.com
# Description: Deconfig openstack
# Notes:       This plugin uses the "cp" command
# -------------------------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root"
  exit
fi

function usage()
{
  echo "deconfig.sh {setuprc|stackrc|network|mysql|mongo|keystone|glance|cinder|nova|neutron|ceilometer}"
}

if [[ $# -ne 1 ]]; then
  usage
  exit 1
fi

if [[ ! "$1" =~ ^(setuprc|stackrc|network|mysql|mongo|keystone|glance|cinder|nova|neutron|ceilometer)$ ]]; then
  usage
  exit 1
fi

function deconf_setuprc()
{
  rm "setuprc"
}

function deconf_stackrc()
{
  rm "stackrc"
}

function save_restore()
{
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

function deconf_network()
{
  echo 0 > /proc/sys/net/ipv4/ip_forward
  sysctl net.ipv4.ip_forward=0

  save_restore "/etc/ntp.conf"
}

function deconf_mysql()
{
  save_restore "/etc/mysql/my.cnf" "/etc/mysql/conf.d/openstack.cnf.orig"
}

function deconf_mongo()
{
  save_restore "/etc/mongodb.conf"
}

function deconf_keystone()
{
  save_restore "/etc/keystone/keystone.conf"
}

function deconf_glance()
{
  save_restore "/etc/glance/glance-api.conf" "/etc/glance/glance-registry.conf"
}

function deconf_cinder()
{
  save_restore "/etc/cinder/cinder.conf"
}

function deconf_nova()
{
  save_restore "/etc/kernel/postinst.d/statoverride" "/etc/nova/dnsmasq-nova.conf" "/etc/nova/nova.conf"
}

function deconf_neutron()
{
  save_restore "/etc/neutron/neutron.conf" "/etc/neutron/api-paste.ini" "/etc/neutron/plugins/ml2/ml2_conf.ini" "/etc/neutron/metadata_agent.ini" "/etc/neutron/dhcp_agent.ini" "/etc/neutron/l3_agent.ini"
}

function deconf_ceilometer()
{
  save_restore "/etc/ceilometer/ceilometer.conf"
}

case $1 in
  setuprc)
    deconf_setuprc
    ;;
  stackrc)
    deconf_stackrc
    ;;
  network)
    deconf_network
    ;;
  mysql)
    deconf_mysql
    ;;
  mongo)
    deconf_mongo
    ;;
  keystone)
    deconf_keystone
    ;;
  glance)
    deconf_glance
    ;;
  cinder)
    deconf_cinder
    ;;
  nova)
    deconf_nova
    ;;
  neutron)
    deconf_neutron
    ;;
  ceilometer)
    deconf_ceilometer
    ;;
  *)
    usage
    exit 1
    ;;
esac

