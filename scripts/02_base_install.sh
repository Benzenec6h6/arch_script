#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_ROOT/env/env.sh"
source "$ENV_FILE"

pacstrap /mnt base linux linux-firmware git base-devel
genfstab -U /mnt >> /mnt/etc/fstab

partuuid=$(blkid -s PARTUUID -o value "${DISK_ROOT}")
sed -i "s|^export PARTUUID=.*|export PARTUUID=\"$partuuid\"|" "$ENV_FILE"

cp "$ENV_FILE" /mnt/env.sh

mkdir -p /mnt/templates/bootloader
cp "$PROJECT_ROOT/templates/bootloader/"* /mnt/templates/bootloader/

cp -r "$PROJECT_ROOT/chroot" /mnt/chroot

arch-chroot /mnt /bin/bash /chroot/03_root.sh
