echo '--------------- 8< Ignore the text above >8 ---------------'

candidate='%%CANDIDATE_DISK%%'

[[ ! -d /var/lib/rancher/k3s/storage ]] && {

    sudo mkdir /var/lib/rancher/k3s/storage
    sudo mount $candidate /var/lib/rancher/k3s/storage

    [[ $? == 0 ]] && {
        mount_line=$(cat /etc/mtab | grep $candidate)

        sudo cp /etc/fstab /etc/fstab.backup
        echo "" | sudo tee -a /etc/fstab > /dev/null
        echo "# See https://www.howtogeek.com/444814/how-to-write-an-fstab-file-on-linux/" | sudo tee -a /etc/fstab > /dev/null
        echo "# This next line was added by the installer.sh file" | sudo tee -a /etc/fstab > /dev/null
        echo "# Another common option is this next line:" | sudo tee -a /etc/fstab > /dev/null
        echo "# /dev/sda1   /var/lib/rancher/k3s/storage	ext4	rw,relatime	0	0" | sudo tee -a /etc/fstab > /dev/null
        echo "$mount_line" | sudo tee -a /etc/fstab > /dev/null

        >&2 echo "Updated /etc/fstab with the new disk. Restarting..."
        sudo reboot
    }

}
