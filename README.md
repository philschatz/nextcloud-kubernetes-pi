**Table of Contents**

1. [Flash Raspberry Pi OS](#flash-raspberry-pi-os)
    - [Optional: Configure USB Boot](#optional-configure-usb-boot)
    - [Optional: Fully-automated](#optional-fully-automated)
1. [Get SSH working on the pi](#get-ssh-working-on-the-pi)
1. [Final touches on the pi](#final-touches-on-the-pi)
1. [Install software on laptop](#install-software-on-laptop)
1. [Install kubernetes (k8s) onto the pi](#install-kubernetes-k8s-onto-the-pi)
    - [Optional: Install k8s Dashboard](#optional-install-k8s-dashboard)
1. [Customize fields](#customize-fields)
1. [Install](#install)
1. [Uninstall nextcloud completely](#uninstall-nextcloud-completely)
1. [Reinstall/Update](#reinstallupdate)
1. [Next Steps!](#next)
1. [Common Errors](#error-cheatsheets)


# Flash Raspberry Pi OS

First, purchase a Raspberry Pi 4, an SD card, and optionally a USB key.

It is advisable to use a USB key since nextcloud writes a lot and USB keys tend to last longer.

## Optional: Configure USB Boot

1. Flash the SD card with raspberry PI OS and boot using it.
    - If you do not have a keyboard, ethernet cable, or monitor you can use the "Fully Automated" instructions below to ssh into it instead.
1. Log in to the pi and run `sudo raspi-config`
1. In "Boot Options", select "Boot Order", select "Boot from USB", and restart


## Optional: Fully-automated

These instructions will configure the raspberry pi to:

- sign in to your wifi
- start up the ssh service
- add your public ssh key to log in
- disable password login

<details>
<summary>Click me to see how to set up the USB stick (or SD card) to be completely automated</summary>

### Replace `/boot/cmdline.txt`

```
console=serial0,115200 console=tty1 root=PARTUUID=83c4223d-02 rootfstype=ext4 elevator=deadline fsck.repair=yes rootwait quiet init=/usr/lib/raspi-config/init_resize.sh systemd.run=/boot/firstrun.sh systemd.run_success_action=reboot systemd.unit=kernel-command-line.target cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory
```

### Create `/boot/firstrun.sh`

```sh
#!/bin/bash

set +e

# --------------------------------------------------
# EDIT THE FOLLOWING:
# - AUTHORIZED_SSH_KEYS
# - WIFI_NAME
# - WIFI_PASSWORD
# - WIFI_COUNTRY_CODE
# - NEW_HOSTNAME
# --------------------------------------------------

AUTHORIZED_SSH_KEYS='ssh-rsa AAAAAABBBBBBCCCCC....'
WIFI_NAME='My Wifi Name'
WIFI_PASSWORD='mysecretpassword'
WIFI_COUNTRY_CODE='us'
NEW_HOSTNAME='kube'


CURRENT_HOSTNAME=`cat /etc/hostname | tr -d " \t\n\r"`
echo kube >/etc/hostname
sed -i "s/127.0.1.1.*$CURRENT_HOSTNAME/127.0.1.1\t$NEW_HOSTNAME/g" /etc/hosts
FIRSTUSER=`getent passwd 1000 | cut -d: -f1`
FIRSTUSERHOME=`getent passwd 1000 | cut -d: -f6`
install -o "$FIRSTUSER" -m 700 -d "$FIRSTUSERHOME/.ssh"
install -o "$FIRSTUSER" -m 600 <(echo "$AUTHORIZED_SSH_KEYS") "$FIRSTUSERHOME/.ssh/authorized_keys"
echo 'PasswordAuthentication no' >>/etc/ssh/sshd_config
systemctl enable ssh
cat >/etc/wpa_supplicant/wpa_supplicant.conf <<WPAEOF
country=${WIFI_COUNTRY_CODE}
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
ap_scan=1

update_config=1
network={
	ssid="${WIFI_NAME}"
	psk="${WIFI_PASSWORD}"
}

WPAEOF
chmod 600 /etc/wpa_supplicant/wpa_supplicant.conf
rfkill unblock wifi
for filename in /var/lib/systemd/rfkill/*:wlan ; do
  echo 0 > $filename
done
rm -f /boot/firstrun.sh
sed -i 's| systemd.run.*||g' /boot/cmdline.txt
exit 0
```

</details>


# Get SSH working on the pi

We need to get to the point that we can run this without being prompted for a password:

```sh
export IP="192.168.0.123" # find from ifconfig on RPi
ssh pi@$IP
```

# Final touches on the pi

Also, use `sudo raspi-config` to set the GPU memory to 16 (in the "Performance" section)

Also, `sudo nano /bood/cmdfile.txt` and add `cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory` to the end of the first line (**Not on a new line!**)


# Install software on laptop

```sh
curl -sSL https://dl.get-arkade.dev | sudo sh
arkade get kubectl
arkade get k3sup
```

# Install kubernetes (k8s) onto the pi

Run the following on your computer. It will ssh into the pi.

```sh
export IP="192.168.0.123" # find from ifconfig on RPi
k3sup install --ip $IP --user pi
```

Verify the node is up:

```sh
export KUBECONFIG=`pwd`/kubeconfig
kubectl get node -o wide
```

Put `KUBECONFIG=` into `~/bash_profile` or remember to keep setting it when you open a new terminal.

# Optional: Install k8s Dashboard

Run the following to install the dashboard, add an admin user, and get a token to sign into the dashboard:

```sh
arkade install kubernetes-dashboard

# Install an admin user
cat <<EOF | kubectl apply -f -                                                                                                    
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
EOF

cat <<EOF | kubectl apply -f -                                                                                                    
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:                         
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
EOF

# Set again just in case
export KUBECONFIG=`pwd`/kubeconfig

# Get the token
kubectl -n kubernetes-dashboard get secret $(kubectl -n kubernetes-dashboard get sa/admin-user -o jsonpath="{.secrets[0].name}") -o go-template="{{.data.token | base64decode}}"

# Start the proxy
kubectl proxy
```

Now visit here http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/#/overview?namespace=_all and select the **Token** option.

Also, select "All Namespaces" in the left dropdown to see everything that is running.


# Customize fields

Customize the following in [nextcloud-server.yaml](./deployments/nextcloud-server.yaml):

- NEXTCLOUD_ADMIN_USER=admin
- NEXTCLOUD_ADMIN_PASSWORD=password
- NEXTCLOUD_TRUSTED_DOMAINS=cloud.lan kube kube.local kube.lan


# Install

**Reminder:** Put `KUBECONFIG=` into `~/bash_profile` or remember to keep setting it when you open a new terminal.

Run [start.sh](./start.sh) to install the ingress, persistence layer, database, and server.

If you change any of the usernames or passwords in the yaml file you will need to completely [reset.sh](./reset.sh) because both the database and nextcloud server read the environment variables only when their data directories are empty.


Now, visit https://kube.local (or https://kube or https://kube.lan). Sign in with username `admin` and password `password` unless you changed it earlier.

Troubleshooting:

- If you see "Service Unavailable" then kubernetes may still be downloading images. Check the dashboard to see the status
- If you see "Bad Gateway" nextcloud may still be starting up (it took 3 minutes for me).
    - See the logs in the dashboard by clicking the `nextcloud-server-a1b2c3` **Pod** (not Deployment) and then clicking the Logs button
    - The logs will end with `AH00163: Apache/2.4.38 (Debian) PHP/7.4.16 configured -- resuming normal operations` when it is complete
- If you get a browser error then try running `ping kube.local`. If there is no answer then use the pis hostname and update the `cluster-ingress.yaml` and `nextcloud-server.yaml` files.

If it does not load up you can view the logs by visiting the k8s dashboard, 


# Uninstall nextcloud completely

**Danger!!!** Run [reset.sh](./reset.sh) to delete all the nodes and persisted files.


# Reinstall/Update

Just run [start.sh](./start.sh) and kubernetes will apply only the changes you made.


# Next!

Install the following Nextcloud Apps by clicking your login on the top-right and then clicking "Apps":

- [Calendar](https://apps.nextcloud.com/apps/calendar)
- [Notes](https://apps.nextcloud.com/apps/notes)
- [Tasks](https://apps.nextcloud.com/apps/tasks)

Then, on your Android phone, install the following:

- [NextCloud](https://f-droid.org/en/packages/com.nextcloud.client/)
- [DAVx5](https://f-droid.org/en/packages/at.bitfire.davdroid/)
- [Etar Calendar](https://f-droid.org/en/packages/ws.xsoh.etar/)
- [Tasks](https://f-droid.org/packages/org.tasks/)
- [Notes](https://f-droid.org/en/packages/it.niedermann.owncloud.notes/)
- Set your [seedvault backup](https://calyxinstitute.org/projects/seedvault-encrypted-backup-for-android) to use nextcloud too!

## Even more!

### Install minio

[min.io](https://min.io) is an AWS S3-compatible object store.

1. Run `arkade install minio`

This should give you instructions to connect to the instance and see. Also, it should give you instructions to use in your app (e.g. nextcloud) if you want.




# Error cheatsheets:

`error: yaml: line 30: mapping values are not allowed in this context` : Set KUBECONFIG= to the absolute path to the `kubeconfig` files (generated during the `k3sup install ...` step)
