#!/bin/bash

mapfile -t disks < <(lsblk -ndo NAME,SIZE,TYPE | awk '$3=="disk" && $1 !~ /^loop/ {print $1, $2}')
network=(dhcpcd networkmanager)
bootloader=(grub systemd-boot)

if [ ${#disks[@]} -eq 0 ]; then
    echo "no device"
    exit 1
fi

for i in "${!disks[@]}" ; do
    name=$(echo "${disks[$i]}" | awk '{print $1}')
    size=$(echo "${disks[$i]}" | awk '{print $2}')
    echo "$((i+1)). /dev/$name (${size})"
done

read -p 'select index>' index

if [[ "$index" =~ ^[0-9]+$ ]] && [[ 0 -lt index ]] && [[ index -le ${#disks[@]} ]]; then
    disk="/dev/$(echo "${disks[$((index-1))]}" | awk '{print $1}')"
    echo "selected disk: $disk"
else
    echo "invalid selection"
    exit 1
fi

for i in "${!network[@]}" ; do
    echo "$((i+1)). ${network[$i]}"
done

read -p 'select network tool by index>' index

if [[ "$index" =~ ^[0-9]+$ ]] && [[ 0 -lt index ]] && [[ index -le ${#network[@]} ]]; then
    net="$(echo "${network[$((index-1))]}" | awk '{print $1}')"
    echo "network tool disk: $net"
else
    echo "invalid selection"
    exit 1
fi

for i in "${!bootloader[@]}" ; do
    echo "$((i+1)). ${bootloader[$i]}"
done

read -p 'select network tool by index>' index

if [[ "$index" =~ ^[0-9]+$ ]] && [[ 0 -lt index ]] && [[ index -le ${#bootloader[@]} ]]; then
    loader="$(echo "${bootloader[$((index-1))]}" | awk '{print $1}')"
    echo "selected bootloader: $loader"
else
    echo "invalid selection"
    exit 1
fi

echo "formatting as GPT disk"
sgdisk --zap-all "$disk" 
sgdisk -n 1:0:+512M -t 1:ef00 -c 1:"EFI System Partition" "$disk"
sgdisk -n 2:0:+4G -t 2:8200 -c 2:"Swap" "$disk"
sgdisk -n 3:0:0 -t 3:8300 -c 3:"Linux Root" "$disk"

mkfs.fat -F32 "${disk}1"
mkswap "${disk}2"
swapon "${disk}2"
mkfs.ext4 -L root "${disk}3"

mkdir -p /mnt/boot/efi
mount "${disk}1" /boot/efi
mount "${disk}3" /mnt

pacstrap /mnt base linux linux-firmware
genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt /bin/bash <<'EOF'

ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime
pacman -S  sudo dhcpcd systemd git nano fastfetch
systemctl enable dhcpcd

bootctl --esp-path=/boot/efi install
cat > /boot/loader/loader.conf <<LOADER
default arch
timeout 3
editor no
LOADER

PARTUUID=$(blkid -s PARTUUID -o value "${disk}3")
cat > /boot/loader/entries/arch.conf <<ENTRY
title arch linux
linux /vmlinuz-linux
initrd /initramfs-linux.img
options root=PARTUUID=$PARTUUID rw
ENTRY

sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
EOF

swapoff "${disk}2"
umount -R /mnt
#reboot
