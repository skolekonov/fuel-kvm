#!/bin/bash

source functions.sh

if [ $# -ne 2 ]
then
  echo "Usage: $0 iso-path #nodes"
  exit 1
fi

#Fuel master node
master_name=fuel-master #currently hardcoded in cleanup script
master_ram=1024
master_cpu=1
master_disk=30G
iso_path=$1

#Cluster nodes
node_name=fuel-slave #currently hardcoded in cleanup script
node_ram=2048
node_cpu=1
node_size=30G
node_count=$2

#Remove old VMs
remove_master
remove_slaves

#Deploy Fuel master node
bash deploy_master.sh $iso_path $master_name $master_ram $master_cpu $master_disk
#Start slaves
for (( i=1; i<=$node_count; i++ ))
do
   bash deploy_slave.sh $node_name-$RANDOM $node_ram $node_cpu $node_size
done
