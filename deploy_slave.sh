#!/bin/bash

source functions.sh

if [ $# -ne 4 ]
then
  echo "Usage: $0 node_name node_ram node_cpu node_size"
  exit 1
fi

name=$1
ram=$2
cpu=$3
size=$4
net_driver=${net_driver:-e1000}

echo "Creating storage..."

virsh vol-create-as --name $name.qcow2 --capacity $size --format qcow2 --allocation $size --pool default

echo "Starting Fuel slave vm..."

virt-install \
  --name=$name \
  --ram=$ram \
  --vcpus=$cpu,cores=$cpu \
  --os-type=linux \
  --virt-type=kvm \
  --pxe \
  --boot network,hd \
  --disk "/var/lib/libvirt/images/$name.qcow2",cache=writeback,bus=virtio,serial=$(uuidgen) \
  --noautoconsole \
  --network network=fuel-pxe,model=$net_driver \
  --network network=fuel-public,model=$net_driver \
  --graphics vnc,listen=0.0.0.0
#  --cpu host \
#If cpu parameter is set to "host" with QEMU 2.0 hypervisor
#it causes critical failure during CentOS installation

virsh destroy $name
setup_cache $name
virsh start $name

echo "VNC port: $(get_vnc $name)"
