#!/usr/bin/env bash
set -euo pipefail
source ./env.sh

pacstrap /mnt base linux linux-firmware git base-devel
genfstab -U /mnt >> /mnt/etc/fstab

# ルートパーティションの PARTUUID を取得
partuuid=$(blkid -s PARTUUID -o value "${DISK}3")
sed -i "s|^export PARTUUID=.*|export PARTUUID=\"$partuuid\"|" ./env.sh

cp env.sh /mnt/env.sh
cp -r bootloader /mnt/bootloader
cp -r arch-setup /mnt/arch-setup

arch-chroot /mnt /bin/bash /arch-setup/03-root.sh
