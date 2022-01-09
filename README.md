**Table of Contents**

1. [Flash Raspberry Pi OS](#flash-raspberry-pi-os)
1. [Customize Fields](#customize-fields)
1. [Install](#install)
    - [Backups](#backups)
1. [Next Steps](#next-steps)
1. [Troubleshooting](#troubleshooting)


# Flash Raspberry Pi OS

First, purchase the following:

- a Raspberry Pi 4
- an SD card (8+ Gb but 16+ is preferable)
- optionally at least one hard drive or USB key to store all that data

**Note:** The extra storage is strongly encouraged because SD cards are not designed to be constantly written to and degrade quickly.

Flash the SD card with [Raspberry PI OS Lite](https://www.raspberrypi.com/software/)

> The Lite version is recommended because we will not need a user interface, screen, a web browsers, etc.


## Customize Fields

The services can optionally be customized by editing the yaml files in [./deployments](./deployments).

**Note:** If you change any of the usernames or passwords in the yaml files you will need to completely [reset.sh](./reset.sh) because both the database and nextcloud server read the environment variables only when their data directories are empty.


# Install

The installation is mostly automated using the [install.sh](./install.sh) script. So far it has been tested on Ubuntu but Pull Requests are welcome!

In general the steps are:

1. Configure SD card (optionally inject WiFi and ssh keys)
1. ssh into machine and install OS dependencies
1. Install packages that reduce the churn on the SD card
1. Install local helpers (k3sup)
1. Install k3s
1. Verify k3s is up
1. Mount storage drive (so SD card lasts longer)
1. Deploy apps to k3s
1. Start proxy tunnel for Cluster dashboard
1. Perform backup
1. Uninstall apps

Once the apps are deployed, visit https://kube (or https://kube.local or https://kube.lan). Sign in with username `admin` and password `password` unless you changed it earlier.


## Backups

You can SCP the [backup.sh](./backup.sh) file to the server and run it to perform a backup.

It backs up the following:

- the Postgres database for nextcloud
- all volumes in the cluster
- the k8s configuration (including secrets and keys)

### Backing up the SD card

To optionally back up the SD card perform the following:

1. turn off the pi
1. remove the SD card and insert it into a laptop
1. use the "Disk Utility" to resize the main partition down to around 4Gb. If you skip this then the image will be however large your SD card is
1. run `sudo dd status=progress if=/dev/sdX | gzip > kube-backup.img.gz` where sdX is your SD card. Sometimes it is `/dev/mmcblk0`
1. run `sudo dd status=progress if=/dev/sdX bs=1M count=5120 | gzip > kube-backup.img.gz` to limit the image size to 5GB (assuming you shrunk it in the Disk Utility) https://stackoverflow.com/a/26909977
1. resize the partition back to the full size using the "Disk Utility"


# Next Steps

Install the following Nextcloud Apps by clicking your login on the top-right and then clicking "Apps":

- [Calendar](https://apps.nextcloud.com/apps/calendar)
- [Notes](https://apps.nextcloud.com/apps/notes)
- [Tasks](https://apps.nextcloud.com/apps/tasks)

Then, on your Android phone, install the following:

- [NextCloud](https://f-droid.org/en/packages/com.nextcloud.client/)
- [DAVx5](https://f-droid.org/en/packages/at.bitfire.davdroid/) and [configuration instructions](https://www.davx5.com/tested-with/nextcloud)
- [Etar Calendar](https://f-droid.org/en/packages/ws.xsoh.etar/)
- [Tasks](https://f-droid.org/packages/org.tasks/)
- [Notes](https://f-droid.org/en/packages/it.niedermann.owncloud.notes/)
- Set your [seedvault backup](https://calyxinstitute.org/projects/seedvault-encrypted-backup-for-android) to use nextcloud too!


## Even more!

- git hosting server [gitea](https://gitea.com/gitea/helm-chart)
- AWS S3-compatible object store [min.io](https://min.io): `arkade install minio`


### Install OpenMediaVault for NFS mounts

([steps](https://singleboardbytes.com/891/set-up-openmediavault-raspberry-pi.htm))

```bash
curl -SLfs https://github.com/OpenMediaVault-Plugin-Developers/installScript/raw/master/install | sudo bash -x
# Set the port to something other than 80: https://openmediavault.readthedocs.io/en/5.x/various/advset.html
omv-firstaid
sudo reboot # important for the nfs service to start up
```


### Connect from another location
	
Your phone can connect to `https://kube` from another location if you have one other machine:

1. Enable ssh access to your home network. This usually involves setting up your router to talk to a DDNS provider and then enabling port forwarding on your router to a bastion machine inside your network.
1. Forward the port to a local machine: `sudo ssh -i ~/.ssh/id_rsa -L 0.0.0.0:kube:443 username@myhomeaddress.com` The 0.0.0.0 ensures other devices can see the local port and the `sudo` allows you to listen to ports below 1024
1. Set the hostname of your laptop to be `kube`



# Troubleshooting

- `error: yaml: line 30: mapping values are not allowed in this context` : Set KUBECONFIG= to the absolute path to the `kubeconfig` files (generated during the `k3sup install ...` step)
- If you see "Service Unavailable" then kubernetes may still be downloading images. Check the dashboard to see the status
- If you see "Bad Gateway" nextcloud may still be starting up (it took 3 minutes for me).
    - See the logs in the dashboard by clicking the `nextcloud-server-a1b2c3` **Pod** (not Deployment) and then clicking the Logs button
    - The logs will end with `AH00163: Apache/2.4.38 (Debian) PHP/7.4.16 configured -- resuming normal operations` when it is complete
- If you get a browser error then try running `ping kube.local`. If there is no answer then use the pis hostname and update the `nextcloud-ingress.yaml` and `nextcloud-server.yaml` files.

If it does not load up you can view the logs by visiting the k8s dashboard, 


## File redundancy

See https://old.reddit.com/r/selfhosted/comments/n4pkwk/finally_added_prometheus_and_grafana_on_my_humble/gwxb3se/


## 32-bit vs 64bit

photoprism no longer builds 32-bit and 64-bit images under the same name. That means that 64-bit images can be referenced by immutable tags while the 32bit image needs to use the [armv7 tag](https://hub.docker.com/r/photoprism/photoprism/tags)

```
photoprism/photoprism:20211203  # This is the last version that works with 32bit and 64bit raspberry pi
```

## Debugging Nextcloud 500 errors

Run `php occ log:watch` as the `www-data` user. Open a shell to nextcloud-server instance and run:

```
su www-data -s /bin/bash
cs /var/www/html/
php occ log:watch    # <-- shows stack traces
```
