#!/bin/bash
source config_aws
config=$1
source $config
source functions.sh

prepare_dirs $location

uuid=$(/sbin/blkid -o value -s UUID /dev/xvda1)

#make_fstab $location/tmp/fstab "true" "simple"
#make_grub_conf $location/tmp/grub.conf "(hd0,0)" "ttyS0" $uuid

#bundle_vol 3500 $location $name "${block_device_mapping}" "mbr" $location/tmp/fstab $location/tmp/grub.conf
# the following replace bundle_vol
make_mbr_image $location/out/$name $size $uuid
prepare_mount_image_partitioned $location/out/$name $size
mount_partitioned_image $location/mnt
prepare_chroot $location/mnt
#copy_root_to_chroot $location/mnt

## Install Packages into CHROOT
install_packages_in_chroot $location $location/mnt

## TODO: uninstall grub2, install grub, reinstall grub2
## TODO: move this into a function...
chroot $location/mnt yum remove -y grub2
if [ ! -f ./grub-0.97-94.el6.x86_64.rpm ]; then
  curl -O http://mirror.centos.org/centos/6/os/x86_64/Packages/grub-0.97-94.el6.x86_64.rpm
fi
cp grub-0.97-94.el6.x86_64.rpm $location/mnt/tmp/
chroot $location/mnt rpm -ivh /tmp/grub-0.97-94.el6.x86_64.rpm
install_packages_in_chroot $location $location/mnt

## Install Grub into chroot MBR...
install_grub $location/mnt
install_grub $location/mnt
make_grub_conf $location "(hd0)" hvc0 $uuid
chroot $location/mnt mv /boot/grub/menu.lst /boot/grub/grub.conf
chroot $location/mnt ln -s /boot/grub/menu.lst /boot/grub/grub.conf

make_fstab $location/mnt/etc/fstab "false" "uuid"

# networking
make_sysconfig_network  $location/mnt/etc/sysconfig/network 
make_sysconfig_network_script  $location/mnt/etc/sysconfig/network-scripts/ifcfg-eth0
# sshd for AWS
make_sshd_config $location/mnt/etc/ssh/sshd_config

## TODO: restorecon
fix_restorecon $location/mnt

unmount_image $location/mnt
finish_unmount_image_partitioned 

bundle_image $location/out/$name $name $location/out ""
upload_bundle $location/out/$name.manifest.xml $s3_location
register_image "hvm" $s3_location/$name.manifest.xml $name
