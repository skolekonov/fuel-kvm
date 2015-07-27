#!/bin/bash

function check_packages {
    PACKAGES="sshpass qemu-utils lvm2 libvirt-bin virtinst qemu-kvm e2fsprogs"
    for i in $PACKAGES; do
       dpkg -s $i &> /dev/null || apt-get install -y $i
    done
}

function create_network {
    local NET=$1
    virsh net-define ${NET}.xml
    virsh net-autostart ${NET}
    virsh net-start ${NET}
}

function setup_network {
    TMPD=$(mktemp -d)
    IMAGE_PATH=/var/lib/libvirt/images
    name=$1
    gateway_ip=$2
    modprobe nbd max_part=63
    qemu-nbd -n -c /dev/nbd0 $IMAGE_PATH/$name.qcow2
    sleep 2
    vgscan --mknode
    vgchange -ay os
    sleep 2
    mount /dev/os/root $TMPD
    sed "s/GATEWAY=.*/GATEWAY=\"$gateway_ip\"/g" -i $TMPD/etc/sysconfig/network
    echo "
DEVICE=eth1
TYPE=Ethernet
ONBOOT=yes
NM_CONTROLLED=no
BOOTPROTO=dhcp" > $TMPD/etc/sysconfig/network-scripts/ifcfg-eth1
    #Fuel 6.1 displays network setup menu by default
    sed -i 's/showmenu=yes/showmenu=no/g' $TMPD/root/.showfuelmenu
    umount $TMPD
    vgchange -an os
    qemu-nbd -d /dev/nbd0
}

function setup_cache {
    NAME=$1
    virsh dumpxml $NAME > $NAME.xml
    sed "s/cache='writeback'/cache='unsafe'/g" -i $NAME.xml
    virsh define $NAME.xml
    rm $NAME.xml
}

function is_product_vm_operational {
   ip=$1
   username=$2
   password=$3
   SSH_OPTIONS="StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
   SSH_CMD="sshpass -p ${3} ssh -o ${SSH_OPTIONS} ${2}@${1}"

   time=0
   LOG_FINISHED=""
   while [ -z "${LOG_FINISHED}" ]; do
       sleep 60
       time=$(($time+60))
       LOG_FINISHED=$(${SSH_CMD} "grep -o 'Fuel node deployment complete' /var/log/puppet/bootstrap_admin_node.log" 2>/dev/null)
       if [ ${time} -ge 7200 ]; then
           echo "Fuel deploy timeout"
           exit 1
       fi
   done
}

function wait_for_product_vm_to_install {
    ip=$1
    username=$2
    password=$3

    echo "Waiting for product VM to install. Please do NOT abort the script..."

    # Loop until master node gets successfully installed
    while ! is_product_vm_operational ${ip} ${username} ${password} ; do
        sleep 5
    done
}

function get_vnc() {
   domain=$1
   VNC_PORT=$(virsh vncdisplay $domain | awk -F ":" '{print $2}' | sed 's/\<[0-9]\>/0&/')
   echo "59${VNC_PORT}"
}

function remove_master () {
     master=$(virsh list --all | grep fuel-master | awk '{print $2}')
     if [ ! -z $master ]
     then
         echo "Deleting Fuel Master vm..."
         NAME=fuel-master
         for j in $(virsh snapshot-list $NAME | awk '{print $1}' | tail -n+3)
         do
            virsh snapshot-delete $NAME $j
         done
         virsh destroy $NAME
         virsh undefine $NAME
         virsh vol-delete --pool default fuel-master.qcow2
     fi
     master=$(virsh vol-list --pool default | grep fuel-master | awk '{print $2}')
     if [ ! -z $master ]
     then
          virsh vol-delete --pool default fuel-master.qcow2
     fi
}

function remove_slaves () {
   echo "Deleting Fuel nodes..."
   for i in $(virsh list --all | grep fuel-slave- | awk '{print $2}')
   do
      for j in $(virsh snapshot-list $i | awk '{print $1}' | tail -n+3)
      do
         virsh snapshot-delete $i $j
      done
      virsh destroy $i
      virsh undefine $i
   done

   for i in $(virsh vol-list --pool default | grep fuel-slave- | awk '{print $1}')
   do
      virsh vol-delete --pool default $i
   done
}
