#!/bin/bash

function setup_network {
	TMPD=$(mktemp -d)
    IMAGE_PATH=/var/lib/libvirt/images
	modprobe nbd max_part=63
	qemu-nbd -n -c /dev/nbd0 $IMAGE_PATH/$name.qcow2
	vgscan --mknode
	vgchange -ay os
	mount /dev/os/root $TMPD
	sed "s/GATEWAY=.*/GATEWAY=\"$gateway_ip\"/g" -i $TMPD/etc/sysconfig/network
        echo "
DEVICE=eth1
TYPE=Ethernet
ONBOOT=yes
NM_CONTROLLED=no
BOOTPROTO=dhcp
PEERDNS=no" > $TMPD/etc/sysconfig/network-scripts/ifcfg-eth1
	umount $TMPD
	vgchange -an os
	qemu-nbd -d /dev/nbd0
}

function setup_cache {
    NAME=$1
    virsh dumpxml $NAME > $NAME.xml
    sed "s/cache='writeback'/cache='unsafe'/g" -i $NAME.xml
    virsh define $NAME.xml
    rm $NAME.xml
}

function remove_master () {
     master=$(virsh list --all | grep fuel-master | awk '{print $2}')
     if [ ! -z $master ]
     then
         echo "Deleting Fuel Master vm..."
         NAME=fuel-master
         virsh destroy $NAME
         virsh undefine $NAME
         virsh vol-delete --pool default fuel-master.qcow2
     fi
     master=$(virsh vol-list --pool default | grep fuel-master | awk '{print $2}')
     if [ ! -z $master ]
     then
          virsh vol-delete --pool default fuel-master.qcow2
     fi
}

function remove_slaves () {
   echo "Deleting Fuel nodes..."
   for i in $(virsh list --all | grep fuel-slave- | awk '{print $2}')
   do
      virsh destroy $i
      virsh undefine $i
   done

   for i in $(virsh vol-list --pool default | grep fuel-slave- | awk '{print $1}')
   do
      virsh vol-delete --pool default $i
   done
}
