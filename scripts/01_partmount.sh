#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_ROOT/env/env.sh"
source "$ENV_FILE"

echo "[+] Wipe & GPT"
sgdisk --zap-all "$DISK"

if [[ -d /sys/firmware/efi ]]; then
  sgdisk -n1:0:+512M -t1:ef00 -c1:"EFI" "$DISK"
else
  sgdisk -n1:0:+1M   -t1:ef02 -c1:"BIOS" "$DISK"
fi
sgdisk -n2:0:+4G   -t2:8200 -c2:"swap" "$DISK"
sgdisk -n3:0:0     -t3:8300 -c3:"root" "$DISK"

mkfs.ext4 -L root "${DISK}3"
mount "${DISK}3" /mnt

mkswap   "${DISK}2" && swapon "${DISK}2"

if [[ -d /sys/firmware/efi ]]; then
  mkfs.fat -F32 "${DISK}1"
  if [[ $LOADER == systemd-boot ]]; then
    mkdir -p /mnt/boot
    mount "${DISK}1" /mnt/boot
  else
    mkdir -p /mnt/boot/efi
    mount "${DISK}1" /mnt/boot/efi
  fi
fi