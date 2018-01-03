#!/bin/bash
# -------------------------------------------------------------------------------
# Filename:    neutron.sh
# Revision:    1.0
# Date:        2017/06/22
# Author:      Qin Boqin
# Email:       bobbqqin#gmail.com
# Description: Neutron manager for openstack
# Notes:       This plugin uses the "ovs" and "neutron-related" command
# -------------------------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
   "This script must be run as root"
  exit
fi

# check if neutron.ini exists; if true, source it.
file="neutron.ini"
if [ ! -f "$file" ]; then
  echo $file not exits
  exit 1
fi
. $file

function usage()
{
  echo "neutron.sh {removeNeutronrc|genNeutronrc|removePhysNetwork|addPhysNetwork|removeNeutronNetwork|addNeutronNetwork}"
}

if [[ $# -ne 1 ]]; then
  usage
  exit 1
fi

if [[ ! "$1" =~ ^(removeNeutronrc|genNeutronrc|removePhysNetwork|addPhysNetwork|removeNeutronNetwork|addNeutronNetwork)$ ]]; then
  usage
  exit 1
fi

nic_num=${#nic[@]}

function removeNeutronrc()
{
  if [ -f "./neutronrc" ]; then
    rm "./neutronrc"
  fi  
}

function genNeutronrc()
{
  network_vlan_ranges=
  bridge_mappings=

  for (( i=0; i<${nic_num}-1; i++ ));
  do
    network_vlan_ranges=${network_vlan_ranges}${physnet[$i]},
    bridge_mappings=${bridge_mappings}${physnet[$i]}:${br[$i]},
  done
  
  network_vlan_ranges=${network_vlan_ranges}${physnet[$nic_num-1]}
  bridge_mappings=${bridge_mappings}${physnet[$nic_num-1]}:${br[$nic_num-1]}
  
echo "network_vlan_ranges=$network_vlan_ranges
bridge_mappings=$bridge_mappings" > "./neutronrc"
}
 
function removePhysNetwork()
{
  for (( i=0; i<${nic_num}; i++ ));
  do
     ifconfig ${br[$i]} down
     ovs-vsctl del-br ${br[$i]}
  done
  ovs-vsctl del-br br-int
}

function addPhysNetwork()
{
  ovs-vsctl add-br br-int
  for (( i=0; i<${nic_num}; i++ ));
  do
     ifconfig ${nic[$i]} 0.0.0.0
     ovs-vsctl add-br ${br[$i]}
     ovs-vsctl add-port ${br[$i]} ${nic[$i]}
     ifconfig ${br[$i]} ${br_ip[$i]} netmask ${br_netmask[$i]}
  done
}

function admin_tenant_id()
{
  . stackrc
  keystone tenant-list | grep admin | awk '{print $2}'
}

function addNeutronNetwork()
{
  . stackrc
  local ADMIN_TENANT_ID=$(admin_tenant_id)

  for (( i=0; i<${nic_num}; i++ ));
  do
     neutron net-create --tenant-id $ADMIN_TENANT_ID ${extnet[$i]} --shared --provider:network_type flat --provider:physical_network ${physnet[$i]}
     neutron subnet-create --name ${subnet[$i]} --ip-version 4 --tenant-id $ADMIN_TENANT_ID ${extnet[$i]} ${subnet_range[$i]} --allocation-pool start=${start_ip[$i]},end=${end_ip[$i]} --gateway ${gateway[$i]} --dns_nameservers list=true 8.8.4.4 8.8.8.8
  done
}

function removeNeutronNetwork()
{
  # TODO
   echo "First remove all instances, then neutron [subnet-delete|net-delete]"
}

case $1 in
  removeNeutronrc)
    removeNeutronrc
    ;;
  genNeutronrc)
    genNeutronrc
    ;;
  removePhysNetwork)
    removePhysNetwork
    ;;
  addPhysNetwork)
    addPhysNetwork
    ;;
  removeNeutronNetwork)
    removeNeutronNetwork
    ;;
  addNeutronNetwork)
    addNeutronNetwork
    ;;
  *)
    usage
    exit 1
    ;;
esac
