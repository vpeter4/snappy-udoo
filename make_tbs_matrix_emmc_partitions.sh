#!/bin/sh

# stderr to stdout
exec 2>&1

	if [ "$(id -u)" != "0" ]; then
		echo "This script must be run as root"
		exit 1
	fi

	PLATFORM=$1
	PART_NUM=$2

	echo " platform: $PLATFORM"
	echo "partition: $PART_NUM"
		
	if [ -z "$PLATFORM" -o -z "$PART_NUM" ]; then
		echo "No platformor partition  specified..."
		exit 1
	fi
	
	dir=$(mktemp -d)
	#echo "dir: $dir"
	
	losetup_before=$(losetup -f)

	#kpartx -r -s -a -v snappy-$PLATFORM.img
	kpartx -r -s -a snappy-$PLATFORM.img

	#LOOP_NUM=$(kpartx -s -v snappy-$PLATFORM.img | sed -E 's|.*(loop[0-9])p.*|\1|g' | head -1)
	LOOP_NUM=$(kpartx -s snappy-$PLATFORM.img | sed -E 's|.*(loop[0-9])p.*|\1|g' | head -1)
	echo "loop: $LOOP_NUM"

	mount -o loop /dev/mapper/${LOOP_NUM}${PART_NUM} $dir
	
	#ls -al $dir
	
	TAR_FILE=snappy-$PLATFORM-$PART_NUM.tgz
	
	tar czf "$TAR_FILE" -C $dir .
	chmod 666 "$TAR_FILE"
	
	umount $dir
	sync
	rmdir $dir
	#kpartx -r -s -d -v snappy-$PLATFORM.img
	kpartx -r -s -d snappy-$PLATFORM.img

	losetup_after=$(losetup -f)
	
	if [ "$losetup_after" != "$losetup_before" ]; then
		echo "something went wrong, manually delete loop"
		echo "losetup_before: $losetup_before"
		echo " losetup_after: $losetup_after"
	fi
