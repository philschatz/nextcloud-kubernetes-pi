#!/bin/bash

set -e

kube_hostname_only='kube'
kube_username='pi'

SD_BOOTFS=${SD_BOOTFS:-/media/$USER/boot}
DOTENV_FILE=./install.env
BACKUP_ROOT=${BACKUP_ROOT:-./backups}
# SERVER_IP is computed later

# https://stackoverflow.com/questions/5947742/how-to-change-the-output-color-of-echo-in-linux
if [[ $(tput colors) -ge 8 ]]; then
    # LCOV_EXCL_START
    declare -x c_red=$(tput setaf 1)
    declare -x c_green=$(tput setaf 2)
    declare -x c_yellow=$(tput setaf 3)
    declare -x c_blue=$(tput setaf 4)
    declare -x c_purple=$(tput setaf 5)
    declare -x c_cyan=$(tput setaf 6)
    declare -x c_none=$(tput sgr0) # Keep this last so TRACE=true does not cause everything to be cyan
    # LCOV_EXCL_STOP
fi

# https://stackoverflow.com/a/25515370
say() { echo -e "${c_green}$*${c_none}"; }
warn() { echo -e "${c_yellow}$*${c_none}"; }
yell() { >&2 echo -e "$0: $c_red$*$c_none"; }
die() { yell "$1"; exit 112; }

prompt() {
    # message $1
    # default $2
    if [[ $2 ]]; then
        read -p "$1 [$2]: " response
    else
        read -p "$1: " response
    fi
    [[ $response ]] && echo $response || echo $2
}
confirm() {
    # message $1
    read -p "$1 <y/N> " response
    echo $response
}

