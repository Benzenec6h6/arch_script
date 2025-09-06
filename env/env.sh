#!/usr/bin/env bash

export ARCH_TIMEZONE="Asia/Tokyo"
export USERNAME=""          # install時に読み取り
export DISK=""              # install時に選択
export DISK_BOOT=""   # /boot用パーティション1
export DISK_SWAP=""   # swap用パーティション2
export DISK_ROOT=""   # /用パーティション3
export LOADER=""            # grub or systemd-boot
export NET_TOOL=""          # dhcpcd or NetworkManager
export AUR_HELPER=""        # yay or paru
export PARTUUID=""
export is_vm=""