# Openstack manager
## 1. Desc
### 1.1 Resource files
 - apt.list
   openstack packages 
 - service.list
   openstack service
 - setup.ini
   config setup variables; generate setuprc
 - neutron.ini
   config neutron variables; generate neutronrc
 - neutronrc
   build openstack physical networks and virtual networks
 - setuprc
   setup variables; generate stackrc
 - stackrc
   openstack credentials, etc; exported before openstack commands

### 1.2 Scripts
 - apt.sh
   install or purge openstack-related packages
   apt.sh {install|purge} {test|basic|network|utils|mysql|mongo|keystone|glance|cinder|nova|neutron|ceilometer|horizon|all}
   test: test for KVM env
   basic: openstack basic env, such as python, qemu, etc
   network: ntp for time sync
   utils: openstack handy tools
   all: all but test
 - config.sh
   modify the openstack config files
   config.sh {setuprc|stackrc|network|mysql|mongo|keystone|glance|cinder|nova|neutron|ceilometer}
   setuprc: generate setuprc from setup.ini
   stackrc: generate stackrc from setuprc
   network: config ntp
 - service.sh
   manage openstack-related service
   service.sh {start|stop|restart|status} {network|mysql|mongo|keystone|glance|cinder|nova|neutron|ceilometer|horizon|all} 
   nework: ntp
 - exec.sh
   exec openstack-related commands
   exec.sh {mysql|mongo|keystone|cinder}
   mysql: create all openstack dbs
   mongo: create ceilometer dbs
   keystone: exec keystone command to generate credentials for all other openstack service
   cinder: generate a loop file cinder-volumes and config in openstack for storage
 - neutron.sh
   add or remove openstack physical networks and virtual networks
   neutron.sh {removeNeutronrc|genNeutronrc|removePhysNetwork|addPhysNetwork|removeNeutronNetwork|addNeutronNetwork}
   removeNeutronrc: rm neutronrc
   genNeutronrc: generate neutronrc
   removePhysNetwork: rm openstack physical nework by ovs-vsctl del-br
   addPhsyNetwork: add openstack physical network by ovs-vsctl add-br
   removeNeutronNetwork: rm openstack virtual network by neutron commands
   addNeutronNetwork: add openstack virtual network by neutron commands
 - test.sh
   test if openstack service is working properly
   test.sh {basic|keystone|glance|nova|ceilometer|all}
   basic: check if the env support KVM
   all: all but basic
 - test_basic.sh
   used by `test.sh basic`
 - deexec.sh
   inverse process of exec.sh, control each service by dropping db
   deexec.sh {ceilometer|mongo|neutron|nova|cinder|glance|keystone|mysql|all}
   ceilometer: drop mongo ceilometer db
   mongo: drop mongo ceilometer db
   mysql: drop all mysql dbs
   cinder: not only drop cinder db but also rm cinder-volumes
   all: drop mysql dbs and mongo dbs, rm cinder-volumes
 - deconfig.sh
   inverse process of config.sh, restore the default conf files
   deconfig.sh {setuprc|stackrc|network|mysql|mongo|keystone|glance|cinder|nova|neutron|ceilometer}
   setuprc: rm setuprc
   stackrc: rm stackrc
 - onekey_install.sh
   interactive scripts for openstack installation 

## 2. Usage
1. modify .ini files
2. apt.sh install
3. config.sh 
4. service.sh restart
5. exec.sh
6. test.sh

