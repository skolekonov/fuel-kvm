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

echo "Creating storage..."

virsh vol-create-as --name $name.qcow2 --capacity $size --format qcow2 --allocation $size --pool default

echo "Starting Fuel slave vm..."

virt-install \
  --name=$name \
  --cpu host \
  --ram=$ram \
  --vcpus=$cpu,cores=$cpu \
  --os-type=linux \
  --virt-type=kvm \
  --pxe \
  --boot network,hd \
  --disk "/var/lib/libvirt/images/$name.qcow2",cache=writeback,bus=virtio \
  --noautoconsole \
  --network network=fuel-pxe,model=virtio \
  --network network=fuel-public,model=virtio \
  --graphics vnc,listen=0.0.0.0

virsh destroy $name
setup_cache $name
virsh start $name

echo "Use this port to connect to vnc console$(virsh vncdisplay $name)"
