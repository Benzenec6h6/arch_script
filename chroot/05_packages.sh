#!/usr/bin/env bash
set -euo pipefail
source ./env.sh

# multilib を有効化
if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
  sed -i '/^\s*#\s*\[multilib\]/{s/^#\s*//;n;s/^#\s*//;}' /etc/pacman.conf
fi
pacman -Sy

gpu_pkgs=(mesa mesa-utils)
lspci | grep -qi nvidia  && gpu_pkgs+=(nvidia nvidia-utils)
lspci | grep -qi " Intel " && gpu_pkgs+=(intel-media-driver)

microcode_pkg=$(grep -qi AMD /proc/cpuinfo && echo amd-ucode || echo intel-ucode)
#xmonad_pkgs=$(xmonad xmonad-contrib xmobar ghc picom trayer lxappearance dmenu rofi feh sxhkd mpv)

if $is_vm; then
  virtual_pkgs=(xf86-video-qxl xf86-video-vesa xf86-video-fbdev)
  power_pkgs=()
  service_pkgs=()
else
  virtual_pkgs=()
  power_pkgs=(tlp tlp-rdw)
  service_pkgs=(bluez bluez-utils cups)
fi

pkgs=(
  # Xorg / Wayland
  xorg-server xorg-xinit xorg-apps xorg-xmessage
  wayland wayland-protocols xorg-xwayland libxkbcommon
  wlr-randr xdg-desktop-portal xdg-desktop-portal-wlr

  # hyprland / launcher
  hyprland 

  "${gpu_pkgs[@]}" "${virtual_pkgs[@]}" "$microcode_pkg"
  pipewire pipewire-alsa pipewire-pulse wireplumber

  "${power_pkgs[@]}" "${service_pkgs[@]}"

  # Utilities
  xdg-utils xdg-user-dirs htop nvtop btop fzf ripgrep
  tmux starship alacritty foot wezterm zsh dash

  # Fonts
  ttf-jetbrains-mono ttf-fira-code ttf-hack ttf-cascadia-code
  noto-fonts-cjk noto-fonts-emoji adobe-source-han-sans-otc-fonts
  fcitx5-im

  # Wine
  wine winetricks wine-mono

  # Virtualization
  qemu-full qemu-img libvirt virt-install virt-viewer \
  edk2-ovmf dnsmasq swtpm libosinfo tuned ntfs-3g

  # Containers
  docker

  # dotfiles
  stow

  # Apps
  firefox chromium code discord qbittorrent unzip unrar p7zip
)

pacman -S --needed --noconfirm "${pkgs[@]}"

#aur_pkgs=(ttf-udev-gothic xwinwrap fcitx5-mozc-ut)
#sudo -u "$USERNAME" "$AUR_HELPER" -S --needed --noconfirm "${aur_pkgs[@]}"

sudo -u "$USERNAME" winetricks -q cjkfonts || true
