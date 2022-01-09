#!/bin/bash
set -x -e

backup_root=${BACKUP_ROOT:-./backups}
k3s_storage=/var/lib/rancher/k3s/storage

nextcloud_pvc=$(sudo sh -c "ls $k3s_storage | grep _nextcloud_nextcloud-shared-storage-claim")
photoprism_originals_pvc=$(sudo sh -c "ls $k3s_storage | grep _photoprism_photoprism-originals-shared-storage-claim")
photoprism_pvc=$(sudo sh -c "ls $k3s_storage | grep _photoprism_photoprism-shared-storage-claim")

nextcloud_root_dir="$k3s_storage/$nextcloud_pvc"
photoprism_originals_dir="$k3s_storage/$photoprism_originals_pvc"
photoprism_dir="$k3s_storage/$photoprism_pvc"

today=$(date -u +%Y-%m-%d)

function tar_with_progress {
  # frequency=$1
  # filename=$2
  # remaining_args="${@:3}"
  
  time sudo tar --create --verbose --file=$2 "${@:3}" | awk -v n=$1 'NR%n==1'
  sudo chown $USER $2
}

[[ -d $backup_root ]] || {
  echo "Error: Directory to place backups does not exist. Create it first or set BACKUP_ROOT environment variable"
  exit 1
}

tar_with_progress 10 $backup_root/${today}_k3s.tar.gz --exclude='/var/lib/rancher/k3s/agent/containerd' /var/lib/rancher/k3s/agent /var/lib/rancher/k3s/server

# Create a postgres dump
sudo kubectl exec deployment/nextcloud-db --namespace nextcloud -- pg_dumpall --database=nextcloud --username=nextcloud --clean | xz > $backup_root/${today}_nextcloud-postgres.sql.xz

tar_with_progress 2000 $backup_root/${today}_nextcloud-postgres-data-files.tar.gz $nextcloud_root_dir/postgres-data
tar_with_progress 2000 $backup_root/${today}_nextcloud-server-code.tar.gz --exclude=$nextcloud_root_dir/server-data/data $nextcloud_root_dir/server-data
tar_with_progress 2000 $backup_root/${today}_nextcloud-server-data.tar.gz $nextcloud_root_dir/server-data/data

sudo rsync --acls --archive --one-file-system --progress "$nextcloud_root_dir" $backup_root/rsync-nextcloud-root/


tar_with_progress 2000 $backup_root/${today}_photoprism-data.tar.gz      $photoprism_dir/
tar_with_progress   50 $backup_root/${today}_photoprism-originals.tar.gz $photoprism_originals_dir/