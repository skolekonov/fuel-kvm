#!/bin/bash


function setup_network {
        VLAN=$1
        STR=$2
	virsh dumpxml $name > $name.xml
	sed "0,/network='internal'\\/>/s//network='internal' portgroup='vlan-$VLAN'\\/>/" -i $name.xml
#        awk '{print} NR==$STR {while (getline < "vlan.xml") print}' $name.xml > $name_new.xml
	virsh define $name.xml
        rm -f $name.xml
}


function setup_iso {
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
