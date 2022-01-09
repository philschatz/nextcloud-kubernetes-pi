echo '--------------- 8< Ignore the text above >8 ---------------'
[[ -d ~/test_mount ]] && sudo umount ~/test_mount

candidates=$(lsblk -rno name,mountpoint,fstype | awk 'NF==2' | grep -v '[SWAP]' | awk '{print $1}')

for candidate in $candidates; do    
    candidate_details=$(lsblk -rno name,size,mountpoint,fstype | grep "^$candidate " | awk '{print $2 $3}')
    # sda1 232.9G  ext4

    [[ -d ~/test_mount ]] || mkdir ~/test_mount
    sudo mount /dev/$candidate ~/test_mount
    if [[ $? == 0 ]]; then
        echo "$(df --human-readable --output=source,size,used,avail,pcent,fstype ~/test_mount/ | sed 1d)"
        # Size  Used Avail Use%
        # 229G   74G  155G  33%
        sudo umount ~/test_mount
    fi
    rm -r ~/test_mount
done
