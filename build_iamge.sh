
sudo -H rm -rf os_fs
sudo -H rm -rf image.img
#curl  -L -f https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2023-02-22/2023-02-21-raspios-bullseye-arm64-lite.img.xz -o image.img.xz

curl  -L -f https://downloads.raspberrypi.org/raspios_lite_armhf/images/raspios_lite_armhf-2023-02-22/2023-02-21-raspios-bullseye-armhf-lite.img.xz -o image.img.xz
unxz -f image.img.xz
sudo fdisk -l image.img
mkdir os_mnt
sudo mount -o offset=$((512*532480)) image.img os_mnt/
mkdir os_fs
sudo -H cp -a os_mnt/* os_fs/
# rsync -vh --progress --modify-window=1 --recursive --ignore-errors os_mnt/ os_fs
sudo umount os_mnt
mkdir boot_mnt
sudo mount -o offset=$((512*8192)),sizelimit=$((512*532479)) image.img boot_mnt/

sudo -H cp -a boot_mnt/* os_fs/boot

# rsync -vh --progress --modify-window=1 --recursive --ignore-errors boot_mnt/ os_fs/boot
sudo umount boot_mnt
cd os_fs
sudo -H tar -czvf base-rootfs-rpi4.tar.gz * --numeric-owner