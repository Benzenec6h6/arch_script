#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(realpath "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_ROOT/env/env.sh"

source "$ENV_FILE"

if [[ -z "${DOTFILES:-}" || -z "${WM:-}" ]]; then
    echo "DOTFILES or WM not set. Run 00_select.sh first."
    exit 1
fi

echo "== Installing dotfiles: $DOTFILES for $WM =="

# --- 実行 ---
case "$DOTFILES" in
    mylinuxforwork)
        runuser -l "$USERNAME" -c "git clone --depth 1 https://github.com/mylinuxforwork/dotfiles ~/Projects/dotfiles"
        runuser -l "$USERNAME" -c "cd ~/Projects/dotfiles/setup && ./setup-arch.sh"
        runuser -l "$USERNAME" -c "cd ~/Projects/dotfiles && stow dotfiles"
        ;;
    JaKooLit)
        runuser -l "$USERNAME" -c "git clone --depth=1 https://github.com/JaKooLit/Arch-Hyprland.git ~/Arch-Hyprland"
        runuser -l "$USERNAME" -c "cd ~/Arch-Hyprland && chmod +x install.sh && ./install.sh"
        ;;
    end-4)
        runuser -l "$USERNAME" -c "git clone --depth=1 https://github.com/end-4/dots-hyprland.git ~/dots-hyprland"
        runuser -l "$USERNAME" -c "cd ~/dots-hyprland && chmod +x install.sh && ./install.sh"
        ;;
    HyDE-Project)
        runuser -l "$USERNAME" -c "git clone --depth=1 https://github.com/HyDE-Project/HyDE ~/HyDE"
        runuser -l "$USERNAME" -c "cd ~/HyDE/Scripts && ./install.sh"
        ;;
    Matt-FTW)
        runuser -l "$USERNAME" -c "git clone https://github.com/Matt-FTW/dotfiles.git ~/dotfiles"
        runuser -l "$USERNAME" -c "cd ~/dotfiles && cp -r .config/* ~/.config/ || true"
        runuser -l "$USERNAME" -c "cd ~/dotfiles && cp -r .local/bin/* ~/.local/bin/ || true"
        ;;
    Axarva)
        runuser -l "$USERNAME" -c "git clone https://github.com/Axarva/dotfiles-2.0.git ~/dotfiles-2.0"
        runuser -l "$USERNAME" -c "cd ~/dotfiles-2.0 && chmod +x install-on-arch.sh && ./install-on-arch.sh"
        ln -sf /usr/lib/libasan.so.8 /usr/lib/libasan.so.6 || true
        ;;
    *)
        echo "Unknown DOTFILES: $DOTFILES"
        exit 1
        ;;
esac

# root パスワードロック
passwd -l root

# 所有権調整（保険）
chown -R "$USERNAME:$USERNAME" "/home/$USERNAME"

echo "✅ Dotfiles ($DOTFILES) installed"

# swap/off / umount / poweroff
swapoff "${DISK_SWAP}" || true
umount -R /mnt || true
poweroff
