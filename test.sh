#!/bin/bash
# -------------------------------------------------------------------------------
# Filename:    test.sh
# Revision:    1.0
# Date:        2017/06/21
# Author:      Qin Boqin
# Email:       bobbqqin#gmail.com
# Description: Test openstack
# Notes:       This plugin uses the "openstack-related" command
# -------------------------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root"
  exit
fi

function usage()
{
  echo "test.sh {basic|keystone|glance|nova|ceilometer|all}"
}

if [[ $# -ne 1 ]]; then
  usage
  exit 1
fi

if [[ ! "$1" =~ ^(basic|keystone|glance|nova|ceilometer|all)$ ]]; then
  usage
  exit 1
fi

service="$1"

function test_basic()
{
./test_basic.sh
}

function test_keystone()
{
. ./stackrc
keystone user-list
}

function test_glance()
{
. ./stackrc
glance image-list
}

function test_nova()
{
. ./stackrc
nova-manage service list
nova image-list
}

function test_ceilometer()
{
. ./stackrc
ceilometer meter-list
}

case $service in
  basic)
    test_basic
    ;;
  keystone)
    test_keystone
    ;;
  glance)
    test_glance
    ;;
  nova)
    test_nova
    ;;
  ceilometer)
    test_ceilometer
    ;;
  all)
#    test_basic
    test_keystone
    test_glance
    test_nova
    test_ceilometer
    ;;
  *)
    usage
    exit 1
    ;;
esac
