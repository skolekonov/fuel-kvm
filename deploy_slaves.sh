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
        "man": "Env name and prefix for the VM name. (Default: test)"
       },
       {"opt":"c",
        "opt_long": "cpu",
        "arg": ":",
        "man": "CPU Number for VM. (Default: 1)"
       },
       {"opt":"r",
        "opt_long": "ram",
        "arg": ":",
        "man": "RAM in MB for VM. (Default: 2048)"
       },
       {"opt":"d",
        "opt_long": "disk",
        "arg": ":",
        "man": "Disk size in GB for VM. (Default: 40G)"
       },
       {"opt":"p",
        "opt_long": "pxe_vlan",
        "arg": ":",
        "man": "PXE VLAN ID. (mandatory option)"
       },
       {"opt":"m",
        "opt_long": "management_vlan",
        "arg": ":",
        "man": "Management VLAN ID. (mandatory option)"
       },
       {"opt":"s",
        "opt_long": "storage_vlan",
        "arg": ":",
        "man": "Storage VLAN ID. (mandatory option)"
       }
     ]
    }'

ARGS=${@}

function parse_args {
    local _CONF=${1-$CONF}
    local _ARGS=${2-$ARGS}

    parse_default_args "$_CONF" "$_ARGS"

    eval set -- "$ARGS"

    while true ; do
        case "$1" in
            # Custom options
            -n|--name)                 NAME=$2 ; shift 2 ;;
            -c|--cpu)                   CPU=$2 ; shift 2 ;;
            -r|--ram)                   RAM=$2 ; shift 2 ;;
            -d|--disk)                 DISK=$2 ; shift 2 ;;
            -p|--pxe_vlan)         PXE_VLAN=$2 ; shift 2 ;;
            -m|--management_vlan) MGMT_VLAN=$2 ; shift 2 ;;
            -s|--storage_vlan)    STRG_VLAN=$2 ; shift 2 ;;

            # Exit
            --) shift ; break ;;
            *) echo "Internal error!" ; exit 1 ;;
        esac
    done

    echo "Remaining arguments:"
    for arg do echo '--> '"\`$arg'" ; done
}


if [[ $USER != "root" ]]
then
    echo "This script should be run with root priveleges."
    exit 1
fi

parse_args "$CONF" "$ARGS"

NAME=${NAME:-"test"}-fuel-slave-$RANDOM
RAM=${RAM:-4096}
CPU=${CPU:-2}
DISK=${DISK:-"40G"}
PXE_VLAN=${PXE_VLAN?"--pxe_vlan is mandatory option. Use --help for more details"}
MGMT_VLAN=${MGMT_VLAN?"--management_vlan is mandatory option. Use --help for more details"}
STRG_VLAN=${STRG_VLAN?"--storage_vlan is mandatory option. Use --help for more details"}

### Confirm parameters

echo
echo "Your parameters are the following:"
echo "           Name: ${NAME}"
echo "            CPU: ${CPU}"
echo "            RAM: ${RAM}"
echo "           DISK: ${DISK}"
echo "       PXE VLAN: ${PXE_VLAN}"
echo "Management VLAN: ${MGMT_VLAN}"
echo "   Storage VLAN: ${STRG_VLAN}"
echo


### Start creating


create_disk ${NAME} ${DISK}

virt-install \
  --name=$NAME \
  --cpu host \
  --ram=$RAM \
  --vcpus=$CPU,cores=$CPU \
  --os-type=linux \
  --os-variant=rhel6 \
  --virt-type=kvm \
  --pxe \
  --boot network,hd \
  --disk "/var/lib/libvirt/images/$NAME.qcow2" \
  --noautoconsole \
  --network network=internal,model=virtio \
  --network network=internal,model=virtio \
  --network network=internal,model=virtio \
  --network network=internal,model=virtio \
  --graphics vnc,listen=0.0.0.0

virsh destroy $NAME
setup_network $NAME $PXE_VLAN
setup_network $NAME $MGMT_VLAN
setup_network $NAME $STRG_VLAN

virsh start $NAME
echo "Started fuel-slave $NAME"

