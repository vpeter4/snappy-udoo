#!/bin/sh

# SYSTEM partition size in MB
PART1=72
PART2=1096
PART3=1096
PART4=... rest ...

# first vfat, rest ex4

# set device
node=$1

# destroy the partition table
echo --------------------------------------
dd if=/dev/zero of=${node} bs=1024 count=1

# call sfdisk to create partition table
echo --------------------------------------
sfdisk --force -uM ${node} << EOF
,${PART1},0x0c
,${PART2},0x83
,${PART3},0x83
,,0x83
;
EOF

echo --------------------------------------
sfdisk -uM --list ${node}
echo --------------------------------------
sfdisk -d ${node}
echo --------------------------------------
