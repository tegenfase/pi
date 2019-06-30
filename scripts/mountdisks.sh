#!/bin/sh

# Automagically mount external drives

i=0
mountables=$(lsblk -lp | grep "part $" | awk '{print $1}')
[[ "$mountables" = "" ]] && exit 1

for disk in $mountables
do
    mntpoint="/mnt/disk$i"

    echo $i $disk $mntpoint

    [[ ! -d $mntpoint ]] && mkdir $mntpoint
    mount $disk
    ((i++))

done
