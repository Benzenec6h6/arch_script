#!/usr/bin/env bash
set -euo pipefail
source ./env.sh

#仮想化判定
if systemd-detect-virt --quiet; then
  echo "[+] Virtual Machine detected"
  sed -i "s|^export is_vm=.*|export is_vm="true"|" ./env.sh
else
  echo "[+] Physical Machine"
  sed -i "s|^export is_vm=.*|export is_vm="false"|" ./env.sh
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
sed -i "s|^export DISK=.*|export DISK=\"$disk\"|" ./env.sh
echo "→ selected $disk"

# ネットワークマネージャ選択
nets=(dhcpcd NetworkManager)
echo "== Network tool =="
select net in "${nets[@]}"; do [[ -n $net ]] && break; done
sed -i "s|^export NET_TOOL=.*|export NET_TOOL=\"$net\"|" ./env.sh
echo "→ $net"

# ブートローダ選択
loaders=(systemd-boot grub)
echo "== Boot loader =="
select loader in "${loaders[@]}"; do [[ -n $loader ]] && break; done
sed -i "s|^export LOADER=.*|export LOADER=\"$loader\"|" ./env.sh
echo "→ $loader"

# aurhelper選択
aurs=(yay paru)
echo "== Choose AUR helper =="
select aur in "${aurs[@]}"; do [[ -n $aur ]] && break; done
sed -i "s|^export AUR_HELPER=.*|export AUR_HELPER=\"$aur\"|" ./env.sh
echo "→ AUR helper: $aur"

#add username
read -rp "== User name (new account): " username
[[ -n $username ]] || { echo "Username must not be empty"; exit 1; }
sed -i "s|^export USERNAME=.*|export USERNAME=\"$username\"|" ./env.sh
echo "→ user = $username"