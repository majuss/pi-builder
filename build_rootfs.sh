# Donwload specified raspios and build a root fs which is ingestible by the builder pipeline
RSYNC_FLAGS="-a -l --modify-window=1 --recursive"

sudo -H rm -rf os_fs os_mnt boot_mnt
sudo -H rm -rf originalimage.img

curl  -L -f https://downloads.raspberrypi.org/raspios_lite_armhf/images/raspios_lite_armhf-2023-05-03/2023-05-03-raspios-bullseye-armhf-lite.img.xz -o originalimage.img.xz
unxz -f originalimage.img.xz
#sudo fdisk -l image.img
mkdir os_mnt
sudo mount -o offset=$((512*532480)) originalimage.img os_mnt/ # mount os
mkdir os_fs
sudo -H rsync ${RSYNC_FLAGS} os_mnt/* os_fs/

sudo umount os_mnt
mkdir boot_mnt
sudo mount -o offset=$((512*8192)),sizelimit=$((512*532479)) originalimage.img boot_mnt/ # mount boot

sudo -H rsync ${RSYNC_FLAGS} boot_mnt/* os_fs/boot

sudo umount boot_mnt
cd os_fs
sudo -H tar -czf base-rootfs-rpi4.tar.gz * --numeric-owner

cp base-rootfs-rpi4.tar.gz ../

sudo -H rm -rf os_fs os_mnt boot_mnt