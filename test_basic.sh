#!/bin/bash
# -------------------------------------------------------------------------------
# Filename:    test_basic.sh
# Revision:    1.0
# Date:        2017/06/21
# Author:      Qin Boqin
# Email:       bobbqqin#gmail.com
# Description: Test if the machine has virt capabilities
# Notes:       This plugin uses the "echo" command
# -------------------------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root"
  exit
fi

# install and run kvm-ok to see if we have virt capabilities
if /usr/sbin/kvm-ok
then echo;
echo "#################################################################################################

Your CPU seems to support KVM extensions.  If you are installing OpenStack on a virtual machine,
you will need to add 'virt_type=qemu' to your nova.conf file in /etc/nova/ and then restart all
nova services once you've finished running through the installation.  You DO NOT need to do this 
on a bare metal box.

#################################################################################################
"
else echo;
echo "#################################################################################################

Your system isn't configured to run KVM properly.  Investigate this before continuing.

You can still modify /etc/nova/nova.conf (once nova is installed) to emulate acceleration:

[libvirt]
virt_type = qemu

#################################################################################################
"
fi


