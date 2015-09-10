#!/bin/bash

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
net_driver=${net_driver:-e1000}
#Use user-defined bridge to setup external network for Fuel Master node
#Bridge name is hardcoded to 'br0', edit xml files to change
hosts_bridge=false
#Define your network's gateway here.
#It will be used as default on Fuel Master node
#By default gateway for fuel-adm-public virtual network will be used
#gateway_ip=172.18.78.1
gateway_ip=172.16.1.1

echo "Creating storage..."

virsh pool-info default &> /dev/null || create_pool
virsh vol-create-as --name $name.qcow2 --capacity $size --format qcow2 --allocation $size --pool default
pool_path=$(get_pool_path default)
iso_name=$(basename $iso_path)
if [ -f $pool_path/$iso_name ]; then
  sum1=$(md5sum $pool_path/$iso_name | awk '{print $1}')
  sum2=$(md5sum $iso_path | awk '{print $1}')
  if [ "$sum1" != "$sum2" ]; then
    rm -f $pool_path/$iso_name
    cp -f $iso_path $pool_path/
  fi
else
  cp -f $iso_path $pool_path/
fi

echo "Creating networks..."

#10.20.0.0/24 - pxe (isolated)
create_network fuel-pxe

#172.16.0.0/24 - public/floating (NAT)
create_network fuel-public

#172.16.1.0/24 - public/master-node (NAT)
create_network fuel-adm-public

if $hosts_bridge
then
    #directly connected to a host's bridge (br0)
    create_network fuel-external
    external_network=fuel-external
else
    external_network=fuel-adm-public
fi

echo "Starting Fuel master vm..."

virt-install \
  --name=$name \
  --ram=$ram \
  --vcpus=$cpu,cores=$cpu \
  --os-type=linux \
  --os-variant=rhel6 \
  --virt-type=kvm \
  --disk "$pool_path/$name.qcow2",cache=writeback,bus=virtio,serial=$(uuidgen) \
  --cdrom "$pool_path/$iso_name" \
  --noautoconsole \
  --network network=fuel-pxe,model=$net_driver \
  --network network=$external_network,model=$net_driver \
  --graphics vnc,listen=0.0.0.0
#  --cpu host \
#If cpu parameter is set to "host" with QEMU 2.0 hypervisor
#it causes critical failure during CentOS installation

echo "VNC port: $(get_vnc $name)"

virsh dominfo $name &> /dev/null || (echo "Fuel master failed to start" && exit 1)

#Fuel master is powered off after CentOS installation
#We are waiting for this moment to setup the VM and continue deployment
while (true)
do
   STATUS=$(virsh dominfo $name | grep State | awk '{print $2}')
   if [ $STATUS == 'shut' ]
   then
       #'setup_cache' is a dirty workaround for unsupported 'unsafe' cache mode
       #in older versions of virt-install utility
       setup_cache $name
       setup_network $name $gateway_ip
       virsh start $name
       break
    fi
    sleep 10
done

echo "CentOS is installed successfully. Running Fuel master deployment..."
vm_master_ip=10.20.0.2
vm_master_username=root
vm_master_password=r00tme

echo "VNC port: $(get_vnc $name)"

# Wait until the machine gets installed and Puppet completes its run
wait_for_product_vm_to_install $vm_master_ip $vm_master_username $vm_master_password || exit 1

echo "Product VM is ready"
