#!/usr/bin/env bash
set -euo pipefail
source ./env.sh

DOT_DIR="/home/$USERNAME/dotfiles/arch_dot"
HOME_DIR="/home/$USERNAME"

# 1) dotfiles を正しい場所へクローン
sudo -u "$USERNAME" git clone https://github.com/Benzenec6h6/dotfiles.git "$HOME_DIR/dotfiles"

# 2) 必要ディレクトリの作成（ユーザー権限）
sudo -u "$USERNAME" mkdir -p "$HOME_DIR/.config/environment.d"
sudo -u "$USERNAME" mkdir -p "$HOME_DIR/.xmonad"

# 3) dotfiles 配下に移動
cd "$DOT_DIR"

# 4) stow で各設定をリンク
for dir in X11 fcitx5 xmonad shell; do
  sudo -u "$USERNAME" stow -t "$HOME_DIR" "$dir"
done

# 5) xmonad 再コンパイル（ユーザーで実行）
sudo -u "$USERNAME" bash -c 'xmonad --recompile'

# 6) シェル変更 & root ロック
chsh -s /bin/zsh "$USERNAME"
passwd -l root

# 7) 最終後処理（swap / umount / reboot）
swapoff "${DISK}2" || true
umount -R /mnt || true
#reboot
