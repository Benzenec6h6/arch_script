#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_ROOT/env/env.sh"
source "$ENV_FILE"

#仮想化判定
if systemd-detect-virt --quiet; then
  echo "[+] Virtual Machine detected"
  sed -i "s|^export is_vm=.*|export is_vm="true"|" "$ENV_FILE"
else
  echo "[+] Physical Machine"
  sed -i "s|^export is_vm=.*|export is_vm="false"|" "$ENV_FILE"
fi

# ディスク一覧を取得
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
sed -i "s|^export DISK=.*|export DISK=\"$disk\"|" "$ENV_FILE"
echo "→ selected $disk"

# 関数を定義
get_partition_name() {
    local disk="$1"
    local part_num="$2"
    if [[ "$disk" =~ nvme ]]; then
        echo "${disk}p${part_num}"
    else
        echo "${disk}${part_num}"
    fi
}

# env.shを読み込む
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_ROOT/env/env.sh"
source "$ENV_FILE"

# DISK選択後にパーティション変数も設定
export DISK_BOOT=$(get_partition_name "$DISK" 1)
export DISK_SWAP=$(get_partition_name "$DISK" 2)
export DISK_ROOT=$(get_partition_name "$DISK" 3)

# env.shに書き戻す
sed -i "s|^export DISK_BOOT=.*|export DISK_BOOT=\"$DISK_BOOT\"|" "$ENV_FILE"
sed -i "s|^export DISK_SWAP=.*|export DISK_SWAP=\"$DISK_SWAP\"|" "$ENV_FILE"
sed -i "s|^export DISK_ROOT=.*|export DISK_ROOT=\"$DISK_ROOT\"|" "$ENV_FILE"

echo "→ Partitions set: boot=$DISK_BOOT swap=$DISK_SWAP root=$DISK_ROOT"

# ネットワークマネージャ選択
nets=(dhcpcd NetworkManager)
echo "== Network tool =="
select net in "${nets[@]}"; do [[ -n $net ]] && break; done
sed -i "s|^export NET_TOOL=.*|export NET_TOOL=\"$net\"|" "$ENV_FILE"
echo "→ $net"

# ブートローダ選択
loaders=(systemd-boot grub)
echo "== Boot loader =="
select loader in "${loaders[@]}"; do [[ -n $loader ]] && break; done
sed -i "s|^export LOADER=.*|export LOADER=\"$loader\"|" "$ENV_FILE"
echo "→ $loader"

# aurhelper選択
aurs=(yay paru)
echo "== Choose AUR helper =="
select aur in "${aurs[@]}"; do [[ -n $aur ]] && break; done
sed -i "s|^export AUR_HELPER=.*|export AUR_HELPER=\"$aur\"|" "$ENV_FILE"
echo "→ AUR helper: $aur"

#add username
read -rp "== User name (new account): " username
[[ -n $username ]] || { echo "Username must not be empty"; exit 1; }
sed -i "s|^export USERNAME=.*|export USERNAME=\"$username\"|" "$ENV_FILE"
echo "→ user = $username"