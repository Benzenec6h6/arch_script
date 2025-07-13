#!/usr/bin/env bash
set -euo pipefail

### 0. root で実行確認
[[ $EUID -eq 0 ]] || { echo "Run as root"; exit 1; }

### 1. AUR ヘルパー選択 & インストール ----------------------------------
choose_aur() {
  local aurs=(yay paru)
  echo "== Choose AUR helper =="
  select aur in "${aurs[@]}"; do [[ -n $aur ]] && break; done
  echo "→ AUR helper: $aur"

  case $aur in
    yay)
      pacman -S --noconfirm base-devel git
      git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin
      (cd /tmp/yay-bin && makepkg -si --noconfirm)
      rm -rf /tmp/yay-bin
      ;;
    paru)
      pacman -S --noconfirm base-devel git rustup
      rustup default stable
      git clone https://aur.archlinux.org/paru.git /tmp/paru
      (cd /tmp/paru && makepkg -si --noconfirm)
      rm -rf /tmp/paru
      ;;
  esac
}

choose_aur

### 2. multilib を有効化 -----------------------------------------------
sed -i '/^\s*#\s*\[multilib\]/{s/^#\s*//;n;s/^#\s*//;}' /etc/pacman.conf
pacman -Syy

### 3. pacman パッケージ -----------------------------------------------
pkgs=(
  # Xorg / Wayland 基本
  xorg-server xorg-xinit xorg-apps
  wayland wayland-protocols xorg-xwayland libxkbcommon

  #Wayland 必須ライブラリ
  wlr-randr xdg-desktop-portal xdg-desktop-portal-wlr

  # GPU/Mesa
  mesa mesa-utils nvidia intel-media-driver

  # サウンド/PipeWire
  pipewire pipewire-alsa pipewire-pulse wireplumber

  # Bluetooth
  bluez bluez-utils

  # Power Management
  tlp tlp-rdw

  # 開発ツール
  git-lfs base-devel

  # XDG/共通ユーティリティ
  xdg-utils xdg-user-dirs

  #Microcode
  intel-ucode

  # Display manager 代替
  greetd gtkgreet seatd

  # Terminal / Shell
  tmux starship alacritty foot st wezterm
  zsh dash

  #アクセサリ
  htop nvtop btop fzf ripgrep

  # フォント
  ttf-jetbrains-mono ttf-fira-code ttf-hack ttf-cascadia-code
  noto-fonts-cjk noto-fonts-emoji otf-mplus1p adobe-source-han-sans-otc-fonts

  # 日本語入力
  fcitx5-im fcitx5-mozc-ut fcitx5-gtk fcitx5-qt

  # Windows 互換
  wine winetricks wine-mono

  # 仮想化
  qemu-full qemu-img libvirt virt-install virt-manager virt-viewer \
  edk2-ovmf dnsmasq swtpm libosinfo tuned ntfs-3g

  # コンテナ
  docker

  # アプリ
  firefox chromium code discord qbittorrent unzip unrar p7zip
)

pacman -S --noconfirm "${pkgs[@]}"

### 4. AUR パッケージ ---------------------------------------------------
# 例: udev-gothic
$aur -S --noconfirm udev-gothic

### 5. サービス有効化 ---------------------------------------------------
systemctl enable seatd.service

# libvirt
systemctl enable --now libvirtd.service
sed -Ei 's|^#(unix_sock_group = )"libvirt"|\1"libvirt"|' /etc/libvirt/libvirtd.conf
sed -Ei 's|^#(unix_sock_rw_perms = )"0770"|\1"0770"|'       /etc/libvirt/libvirtd.conf
usermod -aG libvirt "$SUDO_USER"

#PipeWire
systemctl --user enable --now pipewire pipewire-pulse wireplumber 

#Bluetooth
systemctl enable --now bluetooth

#TLP
systemctl enable --now tlp tlp-sleep

#Fonts キャッシュ更新
fc-cache -fv

# docker
systemctl enable --now docker.service containerd.service
usermod -aG docker "$SUDO_USER"

### 6. Winetricks 日本語フォント
winetricks -q cjkfonts || true   # 失敗しても続行

### 7. curl インストーラ例 (jetify devbox)
sudo -u "$SUDO_USER" bash -c 'curl -fsSL https://get.jetify.com/devbox | bash'

### 8. fcitx5 環境変数
cat >> ~/.config/environment.d/fcitx.conf <<EOF
INPUT_METHOD=fcitx
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
EOF

echo -e "\n===== setup complete! ====="
echo "ログアウトし、再ログインして groups を確認してください。"
