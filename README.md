nextcloud-k8s-pi


# Flash Raspberry Pi OS

## Optional: Fully-automated

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

# Install software on laptop

```sh
curl -sSL https://dl.get-arkade.dev | sudo sh
arkade get kubectl
arkade get k3sup
```

# Install k8s onto the pi

Run the following on the laptop. It will ssh into the pi.

```sh
export IP="192.168.0.123" # find from ifconfig on RPi
k3sup install --ip $IP --user pi
```

Verify the node is up:

```sh
export KUBECONFIG=`pwd`/kubeconfig
kubectl get node -o wide
```

# Optional: Install k8s Dashboard

Keep this running in a separate terminal:

```sh
kubectl proxy
```

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


# Get the token
kubectl -n kubernetes-dashboard get secret $(kubectl -n kubernetes-dashboard get sa/admin-user -o jsonpath="{.secrets[0].name}") -o go-template="{{.data.token | base64decode}}"
```

Now visit here http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/#/overview?namespace=_all and select the **Token** option.

Also, select "All Namespaces" in the left dropdown to see everything that is running.


# Customize fields

Customize the following in [nextcloud-server.yaml](./deployments/nextcloud-server.yaml):

- NEXTCLOUD_ADMIN_USER
- NEXTCLOUD_ADMIN_PASSWORD
- NEXTCLOUD_TRUSTED_DOMAINS


# Install

Run [start.sh](./start.sh) to install the ingress, persistence layer, database, and server.

If you change any of the usernames or passwords in the yaml file you will need to completely [reset.sh](./reset.sh) because both the database and nextcloud server read the environment variables only when their data directories are empty.


# Uninstall nextcloud completely

**Danger!!!** Run [reset.sh](./reset.sh) to delete all the nodes and persisted files.


# Reinstall/Update

Just run [start.sh](./start.sh) and kubernetes will apply only the changes you made.
