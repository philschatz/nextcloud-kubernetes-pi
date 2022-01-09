set -x -e

# Install zram-swap if it is not already running
systemctl -q is-active zram-swap || {
    [[ -d ./zram-swap ]] && rm -r ./zram-swap # delete if dir already exists

    git clone https://github.com/foundObjects/zram-swap.git
    pushd ./zram-swap
    sudo ./install.sh
    popd
    rm -r ./zram-swap
}

# Install log2ram if it is not already running
systemctl -q is-active log2ram || {
    [[ -d ./log2ram-master ]] && rm -r ./log2ram-master # delete if dir already exists
    
    curl -Lo log2ram.tar.gz https://github.com/azlux/log2ram/archive/master.tar.gz
    tar xf log2ram.tar.gz
    pushd ./log2ram-master
    chmod +x install.sh && sudo ./install.sh
    popd
    rm -r ./log2ram-master

    echo "Installing log2ram requires a reboot. Rebooting now..."
    sudo systemctl reboot
}
