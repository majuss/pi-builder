CUSTOM_IMG_NAME=raspberry_pi_os.img
CUSTOM_IMG_SIZE=4096
PT_FILENAME="partition_table.txt"
RSYNC_FLAGS="-a -l --modify-window=1 --recursive"

sudo rm -rf out
mkdir out
cd out
dd if=/dev/zero of=./${CUSTOM_IMG_NAME} bs=1M count=${CUSTOM_IMG_SIZE}

sudo /sbin/sfdisk -d "../originalimage.img" > "${PT_FILENAME}"
sudo /sbin/sfdisk ${CUSTOM_IMG_NAME} < "${PT_FILENAME}"

sudo /sbin/losetup -fP ${CUSTOM_IMG_NAME}
LODEV=$(/sbin/losetup -a | grep "${CUSTOM_IMG_NAME}" | awk -F: '{ print $1 }')

sudo mkfs.fat ${LODEV}p1
mkdir mt_boot
sudo mount ${LODEV}p1 mt_boot
sudo rsync ${RSYNC_FLAGS} ../.cache/result-rootfs/boot/* mt_boot/

# sudo touch mt_boot/ssh
# cd ..
# sudo cp userconf mt_boot
# sudo cp wpa_supplicant.conf mt_boot
# cd out

sudo mkfs.ext4 ${LODEV}p2
mkdir mt_root
sudo mount ${LODEV}p2 mt_root
sudo rsync ${RSYNC_FLAGS} ../.cache/result-rootfs/* mt_root/

sudo umount mt_root
sudo umount mt_boot
sudo /sbin/losetup -D

sudo rm -rf out