step_configure_sd_card() {
    # Detecting if USB or SD card is mounted
    if [[ -f $SD_BOOTFS/cmdline.txt ]]; then

        [[ -f $DOTENV_FILE || $WIFI_NAME ]] || {
            echo "A ./install.env file was not found. Lets create one."
            echo "You will be asked for the WiFi Name and Passphrase which will be included on the SD card of the pi so it can connect to the network and you can log in to it:"
            WIFI_NAME=$(prompt "WiFi Name")
            WIFI_PASSPHRASE=$(prompt "WiFi Passphrase")
            WIFI_COUNTRY_CODE=$(prompt "2-letter country code (WiFi needs it for radio frequencies)" "us")
            AUTHORIZED_SSH_KEYS=$(prompt "Any authorized SSH keys you would like to include")

            # Write the fields out
            [[ $WIFI_NAME ]]           && echo "WIFI_NAME=$WIFI_NAME"                     >> $DOTENV_FILE
            [[ $WIFI_PASSPHRASE ]]     && echo "WIFI_PASSPHRASE=$WIFI_PASSPHRASE"         >> $DOTENV_FILE
            [[ $WIFI_COUNTRY_CODE ]]   && echo "WIFI_COUNTRY_CODE=$WIFI_COUNTRY_CODE"     >> $DOTENV_FILE
            [[ $AUTHORIZED_SSH_KEYS ]] && echo "AUTHORIZED_SSH_KEYS=$AUTHORIZED_SSH_KEYS" >> $DOTENV_FILE
        }

        # Load template variables from file (if it exists)
        [[ -f $DOTENV_FILE ]] && export $(echo $(cat $DOTENV_FILE | sed 's/#.*//g' | sed 's/\r//g' | xargs))

        # Validate WiFi
        [[ ! $WIFI_NAME || $WIFI_COUNTRY_CODE && $WIFI_PASSPHRASE ]] || {
            echo "Error: Both WIFI_PASSPHRASE and WIFI_COUNTRY_CODE are required since you specified a WIFI_NAME. Update $DOTENV_FILE"
            exit 111
        }

        # Pull our public key if nothing else is specified
        AUTHORIZED_SSH_KEYS=${AUTHORIZED_SSH_KEYS:-$(< ~/.ssh/id_rsa.pub)}

        # Make backup
        [[ -f $SD_BOOTFS/firstrun.sh ]] && mv $SD_BOOTFS/firstrun.sh $SD_BOOTFS/firstrun.sh.backup

        # Generate file from template
        sed \
            -e "s;%%AUTHORIZED_SSH_KEYS%%;$AUTHORIZED_SSH_KEYS;g" \
            -e "s;%%WIFI_NAME%%;$WIFI_NAME;g" \
            -e "s;%%WIFI_PASSPHRASE%%;$WIFI_PASSPHRASE;g" \
            -e "s;%%WIFI_COUNTRY_CODE%%;$WIFI_COUNTRY_CODE;g" \
            -e "s;%%NEW_HOSTNAME%%;$kube_hostname_only;g" \
            ./templates/firstrun.template.sh > $SD_BOOTFS/firstrun.sh
        
        # Generate cmdline.txt file
        [[ -f $SD_BOOTFS/cmdline.txt && ! -f $SD_BOOTFS/cmdline.txt.backup ]] && mv $SD_BOOTFS/cmdline.txt $SD_BOOTFS/cmdline.txt.backup
        old_text=$(cat $SD_BOOTFS/cmdline.txt.backup)
        new_text=$(cat ./templates/cmdline.template.txt)
        echo -n "$old_text $new_text" > $SD_BOOTFS/cmdline.txt

        # Add arm_64bit=1 if this is a pi4 and gpu_mem=16 for all pis
        [[ ! -f $SD_BOOTFS/config.txt.backup ]] && {
            cp $SD_BOOTFS/config.txt $SD_BOOTFS/config.txt.backup
            echo "" >> $SD_BOOTFS/config.txt
            echo "$(cat ./templates/config.template.txt)" >> $SD_BOOTFS/config.txt
        }

        echo "---------------"
        echo "Done writing to SD card"
        echo "Now, put the SD card in the raspberry pi and wait about 5 minutes for it to boot up"
        echo "You can run 'ping $kube_hostname_only.local' and 'ssh $kube_username@$kube_hostname_only.local' to see if it starts up (or without the '.local')"
        echo "If it does not start up you may need to plug in a TV/keyboard to see what is happening or double check the contents of $DOTENV_FILE"
        echo "---------------"
    else
        echo "Error: Did not find an SD card or USB drive with Raspberry Pi OS at $SD_BOOTFS. You can override this directory by setting the SD_BOOTFS environment variable"
        exit 111
    fi
}


step_install_os_dependencies() {
    cat ./templates/install-os-deps.sh | ssh $kube_username@$kube_hostname
    echo "Finished installing os dependencies"
}

step_install_disk_savers() {
    cat ./templates/install-disk-savers.sh | ssh $kube_username@$kube_hostname
    echo "Finished installing os dependencies"
}

step_install_k3s() {
    # Install local helpers
    command -v arkade > /dev/null || {
        curl -sSL https://dl.get-arkade.dev | sudo sh
    }
    command -v kubectl > /dev/null || {
        arkade get kubectl
    }
    command -v k3sup > /dev/null || {
        arkade get k3sup
    }
    [[ -f ./kubeconfig ]] && {
        echo "Found existing kubeconfig file. Renaming it."
        echo "You can also find this by sshing into the kube server and copying /etc/rancher/k3s/k3s.yaml. Also, change the server: IP address in that file"
        cp ./kubeconfig ./kubeconfig.backup
    }
    k3sup install --ip $SERVER_IP --user $kube_username || {
        echo "There was a problem installing k3s."
        echo "It may be because the IP address '$SERVER_IP' is not correct"
        echo "Try running 'ping $kube_hostname_only' or 'ping $kube_hostname_only.local' to see what it responds to"
        echo "Then, re-run this command with the SERVER_IP environment variable set"
        echo "Example: SERVER_IP=123.456.789.012 ./install.sh"
        exit 111
    }
}

step_add_this_node() {
    echo "Note: Adding other nodes is not supported yet. Just tweak this next line and ensure you can ssh to the other machine without a password"
    sleep 10
    k3sup join --server-ip $SERVER_IP --server-user $kube_username --user $USER
}


