#!/bin/bash

source functions.sh

if [ $# -lt 1 ]
then
  echo "Usage: $0 [cleanup|snapshot-nodes <name>|revert-nodes <name>]"
  exit 1
fi

OPERATION=$1

case "$OPERATION" in

 "cleanup")
  echo "Cleaning up..."
  remove_master
  remove_slaves
 ;;
 "snapshot-nodes")
  echo "Snapshotting nodes..."
  SNAP_NAME=$2
  for i in $(virsh list | grep fuel-slave- | awk '{print $2}')
  do
    virsh snapshot-create-as $i $SNAP_NAME
  done
 ;;
  "revert-nodes")
  echo "Reverting nodes..."
  SNAP_NAME=$2
  for i in $(virsh list | grep fuel-slave- | awk '{print $2}')
  do
    virsh snapshot-revert $i $SNAP_NAME
  done
 ;;
  *)
  echo "Unsupported command"
  echo "Usage: $0 [cleanup|snapshot-nodes <name>|revert-nodes <name>]"
  exit 1
esac
