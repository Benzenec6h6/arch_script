#!/usr/bin/env bash
set -euo pipefail
source ./env.sh

DOT_DIR="/home/$USERNAME/dotfiles/arch_dot"

# 1) クローン（ユーザー所有に）
sudo -u "$USERNAME" git clone https://github.com/Benzenec6h6/dotfiles.git

# 2) 必要ディレクトリ
sudo -u "$USERNAME" mkdir -p "/home/$USERNAME/.config/environment.d"
sudo -u "$USERNAME" mkdir -p "/home/$USERNAME/.xmonad"

# 3) dotfiles ルートへ移動
cd "$DOT_DIR"

# 4) stow でリンク作成
#    -t (--target) でユーザーの $HOME を明示
sudo -u "$USERNAME" stow -t "/home/$USERNAME" X11
sudo -u "$USERNAME" stow -t "/home/$USERNAME" fcitx5
sudo -u "$USERNAME" stow -t "/home/$USERNAME" xmonad
sudo -u "$USERNAME" stow -t "/home/$USERNAME" shell

sudo -u "$USERNAME" bash -c 'xmonad --recompile'

##### 8. Nix multi-user ##################################################
curl -L https://nixos.org/nix/install | bash -s -- --daemon
systemctl enable --now nix-daemon.service

sudo -u "$USERNAME" chsh -s /bin/zsh "$USERNAME"
sudo passwd -l root

swapoff "${DISK}2"
umount -R /mnt
reboot