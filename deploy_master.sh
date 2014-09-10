#!/bin/bash

source functions.sh
source bash_arg_parser/parse_args.sh


CONF='
    {
     "options":
      [
       {"opt":"n",
        "opt_long": "name",
        "arg": ":",
        "man": "Env name and prefix for the VM name.(mandatory option)"
       },
       {"opt":"c",
        "opt_long": "cpu",
        "arg": ":",
        "man": "CPU Number for VM. (Default: 2)"
       },
       {"opt":"r",
        "opt_long": "ram",
        "arg": ":",
        "man": "RAM in MB for VM. (Default: 4096)"
       },
       {"opt":"d",
        "opt_long": "disk",
        "arg": ":",
        "man": "Disk size for VM. (Defualt: 40G)"
       },
       {"opt":"i",
        "opt_long": "iso",
        "arg": ":",
        "man": "Path to FUEL ISO file. (Default: fuel.iso)"
       },
       {"opt":"p",
        "opt_long": "pxe_vlan",
        "arg": ":",
        "man": "PXE VLAN ID. (mandatory option)"
       }
     ]
    }'

ARGS=${@}

function parse_args {
    local _CONF=${1-$CONF}
    local _ARGS=${2-$ARGS}

    parse_default_args "${_CONF}" "${_ARGS}"

    eval set -- "${ARGS}"

    while true ; do
        case "$1" in
            # Custom options
            -n|--name)         NAME=$2 ; shift 2 ;;
            -c|--cpu)           CPU=$2 ; shift 2 ;;
            -r|--ram)           RAM=$2 ; shift 2 ;;
            -d|--disk)         DISK=$2 ; shift 2 ;;
            -i|--iso)           ISO=$2 ; shift 2 ;;
            -p|--pxe_vlan) PXE_VLAN=$2 ; shift 2 ;;

            # Exit
            --) shift ; break ;;
            *)  usage ; exit 1;;
        esac
    done

    #echo "Remaining arguments:"
    #for arg do echo '--> '"\`${arg}'" ; done
}

parse_args "$CONF" "$ARGS"

if [[ ${USER} != "root" ]]
then
    echo "This script should be run with root priveleges."
    echo "Terminating..."
    exit 1
fi

NAME=${NAME?"--name is mandatory option. use --help for more details"}
NAME=${NAME:-"test"}-fuel-master
RAM=${RAM:-2048}
CPU=${CPU:-1}
DISK=${DISK:-"40G"}
PXE_VLAN=${PXE_VLAN?"--pxe_vlan is mandatory option. Use --help for more details"}
ISO=${ISO:-"fuel.iso"}

if [[ ! -f ${ISO} ]]
then
    echo "ISO file \"${ISO}\" does not exist!"
    echo "Terminating..."
    exit 1
fi



### Confirm parameters

echo
echo "Your parameters are the following:"
echo "           Name: ${NAME}"
echo "            CPU: ${CPU}"
echo "            RAM: ${RAM}"
echo "           DISK: ${DISK}"
echo "       PXE VLAN: ${PXE_VLAN}"


### Start creating


create_disk ${NAME} ${DISK}

echo "Starting Fuel master vm..."

virt-install \
  --name=${NAME} \
  --cpu host \
  --ram=${RAM} \
  --vcpus=${CPU},cores=${CPU} \
  --os-type=linux \
  --os-variant=rhel6 \
  --virt-type=kvm \
  --disk "/var/lib/libvirt/images/${NAME}.qcow2" \
  --cdrom "${ISO}" \
  --noautoconsole \
  --network network=internal,model=virtio \
  --network network=internal,model=virtio \
  --graphics vnc,listen=0.0.0.0

GATEWAY_IP=172.18.161.1

while (true)
do
    STATUS=$(virsh dominfo ${NAME} | grep State | awk -F " " '{print $2}')
    if [ ${STATUS} == 'shut' ]
    then
        setup_iso ${NAME} ${GATEWAY_IP}
        setup_network ${NAME} ${PXE_VLAN}
        virsh start ${NAME}
        break
    fi

    sleep 10
done

echo "Running Fuel master deployment..."

