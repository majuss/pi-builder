sudo -H rm -rf os_fs
sudo -H rm -rf image.img

curl  -L -f https://downloads.raspberrypi.org/raspios_lite_armhf/images/raspios_lite_armhf-2023-02-22/2023-02-21-raspios-bullseye-armhf-lite.img.xz -o image.img.xz
unxz -f image.img.xz
sudo fdisk -l image.img
mkdir os_mnt
sudo mount -o offset=$((512*532480)) image.img os_mnt/ # mount os
mkdir os_fs
sudo -H cp -a os_mnt/* os_fs/

sudo umount os_mnt
mkdir boot_mnt
sudo mount -o offset=$((512*8192)),sizelimit=$((512*532479)) image.img boot_mnt/ # mount boot

sudo -H cp -a boot_mnt/* os_fs/boot

sudo umount boot_mnt
cd os_fs
sudo -H tar -czvf base-rootfs-rpi4.tar.gz * --numeric-owner

cp base-rootfs-rpi4.tar.gz ../../majuss_builder/pi-builder/