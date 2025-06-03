#!/bin/bash

set -e  # Exit on any error


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
wget -O win2019.iso "http://bit.ly/4mPJOQE"

# Mount and extract ISO
mkdir winfile
mount -o loop win2019.iso winfile
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