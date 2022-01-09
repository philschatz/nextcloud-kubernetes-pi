#/usr/bin/env bash
set -e

echo "------------------------------"
echo "Details from inside the server"
echo "------------------------------"
echo "HOST_ARCHITECTURE=$(uname -a)"
echo "USED_SPACE=$(df -h --output=used / | sed 1d)"
echo "USED_SPACE_PERCENT=$(df -h --output=pcent / | sed 1d)"

# Check if /var/lib/rancher/k3s/storage exists and if it is mounted
# [[ -d /var/lib/rancher/k3s/storage ]] && echo 'K3S_STORAGE_ROOT_EXISTS
lsblk -rno name,mountpoint | grep '/var/lib/rancher/k3s/storage$' > /dev/null 2>&1 && echo 'K3S_STORAGE_ROOT_IS_MOUNTED'

systemctl --type=service --state=active