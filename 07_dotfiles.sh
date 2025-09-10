#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/env/env.sh"
DOTFILES_JSON="$$SCRIPT_DIR/lib/dotfiles.json"

source "$ENV_FILE"
command -v jq >/dev/null || { echo "jq is required. pacman -S jq"; exit 1; }

if [[ -z "${DOTFILES:-}" ]]; then
    echo "DOTFILES not set. Run 00_select.sh first."
    exit 1
fi

echo "== Installing dotfiles: $DOTFILES for $WM =="
HOME="/mnt/home/$USERNAME"

# method 配列を読み込む
mapfile -t methods < <(
    jq -r --arg wm "$WM" --arg name "$DOTFILES" \
        '.[$wm][] | select(.name==$name) | .method[]' "$DOTFILES_JSON"
)

for cmd in "${methods[@]}"; do
    echo "[RUN] $cmd"
    bash -c "HOME=\"$HOME\" $cmd"
done

chown -R "$USERNAME:$USERNAME" "$HOME"

echo "✅ Dotfiles ($DOTFILES) installed"

# root パスワードロック
passwd -l root

# swap/off / umount / poweroff
swapoff "${DISK_SWAP}" || true
umount -R /mnt || true
poweroff
