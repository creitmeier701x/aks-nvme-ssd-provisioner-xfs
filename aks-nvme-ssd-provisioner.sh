#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail
SSD_NVME_DEVICE_LIST=($(ls /sys/block | grep nvme | xargs -I. echo /dev/. || true))
SSD_NVME_DEVICE_COUNT=${#SSD_NVME_DEVICE_LIST[@]}
RAID_DEVICE=${RAID_DEVICE:-/dev/md0}
RAID_CHUNK_SIZE=${RAID_CHUNK_SIZE:-512}  # Kilo Bytes
FILESYSTEM_BLOCK_SIZE=${FILESYSTEM_BLOCK_SIZE:-4096}  # Bytes
STRIDE=$(expr $RAID_CHUNK_SIZE \* 1024 / $FILESYSTEM_BLOCK_SIZE || true)
STRIPE_WIDTH=$(expr $SSD_NVME_DEVICE_COUNT \* $STRIDE || true)


# Checking if provisioning already happend
if [ -e /pv-disks ]
then
  echo 'Volumes already present in "/pv-disks"'
  echo -e "\n$(ls -Al /pv-disks | tail -n +2)\n"
  echo "I assume that provisioning already happend, doing nothing!"
  sleep infinity
fi

# Perform provisioning based on nvme device count
case $SSD_NVME_DEVICE_COUNT in
"0")
  echo 'No devices found of type "Microsoft NVMe Direct Disk"'
  echo "Maybe your node selectors are not set correct"
  exit 1
  ;;
"1")
  mkfs.xfs $SSD_NVME_DEVICE_LIST -f
  DEVICE=$SSD_NVME_DEVICE_LIST
  ;;
*)
  mdadm --create --verbose $RAID_DEVICE --level=0 -c ${RAID_CHUNK_SIZE} \
    --raid-devices=${#SSD_NVME_DEVICE_LIST[@]} ${SSD_NVME_DEVICE_LIST[*]}
  while [ -n "$(mdadm --detail $RAID_DEVICE | grep -ioE 'State :.*resyncing')" ]; do
    echo "Raid is resyncing.."
    sleep 1
  done
  echo "Raid0 device $RAID_DEVICE has been created with disks ${SSD_NVME_DEVICE_LIST[*]}"
  mkfs.xfs $RAID_DEVICE
  DEVICE=$RAID_DEVICE
  ;;
esac
echo "Filesystem has been created on $DEVICE"
UUID=$(blkid -s UUID -o value $DEVICE)
mkdir -p /pv-disks/$UUID
mount --uuid $UUID /pv-disks/$UUID
echo "Device $DEVICE has been mounted to /pv-disks/$UUID"
echo "NVMe SSD provisioning is done and I will go to sleep now"

#sleep infinity