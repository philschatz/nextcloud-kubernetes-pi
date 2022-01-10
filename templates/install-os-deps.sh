set -x -e

sudo apt-get update
sudo apt-get upgrade --no-install-recommends -y
sudo apt-get install --no-install-recommends -y \
    git \
    pmount \
    downtimed \
;

# Remove unnecessary apt and temp files
sudo apt-get autoremove -y
sudo rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
