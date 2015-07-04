#!/bin/sh
#
# script based on
#  Snappy with Ubuntu Core for Cubox-i and Hummingboard from dz0ny
# https://github.com/dz0ny/snappy-cubox-i/commits/master
#

# stderr to stdout
exec 2>&1

_ERR_HDR_FMT_INFO="\033[47;30m info %.23s: %s - %s \033[0m"
_ERR_MSG_FMT_INFO="${_ERR_HDR_FMT_INFO}%s\n"
_ERR_HDR_FMT_ERR="\033[47;32m info %.23s: %s - %s \033[0m"
_ERR_MSG_FMT_ERR="${_ERR_HDR_FMT_ERR}%s\n"

function info() {
  printf "$_ERR_MSG_FMT_INFO" ${BASH_SOURCE[1]##*/} ${BASH_LINENO[0]} "${@}"
}

function error() {
	printf "$_ERR_MSG_FMT_ERR" ${BASH_SOURCE[1]##*/} ${BASH_LINENO[0]} "${@}"
}

function abort() {
	error "                          "
	error "script aborted with error."
	error "                          "
	exit 1
}

function clean() {
	rm -fr kernel
	rm -fr u-boot
	rm -fr snappy_package
	rm -f device.tar.xz
	rm -f snappy*.img*
	rm -fr snappy-tbs-matrix-mfgtool2
	rm -f snappy-tbs-matrix-mfgtool2.zip
}

function distclean() {
	clean
	rm -fr gcc-linaro-arm
	rm -f archive-snappy.tgz
}

function patch_files() {
	for f in $1; do
	  if [ -f "$f" ]; then
	    printf "\npatch using file $f"
	    patch -p1 --no-backup-if-mismatch <$f
	  fi
	done
}

trap 'abort' 0

set -e

error "==============================="
error "============ START ============"
error "==============================="
echo

if [ "$1" = "clean" ]; then
	info "Calling clean..."
	clean
	info "Done..."
	trap : 0
	exit 0
elif [ "$1" = "distclean" ]; then
	info "Calling distclean..."
	info ""
	distclean
	info "Done..."
	trap : 0
	exit 0
elif [ "$1" = "save" ]; then
	info "Calling save..."
	info ""
	tar -czf archive-snappy.tgz patches* snappy_defaults matrix_mfgtool2_files *.config* *.sh*
	info "Done. Archive archive-snappy.tgz ready..."
	trap : 0
	exit 0
fi

if [ "$1" = "matrix" ]; then
	info "Building for matrix..."
	PLATFORM=matrix
else
	info "Building for udoo..."
	PLATFORM=udoo
fi

export PATH=${PATH}:$(pwd)/gcc-linaro-arm/bin
export ARCH=arm
export CROSS_COMPILE=arm-linux-gnueabihf-

CONCURRENCY_MAKE_LEVEL=$(cat /proc/cpuinfo | grep -c '^processor[[:cntrl:]]*:')

rm -rf snappy_package
rm -f device.tar.xz
rm -f snappy*.img*

cp -r snappy_defaults snappy_package
mkdir -p snappy_package/assets
mkdir -p snappy_package/assets/dtbs
mkdir -p snappy_package/system
mkdir -p dl

echo
info "==============================="
if [ ! -f "dl/gcc-linaro-arm-linux-gnueabihf-4.7-2013.04-20130415_linux.tar.xz" ]; then	
	info "Downloading gcc-linaro-arm..."
	wget -O dl/gcc-linaro-arm-linux-gnueabihf-4.7-2013.04-20130415_linux.tar.xz https://releases.linaro.org/13.04/components/toolchain/binaries/gcc-linaro-arm-linux-gnueabihf-4.7-2013.04-20130415_linux.tar.xz
fi

if [ ! -d "gcc-linaro-arm" ]; then	
	info "Extracting gcc-linaro-arm..."
	tar xJf dl/gcc-linaro-arm-linux-gnueabihf-4.7-2013.04-20130415_linux.tar.xz
	mv gcc-linaro-arm-linux-gnueabihf-4.7-2013.04-20130415_linux gcc-linaro-arm
fi

if [ "$PLATFORM" = "matrix" ]; then  
	echo
	info "==============================="
	if [ ! -f "dl/mfgtool2-tbs-matrix-1.0.zip" ]; then	
		info "Downloading mfgtool2..."
		wget -O dl/mfgtool2-tbs-matrix-1.0.zip http://sources.openelec.tv/5.0.0/mfgtool2-tbs-matrix-1.0.zip
	fi
	
	if [ ! -d "snappy-tbs-matrix-mfgtool2" ]; then	
		info "Extracting mfgtool2..."
		unzip -q dl/mfgtool2-tbs-matrix-1.0.zip
		mv mfgtool2-tbs-matrix-1.0 snappy-tbs-matrix-mfgtool2
		
		rm -f snappy-tbs-matrix-mfgtool2/*.bat
		rm -f snappy-tbs-matrix-mfgtool2/Profiles/MX6Q\ Linux\ Update/OS\ Firmware/*.png
		
		cp matrix_mfgtool2_files/cfg.ini snappy-tbs-matrix-mfgtool2/
		cp matrix_mfgtool2_files/partitition-emmc.sh snappy-tbs-matrix-mfgtool2/Profiles/MX6Q\ Linux\ Update/OS\ Firmware/
		cp matrix_mfgtool2_files/ucl2.xml snappy-tbs-matrix-mfgtool2/Profiles/MX6Q\ Linux\ Update/OS\ Firmware/
		
		mkdir -p snappy-tbs-matrix-mfgtool2/Profiles/MX6Q\ Linux\ Update/OS\ Firmware/snappy/
	fi
fi

info "Generating u-boot boot script..."
echo

rm -f snappy_package/boot/boot.scr
mkimage -C none \
				-A arm \
				-T script \
				-d snappy_defaults/boot/boot.scr \
				snappy_package/boot/boot.scr

echo
info "==============================="
# http://system-image.ubuntu.com/pool/device-bf0a49e75a3deb99855f186906f17d7668e2dcc3a0b38f5feade3e6f7c75e9b8.tar.xz
# http://people.canonical.com/~platform/snappy/
# http://people.canonical.com/~platform/snappy/device_part_armhf.tar.xz
# http://people.canonical.com/~platform/snappy/initrd.img

get_initrd_img_big() {
	if [ ! -f "dl/device-ubuntu_porting_default.tar.xz" ]; then
		info "Getting Ubuntu default device.tar.xz"
		wget -O dl/device-ubuntu_porting_default.tar.xz "http://system-image.ubuntu.com/pool/device-bf0a49e75a3deb99855f186906f17d7668e2dcc3a0b38f5feade3e6f7c75e9b8.tar.xz"
	fi
	
	pushd snappy_package/assets >/dev/null
	
	rm -f initrd.img
	tar -xJf ../../dl/device-ubuntu_porting_default.tar.xz assets/initrd.img
	mv assets/initrd.img .
	rmdir assets
	
	popd >/dev/null
}

get_initrd_img_small() {
	if [ ! -f "dl/initrd.img" ]; then
		info "Getting Ubuntu default initrd.img"
		wget -O dl/initrd.img http://people.canonical.com/~platform/snappy/initrd.img
	fi
	
	cp dl/initrd.img snappy_package/assets
}

#get_initrd_img_big
get_initrd_img_small

echo
info "==============================="

if [ ! -f "dl/u-boot-2015.01.tar.bz2" ]; then
	info "Downloading u-boot..."
	wget -O dl/u-boot-2015.01.tar.bz2 ftp://ftp.denx.de/pub/u-boot/u-boot-2015.01.tar.bz2
fi

if [ ! -d "u-boot" ]; then
	info "Extracting u-boot..."
	tar -xjf dl/u-boot-2015.01.tar.bz2
	mv u-boot-2015.01 u-boot
	
	cp u-boot/include/configs/tbs2910.h u-boot/include/configs/tbs2910.h_orig
	
	#mkdir -p patches
	#wget -c -q -O patches/u-boot-0001-udoo-uEnv.txt-bootz-n-fixes.patch https://raw.githubusercontent.com/eewiki/u-boot-patches/master/v2015.01/0001-udoo-uEnv.txt-bootz-n-fixes.patch
	
	pushd u-boot >/dev/null
	info "Patching u-boot..."
	patch_files "../patches/u-boot-*.patch"
else
	pushd u-boot >/dev/null
fi

if [ "$PLATFORM" = "matrix" ]; then      
	UBOOT_CONFIG=tbs2910_defconfig
else
	UBOOT_CONFIG=udoo_quad_config
fi

make mrproper
info "U-boot using $UBOOT_CONFIG..."
make -j1 $UBOOT_CONFIG
make -j $CONCURRENCY_MAKE_LEVEL

cp u-boot.imx ../snappy_package/flashtool-assets/${PLATFORM}/

popd >/dev/null

### kernel start
echo
info "==============================="

linux_openelec() {
if [ ! -d "kernel" ]; then
	LINUX_DIR="linux-cuboxi-3.14-dc5edb8"
	
	if [ ! -f "dl/$LINUX_DIR.tar.xz" ]; then
		info "Getting kernel archive..."
		wget -O "dl/$LINUX_DIR.tar.xz" http://sources.openelec.tv/5.0.0/linux-cuboxi-3.14-dc5edb8.tar.xz

		#mkdir -p patches
		#info "Getting kernel apparmor patches..."
		#wget -c -q -O patches/apparmor-001.patch "http://kernel.ubuntu.com/git?p=ppisati/ubuntu-vivid.git;a=patch;h=cdf1d7d42c8be81b6fb94ed196962a73e49d5e20"
		#wget -c -q -O patches/apparmor-002.patch "http://kernel.ubuntu.com/git?p=ppisati/ubuntu-vivid.git;a=patch;h=6449590644fd05c469a1b5b821822b6d2e910850"
		#wget -c -q -O patches/apparmor-003.patch "http://kernel.ubuntu.com/git?p=ppisati/ubuntu-vivid.git;a=patch;h=3791236b61d21bfe2251963e06b5d1cf30019095"
		#wget -c -q -O patches/apparmor-004.patch "http://kernel.ubuntu.com/git?p=ppisati/ubuntu-vivid.git;a=patch;h=bf69831c2ea590976cc31d59165912fabf5ece2f"
		#wget -c -q -O patches/apparmor-005.patch "http://kernel.ubuntu.com/git?p=ppisati/ubuntu-vivid.git;a=patch;h=9ef3eeb8ccfbecdebbdc1fd0cc40c30b4949bf35"
		#wget -c -q -O patches/apparmor-006.patch "http://kernel.ubuntu.com/git?p=ppisati/ubuntu-vivid.git;a=patch;h=d2930a4a0320f7dad9dfcf82ead31eb87796e3ac"
		#wget -c -q -O patches/apparmor-007.patch "http://kernel.ubuntu.com/git?p=ppisati/ubuntu-vivid.git;a=patch;h=35d28e36fef0a4554622c83470a6acb948035470"
		#wget -c -q -O patches/apparmor-008.patch "http://kernel.ubuntu.com/git?p=ppisati/ubuntu-vivid.git;a=patch;h=cb7b2b908a0702414139c812c7fd19a048795e02"
		#wget -c -q -O patches/apparmor-009.patch "http://kernel.ubuntu.com/git?p=ppisati/ubuntu-vivid.git;a=patch;h=78d9521b5e287c1ccc300008d903a9e2d9d7591c"
		#wget -c -q -O patches/apparmor-010.patch "http://kernel.ubuntu.com/git?p=ppisati/ubuntu-vivid.git;a=patch;h=a55a83e050916583a53027d60ab2460ff0756c9a"
		#wget -c -q -O patches/apparmor-011.patch "http://kernel.ubuntu.com/git?p=ppisati/ubuntu-vivid.git;a=patch;h=dd0d8e76becd608a21de4c9984144d9ec2446cd9"
		#wget -c -q -O patches/apparmor-012.patch "http://kernel.ubuntu.com/git?p=ppisati/ubuntu-vivid.git;a=patch;h=2397f31f6811158a7402ee8b13cc349f0f1a9586"
	fi

	info "Extracting kernel archive..."
	tar xJf "dl/$LINUX_DIR.tar.xz"
	mv "$LINUX_DIR" kernel

	pushd kernel >/dev/null
	rm -rf security/apparmor
	
	info "Patching kernel apparmor files..."
	patch_files "../patches/apparmor-*.patch"
	
	info "Patching kernel other files..." 
	patch_files "../patches/linux-*.patch"
else
	pushd kernel >/dev/null
fi

echo
info "==============================="

touch .scmversion

USE_CUSTOM_KERNEL_CONFIG=1

if [ "$USE_CUSTOM_KERNEL_CONFIG" = "1" -a -f ../udoo-kernel.config ]; then
	info "Using custom kernel config..."
	cp ../udoo-kernel.config .config
	sed -i 's|CONFIG_DEFAULT_HOSTNAME=.*|CONFIG_DEFAULT_HOSTNAME=snappy|' .config
	scripts/kconfig/merge_config.sh .config arch/arm/configs/snappy/*.config
fi

if [ ! -f ".config" ]; then
	KERNEL_DEFCONFIG=imx_v7_cbi_hb_defconfig	# ne boota
	#KERNEL_DEFCONFIG=imx_v7_defconfig				# ne prevede
	info "Kernel using $KERNEL_DEFCONFIG..."
	make $KERNEL_DEFCONFIG
	#scripts/kconfig/merge_config.sh .config arch/arm/configs/snappy/*.config
	scripts/kconfig/merge_config.sh .config arch/arm/configs/snappy/*.config ../udoo-poweroff.config
fi
}	# linux_openelec

linux_solidrun() {
if [ ! -d "kernel" ]; then
	if [ ! -f "dl/linux-imx6-3.14.tar.xz" ]; then	
		info "cloning solidrun kernel..."
		git clone https://github.com/SolidRun/linux-imx6-3.14.git kernel --depth=1
		info "compressing solidrun kernel..."
		tar -cJf dl/linux-imx6-3.14.tar.xz kernel
	else
		tar -xJf dl/linux-imx6-3.14.tar.xz
	fi

	pushd kernel >/dev/null
	git rm -rf security/apparmor
	#git commit -s -m "UBUNTU: SAUCE: (no-up) apparmor: remove security/apparmor directory"
	patch -p1 --no-backup-if-mismatch < ../patches_solidrun/1.patch
	patch -p1 --no-backup-if-mismatch < ../patches_solidrun/2.patch
	patch -p1 --no-backup-if-mismatch < ../patches_solidrun/3.patch
	patch -p1 --no-backup-if-mismatch < ../patches_solidrun/4.patch
	patch -p1 --no-backup-if-mismatch < ../patches_solidrun/5.patch
	patch -p1 --no-backup-if-mismatch < ../patches_solidrun/6.patch
	patch -p1 --no-backup-if-mismatch < ../patches_solidrun/7.patch
	patch -p1 --no-backup-if-mismatch < ../patches_solidrun/8.patch
	patch -p1 --no-backup-if-mismatch < ../patches_solidrun/9.patch
	patch -p1 --no-backup-if-mismatch < ../patches_solidrun/10.patch
	patch -p1 --no-backup-if-mismatch < ../patches_solidrun/11.patch
	patch -p1 --no-backup-if-mismatch < ../patches_solidrun/12.patch
	#git commit -s -m "UBUNTU: SAUCE: Snappy and Core support"
	patch -p1 --no-backup-if-mismatch < ../patches_solidrun/13.patch
	patch -p1 --no-backup-if-mismatch < ../patches_solidrun/14.patch
	patch -p1 --no-backup-if-mismatch < ../patches_solidrun/15.patch
	patch -p1 --no-backup-if-mismatch < ../patches_solidrun/16.patch
	#git commit -s -m "Cubox-i: CEC and BT fixes"
else
	pushd kernel >/dev/null
fi

echo
info "==============================="

touch .scmversion
if [ ! -f ".config" ]; then
	info "kernel .config does not exist, using imx_v7_cbi_hb_defconfig"
	make imx_v7_cbi_hb_defconfig
	scripts/kconfig/merge_config.sh .config arch/arm/configs/snappy/*.config
fi
}	# linux_solidrun

linux_openelec
#linux_solidrun

make -j $CONCURRENCY_MAKE_LEVEL zImage
make -j $CONCURRENCY_MAKE_LEVEL imx6q-udoo.dtb imx6q-tbs2910.dtb
make -j $CONCURRENCY_MAKE_LEVEL modules

make modules_install INSTALL_MOD_PATH=../snappy_package/system

# strip kernel modules to minimize size
STRIP="${CROSS_COMPILE}strip"
for MOD in $(find ../snappy_package/system -name *.ko); do
  [ -f "$MOD" ] && $STRIP --strip-debug "$MOD"
done

# remove two symbolic links
rm -f ../snappy_package/system/lib/modules/*/source
rm -f ../snappy_package/system/lib/modules/*/build

cp arch/arm/boot/zImage ../snappy_package/assets/zImage
cp arch/arm/boot/dts/*.dtb ../snappy_package/assets/dtbs

# from kernel folder
popd >/dev/null
### kernel done

if [ "$PLATFORM" = "matrix" ]; then
	echo
	info "==============================="	
	if [ ! -d "rtl8188eu" ]; then
		if [ ! -f "dl/rtl8188eu.tar.xz" ]; then	
			info "cloning rtl8188eu..."
			git clone https://github.com/lwfinger/rtl8188eu.git -b v4.1.8_9499 rtl8188eu
			info "compressing rtl8188eu..."
			tar -cJf dl/rtl8188eu.tar.xz rtl8188eu
		else
			tar -xJf dl/rtl8188eu.tar.xz
		fi
	
		pushd rtl8188eu >/dev/null
	else
		pushd rtl8188eu >/dev/null
	fi

  make KSRC=$(pwd)/../kernel CONFIG_POWER_SAVING=n
	$STRIP --strip-debug 8188eu.ko

	KVER=$(basename ../snappy_package/system/lib/modules/3.*)
	#echo "KVER: $KVER"

	mkdir ../snappy_package/system/lib/modules/$KVER/kernel/drivers/wifi/
	cp 8188eu.ko ../snappy_package/system/lib/modules/$KVER/kernel/drivers/wifi/

	depmod -b ../snappy_package/system $KVER
	
	popd >/dev/null
fi

echo
info "==============================="
info "Creating device.tar.xz..."

du -hsc snappy_package | head -n1
pushd snappy_package >/dev/null

tar -cJf ../device.tar.xz *

popd >/dev/null

info "device.tar.xz ready"

echo
info "==============================="

SD_CARD_IMAGE_SIZE=3

info "Creating SD card image (requiring sudo privileges)..."
echo

sudo -s -- << EOF
	echo "PLATFORM: $PLATFORM"
	echo "SD_CARD_IMAGE_SIZE: $SD_CARD_IMAGE_SIZE"
	
	ubuntu-device-flash \
		-v core \
  	-o snappy-$PLATFORM.img \
  	--size $SD_CARD_IMAGE_SIZE \
  	--channel ubuntu-core/devel \
  	--device generic_armhf \
  	--platform $PLATFORM \
  	--enable-ssh \
  	--device-part=device.tar.xz
#  	--developer-mode

	if [ "$PLATFORM" = "matrix" ]; then
		./make_tbs_matrix_emmc_partitions.sh matrix p1
		./make_tbs_matrix_emmc_partitions.sh matrix p2
		./make_tbs_matrix_emmc_partitions.sh matrix p3
		./make_tbs_matrix_emmc_partitions.sh matrix p4
	fi
EOF

if [ "$PLATFORM" = "udoo" ]; then 
  echo
  info "Compressing Udoo SD card image..."
  gzip -c snappy-$PLATFORM.img >snappy-$PLATFORM.img.gz
	info "snappy-$PLATFORM.img.gz ready"
elif [ "$PLATFORM" = "matrix" ]; then  
  echo
  info "Compressing Matrix MfgTool2..."

	mv snappy-matrix-p[1-4].tgz snappy-tbs-matrix-mfgtool2/Profiles/MX6Q\ Linux\ Update/OS\ Firmware/snappy/
	cp snappy_package/flashtool-assets/matrix/u-boot.imx  snappy-tbs-matrix-mfgtool2/Profiles/MX6Q\ Linux\ Update/OS\ Firmware/snappy/
	
	zip -q -r snappy-tbs-matrix-mfgtool2.zip snappy-tbs-matrix-mfgtool2
fi

echo
info "==============================="
info "============ DONE ============="
info "==============================="
echo

trap : 0
exit 0

dummy() {

# to mount the first partition of the disk image:
mkdir m
sudo kpartx -a -v udoo-snappy.img
sudo mount -o loop /dev/mapper/loop0p1 m

# remove the loop devices:
sudo umount m
sudo kpartx -d -v udoo-snappy.img
rmdir m
sudo losetup -f

/dev/loop1                 63M   18M   46M  28% p1
/dev/loop2                976M  285M  624M  32% p2
/dev/loop3                976M  1.3M  908M   1% p3
/dev/loop4                924M  1.3M  859M   1% p4

# p1 - vfat
# p2 - ext4
# p3 - ext4
# p4 - ext4

dd if=/dev/zero of=udoo-manual-snappy.img bs=1M count=4000


}
