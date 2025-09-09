#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_ROOT/env/env.sh"
DOTFILES_JSON="$PROJECT_ROOT/lib/dotfiles.json"
source "$ENV_FILE"
command -v jq >/dev/null || { echo "jq is required. pacman -S jq"; exit 1; }

# ---- 関数 ----

# env.sh に書き込む関数
update_env() {
  local var="$1"
  local val="$2"
  sed -i "/^export ${var}=/d" "$ENV_FILE"
  if [[ -s "$ENV_FILE" && "$(tail -c 1 "$ENV_FILE")" != $'\n' ]]; then
    printf '\n' >> "$ENV_FILE"
  fi
  printf 'export %s="%s"\n' "$var" "$val" >> "$ENV_FILE"
}

# select / read を共通化
choose_option() {
  local prompt="$1"; shift
  local options=("$@")
  local opt
  printf '%s\n' "$prompt" >&2
  exec 3>&1
  {
    PS3="> "
    select opt in "${options[@]}"; do
      if [[ -n $opt ]]; then
        printf '%s\n' "$opt" >&3
        break
      fi
    done
  } 1>&2
  exec 3>&-
}

# パーティション名取得
get_partition_name() {
    local disk="$1"
    local part_num="$2"
    if [[ "$disk" =~ nvme ]]; then
        echo "${disk}p${part_num}"
    else
        echo "${disk}${part_num}"
    fi
}

# ---- 仮想化判定 ----
if systemd-detect-virt --quiet; then
    echo "[+] Virtual Machine detected"
    update_env "is_vm" "true"
else
    echo "[+] Physical Machine"
    update_env "is_vm" "false"
fi

# ---- ディスク選択 ----
mapfile -t disks < <(lsblk -ndo NAME,SIZE,TYPE | awk '$3=="disk" && $1!~/^loop/ {print $1, $2}')
(( ${#disks[@]} )) || { echo "No block device found"; exit 1; }

echo "== Select target disk =="
for i in "${!disks[@]}"; do
    printf "%2d) /dev/%s (%s)\n" $((i+1)) \
        "$(awk '{print $1}' <<<"${disks[$i]}")" \
        "$(awk '{print $2}' <<<"${disks[$i]}")"
done

read -rp "Index: " idx
(( idx >= 1 && idx <= ${#disks[@]} )) || { echo "Invalid index"; exit 1; }
DISK="/dev/$(awk '{print $1}' <<<"${disks[idx-1]}")"
update_env "DISK" "$DISK"
echo "→ Selected disk: $DISK"

# ---- パーティション設定 ----
DISK_BOOT=$(get_partition_name "$DISK" 1)
DISK_SWAP=$(get_partition_name "$DISK" 2)
DISK_ROOT=$(get_partition_name "$DISK" 3)
update_env "DISK_BOOT" "$DISK_BOOT"
update_env "DISK_SWAP" "$DISK_SWAP"
update_env "DISK_ROOT" "$DISK_ROOT"
echo "→ Partitions: boot=$DISK_BOOT swap=$DISK_SWAP root=$DISK_ROOT"

# ---- ネットワークマネージャ選択 ----
NET_TOOL=$(choose_option "== Select network tool ==" dhcpcd NetworkManager)
update_env "NET_TOOL" "$NET_TOOL"
echo "→ $NET_TOOL"

# ---- ブートローダ選択 ----
LOADER=$(choose_option "== Select boot loader ==" systemd-boot grub)
update_env "LOADER" "$LOADER"
echo "→ $LOADER"

# ---- AUR helper選択 ----
AUR_HELPER=$(choose_option "== Choose AUR helper ==" yay paru)
update_env "AUR_HELPER" "$AUR_HELPER"
echo "→ $AUR_HELPER"

# ---- WM 選択 ----
WM=$(choose_option "== Choose Window Manager ==" hyprland xmonad)
update_env "WM" "$WM"
echo "→ $WM"

# ---- dotfiles 選択 ----
mapfile -t names < <(jq -r --arg wm "$WM" '.[$wm][] | .name' "$DOTFILES_JSON")

echo "== Choose dotfiles for $WM =="
select name in "${names[@]}"; do [[ -n $name ]] && break; done
update_env "DOTFILES" "$name"
echo "→ $name"

# ---- ユーザー名入力 ----
read -rp "== User name (new account): " username
[[ -n $username ]] || { echo "Username must not be empty"; exit 1; }
update_env "USERNAME" "$username"
echo "→ User: $username"

# ---- password ----
read -rp "== Password (new password): " password
[[ -n $password ]] || { echo "Password must not be empty"; exit 1; }
update_env "PASSWORD" "$password"