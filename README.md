fuel-kvm
========
Fuel Master deployment
----------------------
./deploy_master.sh prefix ram cpu disk iso-path vlan1

Prefix is a short name to make cluster resources' names unique. It is also used to safely remove cluster resources.

RAM - ram amount for virtual machine, in megabytes
CPU - virtual cpu number
DISK - virtual drive size, in gigabytes. Fuel Master requires at least 30G of disk space.
ISO-PATH - path to fuel iso which will be used or Fuel Master deployment
VLAN1 - vlan number for PXE interface (eth0 on Fuel Master and its slaves).
        All vms are connected to the same network, so vlans are required to isolate Fuel master nodes from each other.
        Please use only vlans from 3000 to 3015 for this interface due to libvirt network configuration.

This script will create a new virtual machine named $PREFIX-fuel-master and deploy Fuel Master on it.
This machine has the following network configuration:
eth0 - PXE, static, connected to the external network, selected VLAN.
eth1 - user access, external network, 172.18.161.0/24, DHCP. It's the public interface, added to the Fuel master automatically.
       You can use this interface to access Fuel master node from the Mirantis network.

Fuel Master VM gets the only accessible address from DHCP on eth1 interface, so the script isn't able to control its status after spawning.
When the script finishes its work, please access your VM using the VNC console and check its address by executing 'ifconfig eth1'.

Sample execution string: sudo ./deploy_master.sh sk308 1024 1 30G fuel-master-308-2014-07-10_02-01-14.iso

Fuel Nodes deployment
---------------------
sudo ./deploy_slaves.sh prefix ram cpu disk vlan1 vlan2 vlan3

This script will create a new virtual machine named $PREFIX-fuel-slave-$RANDOM_NUMBER.

VLAN1 - the same vlan which was used during Fuel deployment, it's required to make nodes boot over PXE.
VLAN2 - vlan to use for management or storage network between nodes of a cluster
VLAN3 - vlan to use for management or storage network between nodes of a cluster

Please use 3015-3050 and 4001-4030 vlans for VLAN2/VLAN3.

Slaves will be created with 4 interfaces:

eth0 - PXE (same as on Fuel Master)
eth1 - management or storage network with only 1 selected vlan allowed
eth2 - management or storage network with only 1 selected vlan allowed
eth3 - public network (also can be used as management/storage network)

After spawning they will try to boot over PXE.

Sample execution string: sudo ./deploy_slaves.sh sk351 2048 2 25G 3001 3016 3017

Clean up script
-------------------
