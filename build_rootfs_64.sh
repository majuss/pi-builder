# Donwload specified raspios and build a root fs which is ingestible by the builder pipeline
RSYNC_FLAGS="-a -l --modify-window=1 --recursive"
IMAGE_NAME="originalimage64.img"

sudo -H rm -rf os_fs os_mnt boot_mnt
sudo -H rm -rf $IMAGE_NAME

curl  -L -f https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2023-05-03/2023-05-03-raspios-bullseye-arm64-lite.img.xz -o $IMAGE_NAME.xz
unxz -f $IMAGE_NAME.xz
#sudo fdisk -l image.img
mkdir os_mnt
sudo mount -o offset=$((512*532480)) $IMAGE_NAME os_mnt/ # mount os
mkdir os_fs
sudo -H rsync ${RSYNC_FLAGS} os_mnt/* os_fs/

sudo umount os_mnt
mkdir boot_mnt
sudo mount -o offset=$((512*8192)),sizelimit=$((512*532479)) $IMAGE_NAME boot_mnt/ # mount boot

sudo -H rsync ${RSYNC_FLAGS} boot_mnt/* os_fs/boot

sudo umount boot_mnt
cd os_fs
sudo -H tar -czf base-rootfs-rpi4.tar.gz * --numeric-owner

cp base-rootfs-rpi4.tar.gz ../

cd ..
sudo -H rm -rf os_fs os_mnt boot_mnt