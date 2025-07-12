#!/usr/bin/env bash
set -euo pipefail

# ── ① ディスク一覧を取得 ──────────────────────────
mapfile -t disks < <(lsblk -ndo NAME,SIZE,TYPE | awk '$3=="disk" && $1!~/^loop/ {print $1, $2}')

if ((${#disks[@]}==0)); then
  echo "No block device found"; exit 1
fi

echo "== Select target disk =="
for i in "${!disks[@]}"; do
  printf "%2d) /dev/%s (%s)\n" $((i+1))  \
    "$(awk '{print $1}' <<<"${disks[$i]}")" \
    "$(awk '{print $2}' <<<"${disks[$i]}")"
done

read -rp 'Index: ' idx
((idx>=1 && idx<=${#disks[@]})) || { echo "Invalid index"; exit 1; }
disk="/dev/$(awk '{print $1}' <<<"${disks[idx-1]}")"
echo "→ selected $disk"

# ── ② ネットワークマネージャ選択 ────────────────
nets=(dhcpcd NetworkManager)
echo "== Network tool =="
select net in "${nets[@]}"; do [[ -n $net ]] && break; done
echo "→ $net"

# ── ③ ブートローダ選択 ──────────────────────────
loaders=(systemd-boot grub)
echo "== Boot loader =="
select loader in "${loaders[@]}"; do [[ -n $loader ]] && break; done
echo "→ $loader"

# ── ④ パーティション作成 ────────────────────────
echo "[+] Wipe & GPT"
sgdisk --zap-all "$disk"

if [[ $loader == systemd-boot ]]; then
  sgdisk -n1:0:+512M -t1:ef00 -c1:"EFI" "$disk"
else
  sgdisk -n1:0:+1M   -t1:ef02 -c1:"BIOS" "$disk"
fi
sgdisk -n2:0:+4G   -t2:8200 -c2:"swap" "$disk"
sgdisk -n3:0:0     -t3:8300 -c3:"root" "$disk"

mkswap   "${disk}2" && swapon "${disk}2"
mkfs.ext4 -L root "${disk}3"

if [[ -d /sys/firmware/efi ]]; then
  mkfs.fat -F32 "${disk}1"
  if [[ $loader == systemd-boot ]]; then
    mkdir -p /mnt/boot
    mount "${disk}1" /mnt/boot
  else
    mkdir -p /mnt/boot/efi
    mount "${disk}1" /mnt/boot/efi
  fi
fi

# ── ⑤ マウント ────────────────────────────────
mount "${disk}3" /mnt

# ── ⑥ ベースシステム ───────────────────────────
pacstrap /mnt base linux linux-firmware
genfstab -U /mnt >> /mnt/etc/fstab

# ルートパーティションの PARTUUID を取得
PARTUUID=$(blkid -s PARTUUID -o value "${disk}3")

export disk net loader PARTUUID
# ── ⑦ chroot 設定 ─────────────────────────────
arch-chroot /mnt /bin/bash <<EOF
set -euo pipefail

ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "KEYMAP=jp106"     > /etc/vconsole.conf
locale-gen

pacman -S --noconfirm sudo git nano fastfetch "$net"

if [[ $net == dhcpcd ]]; then
  systemctl enable dhcpcd
else
  systemctl enable NetworkManager
fi

useradd -m -G wheel -s /bin/bash teto
echo "root:toor" | chpasswd
echo "teto:teto" | chpasswd

# ── ブートローダーの分岐 ─────────────────────────────
if [[ $loader == grub ]]; then
    # ── GRUB ────────────────────────────────
    pacman -S --noconfirm grub efibootmgr

    if [[ -d /sys/firmware/efi ]]; then          # ← UEFI で起動している
        grub-install --target=x86_64-efi \
                     --efi-directory=/boot/efi \
                     --bootloader-id=GRUB
    else                                         # ← BIOS 互換モード
        grub-install --target=i386-pc "$disk"
    fi

    grub-mkconfig -o /boot/grub/grub.cfg

else  # ── systemd‑boot ──────────────────────

    # ESP を /boot にマウントしている前提
    bootctl install

    # loader.conf
    cat > /boot/loader/loader.conf <<'LOADER'
default arch
timeout 3
editor 0
LOADER

    # エントリー・ファイル
    cat > /boot/loader/entries/arch.conf <<ENTRY
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=PARTUUID=$PARTUUID rw
ENTRY
fi

sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
EOF

# ── ⑧ 後片付け ────────────────────────────────
swapoff "${disk}2"
umount -R /mnt
#reboot
