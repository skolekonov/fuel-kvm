#!/bin/bash

source functions.sh

if [ $# -ne 6 ]
then
  echo "Usage: $0 prefix ram cpu disk iso-path vlan1"
  exit 1
fi

name=$1-fuel-master
ram=$2
cpu=$3
size=$4
iso_path=$5
pxe_vlan=$6

echo "Creating storage..."

virsh vol-create-as --name $name.qcow2 --capacity $size --format qcow2 --allocation $size --pool default

echo "Starting Fuel master vm..."

virt-install \
  --name=$name \
  --cpu host \
  --ram=$ram \
  --vcpus=$cpu,cores=$cpu \
  --os-type=linux \
  --os-variant=rhel6 \
  --virt-type=kvm \
  --disk "/var/lib/libvirt/images/$name.qcow2" \
  --cdrom "$iso_path" \
  --noautoconsole \
  --network network=internal,model=virtio \
  --network network=internal,model=virtio \
  --graphics vnc,listen=0.0.0.0

gateway_ip=172.18.161.1

while (true)
do
   STATUS=$(virsh dominfo $name | grep State | awk -F " " '{print $2}')
   if [ $STATUS == 'shut' ]
   then
       setup_iso
       setup_network $pxe_vlan
       virsh start $name
       break
    fi
    sleep 10
done

echo "CentOS is installed successfully. Running Fuel master deployment..."