step_verify_k3s_is_up() {
    export KUBECONFIG=$(pwd)/kubeconfig
    kubectl get nodes
    kubectl get pods --all-namespaces
}

step_deploy_apps() {
    # Create TLS certificate
    # [[ -f ./my-tls.crt ]] || {
    #     openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    #         -out ./deployments/my-tls.crt \
    #         -keyout ./deployments/my-tls.key \
    #         -subj "/CN=$kube_hostname/O=Personal Cloud"
    # }
    ./start.sh

    echo "Deployment started. It may take a couple of minutes for the dashboard app to start. (waiting 10sec)"
    echo "Once they have started (check dashboard) then you can visit https://$kube_hostname with a browser."
    echo "When you do, you will be presented with a locally-signed certificate. Accept it."
    sleep 10
}

step_delete_apps() {
    ./reset.sh
}

step_start_proxy_tunnel() {
    set +x
    export KUBECONFIG=$(pwd)/kubeconfig

    login_token=$(kubectl -n kubernetes-dashboard get secret $(kubectl -n kubernetes-dashboard get sa/admin-user -o jsonpath="{.secrets[0].name}") -o go-template="{{.data.token | base64decode}}")
    echo "Login Token:"
    echo "$login_token"
    echo ""
    echo "Visit the following URL and paste the token from above"
    echo "http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/#/workloads?namespace=_all"
    echo ""
    echo "Note: Select 'All Namespaces' in the left dropdown to see everything that is running"
    echo ""
    echo "Note: Pressing Ctrl+C will close the connection to the dashboard"
    kubectl proxy
}

