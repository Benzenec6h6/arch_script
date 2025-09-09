#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(realpath "$SCRIPT_DIR/..")"
ENV_FILE="$PROJECT_ROOT/env.sh"
DOTFILES_JSON="$PROJECT_ROOT/dotfiles.json"

source "$ENV_FILE"
command -v jq >/dev/null || { echo "jq is required. pacman -S jq"; exit 1; }

if [[ -z "${DOTFILES:-}" ]]; then
    echo "DOTFILES not set. Run 00_select.sh first."
    exit 1
fi

echo "== Installing dotfiles: $DOTFILES for $WM =="
DOTFILES_DIR="/mnt/home/$USERNAME/$DOTFILES"
mkdir -p "$DOTFILES_DIR"

# method 配列を読み込む
mapfile -t methods < <(
    jq -r --arg wm "$WM" --arg name "$DOTFILES" \
        '.[$wm][] | select(.name==$name) | .method[]' "$DOTFILES_JSON"
)

for cmd in "${methods[@]}"; do
    echo "[RUN] $cmd"
    # subshell で実行することでカレントディレクトリを汚さない
    (
        # 必要に応じて指定ユーザーで実行
        if [[ $cmd == sudo* ]]; then
            eval "$cmd"
        else
            sudo -u "$USERNAME" bash -c "$cmd"
        fi
    )
done

echo "✅ Dotfiles ($DOTFILES) installed"

# root パスワードロック
passwd -l root

# swap/off / umount / poweroff
swapoff "${DISK_SWAP}" || true
umount -R /mnt || true
poweroff
