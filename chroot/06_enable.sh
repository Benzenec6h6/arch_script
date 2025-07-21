#!/usr/bin/env bash
set -euo pipefail
source ./env.sh

usermod -aG video,audio "$USERNAME"

if ! $is_vm; then
  systemctl enable bluetooth cups tlp
  usermod -aG input "$USERNAME"
fi

# libvirt
systemctl enable libvirtd
sed -Ei 's|^#(unix_sock_group = )"libvirt"|\1"libvirt"|' /etc/libvirt/libvirtd.conf
sed -Ei 's|^#(unix_sock_rw_perms = )"0770"|\1"0770"|' /etc/libvirt/libvirtd.conf
usermod -aG libvirt "$USERNAME"

# docker
systemctl enable docker containerd
usermod -aG docker "$USERNAME"

# winetricks
sudo -u "$USERNAME" winetricks -q cjkfonts || true

fc-cache -fv