step_mount_storage_drive() {
    
    while :; do
        DANGER_TOKEN='!!!DANGER!!!'
        candidate_lines=$(cat ./templates/mount-candidates.sh | ssh $kube_username@$kube_hostname)
        candidate_lines=$(echo "$candidate_lines" | sed -n -E -e '/--------------- 8< Ignore the text above >8 ---------------/,$ p' | sed '1 d' | sort)
        candidate_lines=$(echo "$candidate_lines" | sed -e "s; vfat$;   $c_red$DANGER_TOKEN DO NOT USE THIS. REFORMAT THIS TO USE A NON-FAT FILESYSTEM. The 'ext' family works best$c_none;g")
        candidate_lines=$(echo "$candidate_lines" | sed -e "s; ntfs$;   $c_red$DANGER_TOKEN DO NOT USE THIS. REFORMAT THIS TO USE A NON-FAT FILESYSTEM. The 'ext' family works best$c_none;g")
        set +e
        IFS=$'\n' read -d '' -a candidates <<< "$candidate_lines"
        set -e
        if [[ ${#candidates[@]} == 0 ]]; then
            echo "Error: No free disks found. Insert a formatted USB drive and try this command again."
            echo "Choose the slot carefully because that slot will be used for storing all of your data."
            return
        else
            # Ask the user which disk they want to mount
            echo "Which disk would you like to use for storing all of your cloud data (do not remove it while the server is on!):"
            echo "Disk              Total  Used  Avail Percentage FSType"
            PS3="Choose a disk (1-${#candidates[@]}): "
            select candidate in "${candidates[@]}"; do
                case $candidate in
                    *)
                        candidate_device=$(echo $candidate | awk '{print $1}')
                        [[ $candidate =~ $DANGER_TOKEN ]] && {
                            candidate_device=''
                        }
                        break
                        ;;
                esac
            done

            [[ $candidate_device != '' ]] && {
                # Perform the mount, read the mount info, and write it to /etc/fstab (after making a backup)
                sed \
                    -e "s;%%CANDIDATE_DISK%%;$candidate_device;g" \
                    ./templates/mount-run.template.sh | ssh $kube_username@$kube_hostname > /dev/null
                break
            }
        fi
    done
}

step_perform_rsync_backup() {
    export KUBECONFIG=`pwd`/kubeconfig

    today=$(date -u +%Y-%m-%d)
    # Perform rsync, postgres database dump, and a full tarball snapshot
    [[ ! -d $BACKUP_ROOT ]] && mkdir $BACKUP_ROOT
    
    [[ ! -d $BACKUP_ROOT ]] && {
        echo 'Warning: It appears you are backing up for the first time. The first time takes a while.'
        sleep 2
    }
    time rsync \
        --archive \
        --compress \
        --progress \
        --partial \
        --rsync-path 'sudo rsync' \
        --bwlimit=100 \
        --ipv4 \
        --exclude='backups' \
        $kube_username@$kube_hostname:/var/lib/rancher/k3s/storage \
        $BACKUP_ROOT/rsync-storage
    
    echo "Running postgres database dump"
    [[ ! -d $BACKUP_ROOT/backup_$today ]] && mkdir $BACKUP_ROOT/backup_$today
    kubectl exec deployment/nextcloud-db --namespace nextcloud -- pg_dumpall --database=nextcloud --username=nextcloud --clean > $BACKUP_ROOT/backup_$today/nextcloud-postgres.sql
}

step_perform_tarball_backup() {
    today=$(date -u +%Y-%m-%d)
    # Perform rsync, postgres database dump, and a full tarball snapshot
    [[ ! -d $BACKUP_ROOT/backup_$today ]] && mkdir -p $BACKUP_ROOT/backup_$today

    echo 'sudo tar czf - /var/lib/rancher/k3s/server/ || [[ $? -eq 1 ]]' | ssh $kube_username@$kube_hostname > $BACKUP_ROOT/backup_$today/k3s_server.tar.gz
    echo 'sudo tar czf - /var/lib/rancher/k3s/storage/ || [[ $? -eq 1 ]]' | ssh $kube_username@$kube_hostname > $BACKUP_ROOT/backup_$today/k3s_storage.tar.gz
}

step_restore_postgres_from_backup() {
    export KUBECONFIG=$(pwd)/kubeconfig

    if [[ $1 ]]; then
        backup_file=$1
    else
        backup_dir=$(find ./backups -name 'backup_*' | sort -r | head -n 1)
        backup_file=$backup_dir/nextcloud-postgres.sql
        [[ ! $backup_file || ! -f $backup_file ]] && {
            echo "Error: Could not find a backup file at '$backup_file'"
            exit 1
        }
        echo "$c_yellowWARNING: Using the newest backup file '$backup_file'. To specify a different file, run this install script with the following arguments: 'restore-postgres' path/to/postgres-backup.sql. Waiting 5sec.$c_none"
        sleep 5
    fi

    # kubectl delete --wait=true -f ./deployments/nextcloud-server.yaml || echo "The service is already off."
    # kubectl delete --wait=true -f ./deployments/nextcloud-db.yaml || echo "The service is already off."
    kubectl apply -f ./deployments/nextcloud-db.yaml
    cat $backup_file | kubectl exec deployment/nextcloud-db --stdin=true --namespace nextcloud -- psql --set ON_ERROR_STOP=on --dbname=postgres --username=nextcloud --echo-all
    kubectl apply -f ./deployments/nextcloud-server.yaml
}

ander() {
    ret='yes'
    for var in "$@"; do
        if [[ $var == '' ]]; then
            ret=''
        fi
    done
    echo $ret
}
yes_no() {
    if [[ $2 ]]; then
        echo "$1 ${c_green}yes$c_none"
    else
        echo "$1 ${c_red}no$c_none"
    fi
}

run_yes_no() {
    set +e
    echo "$($@ > /dev/null 2>&1 && echo 'yes')"
    set -e
}

update_status() {
    echo "Checking installation/server status... You may be prompted for a password if you did not set up private keys"
    set +e

    is_mounted=''
    is_on_local=''
    is_on_noname=''
    is_on=''
    kube_hostname=''
    is_ssh_on=''
    is_https_on=''
    is_http_on=''
    is_ssh_valid=''
    has_kubeconfig=''
    is_kubeconfig_valid=''
    has_rsync_backup_ran=''

    echo -n "${c_yellow}Loading $c_blue[$c_none"
    is_mounted=$([[ -f $SD_BOOTFS ]] && echo 'yes')
    has_rsync_backup_ran=$([[ -d $BACKUP_ROOT/rsync-storage ]] && echo 'yes')
    is_on_local=$(ping -c 1 -W 2 $kube_hostname_only.local &> /dev/null && echo 'yes')
    echo -n "$c_green.$c_none"
    [[ ! $is_on_local ]] && is_on_noname=$(ping -c 1 -W 2 $kube_hostname_only &> /dev/null && echo 'yes')

    [[ $is_on_local || $is_on_noname ]] && is_on='yes'
    [[ $is_on_noname ]] && kube_hostname=$kube_hostname_only
    [[ $is_on_local ]] && kube_hostname="$kube_hostname_only.local"
    [[ $is_on ]] && {
        echo -n "$c_green.$c_none"
        # SERVER_IP=${SERVER_IP:-$(host $kube_hostname | head -n 1 | awk '{ print $NF; }')}
        SERVER_IP=${SERVER_IP:-$(ping -q -c 1 -t 1 $kube_hostname | grep -m 1 PING | cut -d "(" -f2 | cut -d ")" -f1)}
        [[ $? == 0 ]] || SERVER_IP='' # Could not find it

        echo -n "$c_green.$c_none"
        is_ssh_on=$(./wait-for-it.sh --quiet --timeout=2 --host=$kube_hostname --port=22 && echo 'yes')
        echo -n "$c_green.$c_none"
        is_https_on=$(./wait-for-it.sh --quiet --timeout=2 --host=$kube_hostname --port=443 && echo 'yes')
        echo -n "$c_green.$c_none"
        is_http_on=$(./wait-for-it.sh --quiet --timeout=2 --host=$kube_hostname --port=80 && echo 'yes')
    }

    echo -n "$c_green.$c_none"
    has_kubeconfig=$([[ -f ./kubeconfig ]] && echo 'yes')
    [[ $is_on ]] && is_kubeconfig_valid=$(KUBECONFIG=$(pwd)/kubeconfig kubectl version > /dev/null 2>&1 && echo 'yes')

    [[ $is_ssh_on ]] && {
        echo -n "$c_green.$c_none"
        ssh_output=$(cat ./templates/status-reporter.sh | ssh $kube_username@$kube_hostname)
        echo -n "$c_green.$c_none"
        [[ $? == 0 ]] && is_ssh_valid='yes'
        is_server_log2ram_active=$(echo $ssh_output | grep 'log2ram.service' > /dev/null 2>&1 && echo 'yes')
        is_server_zram_active=$(echo $ssh_output | grep 'zram-swap.service' > /dev/null 2>&1 && echo 'yes')
        is_server_k3s_active=$(echo $ssh_output | grep 'k3s.service' > /dev/null 2>&1 && echo 'yes')
        is_k3s_storage_root_mounted=$(echo $ssh_output | grep 'K3S_STORAGE_ROOT_IS_MOUNTED' > /dev/null 2>&1 && echo 'yes')
    }

    echo "$c_blue]$c_none"
    set -e
}

step_status() {
    echo ""
    echo "--------------------------"
    echo "Installation/Server status"
    echo "--------------------------"

    update_status

    yes_no "- Is SD card mounted at '$SD_BOOTFS' (SD_BOOTFS)?" $is_mounted
    yes_no "- Is $kube_hostname on the network?" $is_on
    [[ $is_on ]] && echo "- Server IP Address (SERVER_IP): $c_green$SERVER_IP$c_none" || echo "Server IP Address: ${c_red}UNKNOWN$c_none"
    yes_no "- Is ssh running?" $is_ssh_on
    yes_no "- Can connect via ssh?" $is_ssh_valid
    yes_no "- Is log2ram active on the server?" $is_server_log2ram_active
    yes_no "- Is zram active on the server?" $is_server_zram_active
    yes_no "- Is k3s active on the server?" $is_server_k3s_active
    yes_no "- Has kubeconfig?" $has_kubeconfig
    yes_no "- Is kubeconfig valid?" $is_kubeconfig_valid
    yes_no "- Is https running? (might need to configure the router to allow the $kube_hostname hostname)" $is_https_on
    yes_no "- Is http running?" $is_http_on
}


mkicon() {
    # $1: have prerequisites been met?
    # $2: has this step already succeeded?
    if [[ $2 ]]; then
        echo "$c_green[ok]$c_none"
    elif [[ $# == 0 ]]; then
        echo "[--]" # These are always available
    elif [[ ! $1 ]]; then
        echo "$c_red[XX]$c_none"
    else
        echo "$c_yellow[  ]$c_none"
    fi
}

gui() {
    # while :; do
        echo ""
        echo ""

        # Create a Menu
        declare -a install_steps=(
            "$(mkicon "$is_mounted") Configure SD card (optionally inject WiFi and ssh keys)"
            "$(mkicon "$is_ssh_valid" "$(ander "$is_server_log2ram_active" "$is_server_zram_active")") ssh into machine and install OS dependencies"
            "$(mkicon "$is_ssh_valid" "$(ander "$is_server_log2ram_active" "$is_server_zram_active")") Install packages that reduce the churn on the SD card (do this early!)"
            "$(mkicon "$is_ssh_valid" "$is_server_k3s_active") Install k3s"
            "$(mkicon "$is_ssh_valid" "$is_k3s_storage_root_mounted") Mount storage drive (so SD card lasts longer)"
            "$(mkicon "$is_kubeconfig_valid" "$is_https_on") Deploy apps to k3s"
            "$(mkicon "$is_kubeconfig_valid") Start proxy tunnel for Cluster dashboard"
            "$(mkicon "$is_https_on" "$has_rsync_backup_ran") Perform rsync backup"
            "$(mkicon "$is_https_on" "$has_rsync_backup_ran") Perform tarball backup of data and server"
            "$(mkicon $(ander "$is_ssh_valid" "$has_rsync_backup_ran")) Restore from backup (ToDo)"
            "$(mkicon "$is_https_on") Delete all the apps"
            "$(mkicon "$is_kubeconfig_valid") Add a new computer to the cluster"
            "$(mkicon "$is_kubeconfig_valid") Show running services"
            "$(mkicon) Quit (or press Ctrl+C)"
        )
        PS3="Choose an action (1-${#install_steps[@]}): "
        select _ in "${install_steps[@]}"; do
            case $REPLY in
                1) step_configure_sd_card; break;;
                2) step_install_os_dependencies; break;;
                3) step_install_disk_savers; break;;
                4) step_install_k3s; break;;
                5) step_mount_storage_drive; break;;
                6) step_deploy_apps; break;;
                7) step_start_proxy_tunnel; break;;
                8) step_perform_rsync_backup; break;;
                9) step_perform_tarball_backup; break;;
                10) step_restore_postgres_from_backup; break;;
                11) step_delete_apps; break;;
                12) step_add_this_node; break;;
                13) step_verify_k3s_is_up; break;;
                14)
                    echo "Exiting"
                    exit 0
                    ;;
                *) echo "invalid option $REPLY. step=$step"; break;;
            esac
        done

        step_status
    # done
}


update_status
case $1 in
    prepare) step_configure_sd_card;;
    sd) step_configure_sd_card;;
    usb) step_configure_sd_card;;
    os) step_install_os_dependencies;;
    k3s) step_install_k3s;;
    mount) step_mount_storage_drive;;
    deploy) step_deploy_apps;;
    proxy) step_start_proxy_tunnel;;
    backup-rsync) step_perform_rsync_backup;;
    backup-tarball) step_perform_tarball_backup;;
    restore-postgres) step_restore_postgres_from_backup $2;;
    delete) step_delete_apps;;
    status) step_status;;
    *) gui;;
esac

