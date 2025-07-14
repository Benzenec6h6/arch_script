#!/usr/bin/env bash
set -euo pipefail

##### 0. root で実行確認 ################################################
[[ $EUID -eq 0 ]] || { echo "Run as root"; exit 1; }
USER_NAME=${SUDO_USER:-$(logname)}
echo "[+] target user = $USER_NAME"

##### 1. AUR ヘルパー選択 & インストール ################################
choose_aur() {
  local aurs=(yay paru)
  echo "== Choose AUR helper =="
  select aur in "${aurs[@]}"; do [[ -n $aur ]] && break; done
  echo "→ AUR helper: $aur"

  pacman -S --needed --noconfirm base-devel git

  tmpdir=$(mktemp -d)
  chmod 777 "$tmpdir"
  case $aur in
    yay)
      sudo -u "$USER_NAME" git clone https://aur.archlinux.org/yay-bin.git "$tmpdir/yay-bin"
      (cd "$tmpdir/yay-bin" && sudo -u "$USER_NAME" makepkg -si --noconfirm)
      ;;
    paru)
      pacman -S --needed --noconfirm rustup
      sudo -u "$USER_NAME" rustup default stable
      sudo -u "$USER_NAME" git clone https://aur.archlinux.org/paru.git "$tmpdir/paru"
      (cd "$tmpdir/paru" && sudo -u "$USER_NAME" makepkg -si --noconfirm)
      ;;
  esac
  rm -rf "$tmpdir"
  echo "$aur"          # 戻り値として書き出し
}

aur=$(choose_aur)

##### 2. multilib を有効化 ##############################################
if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
  sed -i '/^\s*#\s*\[multilib\]/{s/^#\s*//;n;s/^#\s*//;}' /etc/pacman.conf
fi
pacman -Sy

##### 3. pacman パッケージ ##############################################
# GPU ドライバ自動判定
gpu_pkgs=(mesa mesa-utils)
lspci | grep -qi nvidia  && gpu_pkgs+=(nvidia nvidia-utils)
lspci | grep -qi " Intel " && gpu_pkgs+=(intel-media-driver)

microcode_pkg=$(grep -qi AMD /proc/cpuinfo && echo amd-ucode || echo intel-ucode)

pkgs=(
  # Xorg / Wayland
  xorg-server xorg-xinit xorg-apps
  wayland wayland-protocols xorg-xwayland libxkbcommon
  wlr-randr xdg-desktop-portal xdg-desktop-portal-wlr

  "${gpu_pkgs[@]}" "$microcode_pkg"

  # Audio / Bluetooth / Power
  pipewire pipewire-alsa pipewire-pulse wireplumber
  bluez bluez-utils tlp tlp-rdw

  # Utils / Shell
  xdg-utils xdg-user-dirs htop nvtop btop fzf ripgrep
  tmux starship alacritty foot wezterm zsh dash

  # Display manager alt
  greetd greetd-gtkgreet seatd

  # Fonts & IM
  ttf-jetbrains-mono ttf-fira-code ttf-hack ttf-cascadia-code
  noto-fonts-cjk noto-fonts-emoji adobe-source-han-sans-otc-fonts
  fcitx5-im

  # Windows
  wine winetricks wine-mono

  # Virtualization
  qemu-full qemu-img libvirt virt-install virt-manager virt-viewer \
  edk2-ovmf dnsmasq swtpm libosinfo tuned ntfs-3g

  # Containers
  docker

  # Apps
  firefox chromium code discord qbittorrent unzip unrar p7zip
)

pacman -S --needed --noconfirm "${pkgs[@]}"

##### 4. AUR パッケージ（テスト時はコメントアウト） ####################
#aur_pkgs=(ttf-udev-gothic fcitx5-mozc-ut)
#sudo -u "$USER_NAME" "$aur" -S --needed --noconfirm "${aur_pkgs[@]}"

##### 5. サービス有効化 ##################################################
loginctl enable-linger "$USER_NAME"

# user units
#sudo -u "$USER_NAME"
systemctl --user enable --now pipewire pipewire-pulse wireplumber seatd

# system units
systemctl enable --now bluetooth cups tlp tlp-sleep greetd.service
#systemctl enable --now greetd.service

# libvirt
systemctl enable --now libvirtd
sed -Ei 's|^#(unix_sock_group = )"libvirt"|\1"libvirt"|' /etc/libvirt/libvirtd.conf
sed -Ei 's|^#(unix_sock_rw_perms = )"0770"|\1"0770"|' /etc/libvirt/libvirtd.conf
usermod -aG libvirt "$USER_NAME"

# docker
systemctl enable --now docker containerd
usermod -aG docker "$USER_NAME"

fc-cache -fv

##### 6. winetricks （非 root） #########################################
sudo -u "$USER_NAME" winetricks -q cjkfonts || true

##### 7. Nix multi-user ##################################################
curl -L https://nixos.org/nix/install | bash -s -- --daemon
systemctl enable --now nix-daemon.service

##### 8. fcitx5 環境変数 #################################################
sudo -u "$USER_NAME" mkdir -p "/home/$USER_NAME/.config/environment.d"
cat > "/home/$USER_NAME/.config/environment.d/fcitx.conf" <<EOF
INPUT_METHOD=fcitx
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
EOF
chown "$USER_NAME":"$USER_NAME" "/home/$USER_NAME/.config/environment.d/fcitx.conf"

echo "===== setup complete! Re‑login and verify 'groups' output (docker/libvirt) ====="
