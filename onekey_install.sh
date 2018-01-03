#!/bin/bash
# -------------------------------------------------------------------------------
# Filename:    onekey_install.sh
# Revision:    1.0
# Date:        2017/06/22
# Author:      Qin Boqin
# Email:       bobbqqin#gmail.com
# Description: Onekey install openstack
# Notes:       This plugin uses the "shell" command
# -------------------------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root"
  exit
fi

./apt.sh install test
./test.sh basic

read -p "Continue? [y/n]" -n 2 -r
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "install abort!"
  exit 1
fi

echo "Please modify the setup.ini and neutorn.ini"
read -p "Continue? [y/n]" -n 2 -r
if [[ !  $REPLY =~ ^[Yy]$ ]]; then
  echo "install abort!"
  exit 1
fi

./config.sh setuprc
./config.sh stackrc

echo "setuprc:"
cat setuprc
echo
echo "stackrc:"
cat stackrc

echo "Please check the setuprc and stackrc"
read -p "Continue? [y/n]" -n 2 -r
if [[ !  $REPLY =~ ^[Yy]$ ]]; then
  echo "install abort!"
  exit 1
fi

./apt.sh install all

./config.sh network
./config.sh mysql
./config.sh mongo
./config.sh keystone
./config.sh glance
./config.sh cinder
./config.sh nova
./config.sh ceilometer

./neutron.sh genNeutronrc
echo "neutronrc:"
cat neutronrc

echo "Please check the neutronrc"
read -p "Continue? [y/n]" -n 2 -r
if [[ !  $REPLY =~ ^[Yy]$ ]]; then
  echo "install abort!"
  exit 1
fi

./config.sh neutron
./service.sh restart mysql
sleep 3
./exec.sh mysql
sleep 3
./service.sh restart mongo
sleep 3
./exec.sh mongo
sleep 3
./service.sh restart keystone
sleep 3
./exec.sh keystone
sleep 3
./service.sh restart keystone
sleep 3
./service.sh restart cinder
sleep 3
./exec.sh cinder
sleep 3
./service.sh restart cinder
sleep 3
./service.sh restart glance
sleep 3
./service.sh restart nova
sleep 3
./service.sh restart ceilometer
sleep 3
./neutron.sh addPhysNetwork
sleep 3
./service.sh restart neutron
sleep 3
./neutron.sh addNeutronNetwork
sleep 3
./service.sh restart horizon
sleep 3
./test.sh all

echo "Installation done"
echo "Please visit http://{IP}/horizon"
