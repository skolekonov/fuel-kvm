#!/bin/bash
function create_disk {

    local _NAME=${1:-NAME}
    local _DISK=${2:-DISK}

    echo "Creating storage..."
    echo -e "Name: \"${_NAME}\"\nSize: ${_DISK}"

    virsh vol-create-as --name $_NAME.qcow2 --capacity $_DISK --format qcow2 --allocation $_DISK --pool default
}

function setup_network {


    local _NAME=${1:-NAME}
    local _VLAN=${2:-VLAN}

    echo "Setup network..."
    echo -e "Name: \"${_NAME}\"\nVLAN ID: ${_VLAN}"

    virsh dumpxml ${_NAME} > ${_NAME}.xml
	sed "0,/network='internal'\\/>/s//network='internal' portgroup='vlan-${_VLAN}'\\/>/" -i ${_NAME}.xml
#        awk '{print} NR==$STR {while (getline < "vlan.xml") print}' $name.xml > $name_new.xml
	virsh define ${_NAME}.xml
    rm -f ${_NAME}.xml
}


function setup_iso {

    local _NAME=${1:-NAME}
    local _GW=${2:-GATEWAY_IP}

    echo "Setup ISO..."

	TMPD=$(mktemp -d)
    IMAGE_PATH=/var/lib/libvirt/images
	modprobe nbd max_part=63
	qemu-nbd -n -c /dev/nbd0 $IMAGE_PATH/${_NAME}.qcow2
	vgscan --mknode
	vgchange -ay os
	mount /dev/os/root $TMPD
	sed "s/GATEWAY=.*/GATEWAY=\"${_GW}\"/g" -i $TMPD/etc/sysconfig/network
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
