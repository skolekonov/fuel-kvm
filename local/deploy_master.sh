#!/bin/bash

source product.sh
source functions.sh

if [ $# -ne 5 ]
then
  echo "Usage: $0 iso-path master_name master_ram master_cpu master_disk"
  exit 1
fi

iso_path=$1
name=$2
ram=$3
cpu=$4
size=$5
#Use user-defined bridge to setup external network for Fuel Master node
#Bridge name is hardcoded to 'br0', edit xml files to change
#libvirt's "default" NAT network will be used if there's no bridge
hosts_bridge=false
#Define your network's gateway here.
#It will be used as default on Fuel Master node
#gateway_ip=172.18.78.1
gateway_ip=192.168.122.1

echo "Creating storage..."

virsh vol-create-as --name $name.qcow2 --capacity $size --format qcow2 --allocation $size --pool default

echo "Creating networks..."

#10.20.0.0/24 - pxe (isolated)
virsh net-destroy fuel-pxe
virsh net-undefine fuel-pxe
virsh net-define fuel-pxe.xml
virsh net-autostart fuel-pxe
virsh net-start fuel-pxe

#172.16.0.1/24 - public/floating (NAT)
virsh net-destroy fuel-public
virsh net-undefine fuel-public
virsh net-define fuel-public.xml
virsh net-autostart fuel-public
virsh net-start fuel-public

if $hosts_bridge
then
    #directly connected to a host's bridge (br0)
    virsh net-destroy fuel-external
    virsh net-undefine fuel-external
    virsh net-define fuel-external.xml
    virsh net-autostart fuel-external
    virsh net-start fuel-external
    external_network=fuel-external
else
    external_network=default
fi

echo "Starting Fuel master vm..."

virt-install \
  --name=$name \
  --ram=$ram \
  --vcpus=$cpu,cores=$cpu \
  --os-type=linux \
  --os-variant=rhel6 \
  --virt-type=kvm \
  --disk "/var/lib/libvirt/images/$name.qcow2",cache=writeback,bus=virtio \
  --cdrom "$iso_path" \
  --noautoconsole \
  --network network=fuel-pxe,model=virtio \
  --network network=$external_network,model=virtio \
  --graphics vnc,listen=0.0.0.0
#  --cpu host \
#If cpu parameter is set to "host" with QEMU 2.0 hypervisor
#it causes critical failure during CentOS installation

echo "Use this port to connect to vnc console$(virsh vncdisplay $name)"

#Fuel master is powered off after CentOS installation
#We are waiting for this moment to setup the VM and continue deployment
while (true)
do
   STATUS=$(virsh dominfo $name | grep State | awk -F " " '{print $2}')
   if [ $STATUS == 'shut' ]
   then
       #'setup_cache' is a dirty workaround for unsupported 'unsafe' cache mode
       #in older versions of virt-install utility
       setup_cache $name
       virsh start $name
       break
    fi
    sleep 10
done

echo "CentOS is installed successfully. Running Fuel master deployment..."

vm_master_ip=10.20.0.2
vm_master_username=root
vm_master_password=r00tme
vm_master_prompt='root@fuel ~]#'

# Wait until the machine gets installed and Puppet completes its run
wait_for_product_vm_to_install $vm_master_ip $vm_master_username $vm_master_password "$vm_master_prompt"

# Enable outbound network/internet access for the machine
enable_outbound_network_for_product_vm $vm_master_ip $vm_master_username $vm_master_password "$vm_master_prompt" $gateway_ip

echo "Product VM is ready"
