#!/usr/bin/env bash
set -euo pipefail
source ./env.sh

ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime
sed -i -e '/^#\(en_US\|ja_JP\)\.UTF-8/s/^#//' /etc/locale.gen
echo "KEYMAP=jp106"     > /etc/vconsole.conf
locale-gen

useradd -m -G wheel -s /bin/bash "\$USERNAME"
echo "root:root" | chpasswd
echo "\$USERNAME:\$USERNAME" | chpasswd

sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

for script in /chroot/{04..07}_*.sh; do
  bash "$script"
done