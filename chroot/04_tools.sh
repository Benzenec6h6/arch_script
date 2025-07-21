#!/usr/bin/env bash
set -euo pipefail
source ./env.sh

pacman -S --noconfirm sudo nano fastfetch "$NET_TOOL"

# network tools
if [[ $NET_TOOL == dhcpcd ]]; then
  systemctl enable dhcpcd
else
  systemctl enable NetworkManager
fi

# ブートローダーの分岐
if [[ $LOADER == grub ]]; then
    # GRUB
    pacman -S --noconfirm grub efibootmgr

    if [[ -d /sys/firmware/efi ]]; then          # ← UEFI で起動している
        grub-install --target=x86_64-efi \
                     --efi-directory=/boot/efi \
                     --bootloader-id=GRUB
    else                                         # ← BIOS 互換モード
        grub-install --target=i386-pc "$DISK"
    fi

    grub-mkconfig -o /boot/grub/grub.cfg

else  # systemd‑boot

    # ESP を /boot にマウントしている前提
    bootctl install

    # loader.conf
    cp ./bootloader/loader.conf /boot/loader/loader.conf

    # エントリー・ファイル
    cp ./bootloader/arch.conf.template /boot/loader/entries/arch.conf
    sed "s|@PARTUUID@|$PARTUUID|g" ./bootloader/arch.conf.template \
    > /boot/loader/entries/arch.conf

fi

tmpdir=$(mktemp -d)
chmod 777 "$tmpdir"
case $AUR_HELPER in
    yay)
      sudo -u "$USERNAME" git clone https://aur.archlinux.org/yay-bin.git "$tmpdir/yay-bin"
      (cd "$tmpdir/yay-bin" && sudo -u "$USERNAME" makepkg -si --noconfirm)
      ;;
    paru)
      pacman -S --needed --noconfirm rustup
      sudo -u "$USERNAME" rustup default stable
      sudo -u "$USERNAME" git clone https://aur.archlinux.org/paru.git "$tmpdir/paru"
      (cd "$tmpdir/paru" && sudo -u "$USERNAME" makepkg -si --noconfirm)
      ;;
  esac
  rm -rf "$tmpdir"
  echo $AUR_HELPER
