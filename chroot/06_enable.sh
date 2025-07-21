#!/usr/bin/env bash
set -euo pipefail
source ./env.sh

loginctl enable-linger "$USERNAME"

systemctl --machine="$USERNAME@" --user enable --now pipewire pipewire-pulse wireplumber

usermod -aG video,audio "$USERNAME"

if ! $is_vm; then
  systemctl enable --now bluetooth cups tlp
  usermod -aG input "$USERNAME"
fi

# libvirt
systemctl enable --now libvirtd
sed -Ei 's|^#(unix_sock_group = )"libvirt"|\1"libvirt"|' /etc/libvirt/libvirtd.conf
sed -Ei 's|^#(unix_sock_rw_perms = )"0770"|\1"0770"|' /etc/libvirt/libvirtd.conf
usermod -aG libvirt "$USERNAME"

# docker
systemctl enable --now docker containerd
usermod -aG docker "$USERNAME"

fc-cache -fv

# winetricks
sudo -u "$USERNAME" winetricks -q cjkfonts || true
