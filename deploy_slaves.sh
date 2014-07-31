#!/bin/bash
source functions.sh

if [ $# -ne 7 ]
then
  echo "Usage: $0 prefix ram cpu disk vlan1 vlan2 vlan3"
  exit 1
fi

name=$1-fuel-slave-$RANDOM
ram=$2
cpu=$3
size=$4
vlan1=$5
vlan2=$6
vlan3=$7

#virsh destroy $name
#virsh undefine $name
#virsh vol-delete --pool default $name.qcow2

virsh vol-create-as --name $name.qcow2 --capacity $size --format qcow2 --allocation $size --pool default
virt-install \
  --name=$name \
  --cpu host \
  --ram=$ram \
  --vcpus=$cpu,cores=$cpu \
  --os-type=linux \
  --os-variant=rhel6 \
  --virt-type=kvm \
  --pxe \
  --boot network,hd \
  --disk "/var/lib/libvirt/images/$name.qcow2" \
  --noautoconsole \
  --network network=internal,model=virtio \
  --network network=internal,model=virtio \
  --network network=internal,model=virtio \
  --network network=internal,model=virtio \
  --graphics vnc,listen=0.0.0.0

virsh destroy $name
setup_network $vlan1
setup_network $vlan2
setup_network $vlan3

virsh start $name
echo "Started fuel-slave $name"
