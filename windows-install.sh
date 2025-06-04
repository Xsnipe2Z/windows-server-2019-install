#!/bin/bash

set -e  # Exit on any error

apt install -y linux-image-amd64

apt install -y grub2 wimtools ntfs-3g rsync wget gdisk parted

# Get disk size and calculate partition sizes
disk_size_gb=$(parted /dev/sda --script print | awk '/^Disk \/dev\/sda:/ {print int($3)}')
disk_size_mb=$((disk_size_gb * 1024))
part_size_mb=$((disk_size_mb / 4))


parted /dev/sda --script mklabel gpt
parted /dev/sda --script mkpart primary ntfs 1MB ${part_size_mb}MB
parted /dev/sda --script mkpart primary ntfs ${part_size_mb}MB $((2 * part_size_mb))MB

sleep 5

partprobe /dev/sda

sleep 5



mkfs.ntfs -f /dev/sda1
mkfs.ntfs -f /dev/sda2


echo -e "r\ng\np\nw\nY\n" | gdisk /dev/sda


sleep 5

partprobe /dev/sda

sleep 5


mount /dev/sda1 /mnt

# Mount second partition to copy ISO content
mkdir -p /root/windisk
mount /dev/sda2 /root/windisk

# Install GRUB
grub-install --root-directory=/mnt /dev/sda

# Setup GRUB entry for Windows boot
mkdir -p /mnt/boot/grub
cat <<EOF > /mnt/boot/grub/grub.cfg
menuentry "Windows Installer" {
    insmod ntfs
    search --set=root --file=/bootmgr
    ntldr /bootmgr
    boot
}
EOF

# Download Windows ISO
cd /root/windisk
wget -O win2022.iso "https://bit.ly/winwin22022"

# Mount and extract ISO
mkdir winfile
mount -o loop win2022.iso winfile
rsync -avh --progress winfile/ /mnt/
umount winfile

# Download VirtIO drivers
wget -O virtio.iso https://bit.ly/virtvirtio
mount -o loop virtio.iso winfile
mkdir -p /mnt/sources/virtio
rsync -avh --progress winfile/ /mnt/sources/virtio

# Inject VirtIO path into boot.wim
cd /mnt/sources
echo 'add virtio /virtio_drivers' > cmd.txt
wimlib-imagex update boot.wim 2 < cmd.txt

# Done - Reboot
reboot