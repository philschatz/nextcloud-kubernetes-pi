#!/bin/bash

set -e

# --------------------------------------------------
# The following are injected values from the install.sh script
# --------------------------------------------------
AUTHORIZED_SSH_KEYS='%%AUTHORIZED_SSH_KEYS%%'
WIFI_NAME='%%WIFI_NAME%%'
WIFI_PASSPHRASE='%%WIFI_PASSPHRASE%%'
WIFI_COUNTRY_CODE='%%WIFI_COUNTRY_CODE%%'
NEW_HOSTNAME='%%NEW_HOSTNAME%%'


CURRENT_HOSTNAME=$(cat /etc/hostname | tr -d " \t\n\r")
echo $NEW_HOSTNAME >/etc/hostname
sed -i "s/127.0.1.1.*$CURRENT_HOSTNAME/127.0.1.1\t$NEW_HOSTNAME/g" /etc/hosts

[[ "$AUTHORIZED_SSH_KEYS" ]] && {
    FIRSTUSER=$(getent passwd 1000 | cut -d: -f1)
    FIRSTUSERHOME=$(getent passwd 1000 | cut -d: -f6)
    install -o "$FIRSTUSER" -m 700 -d "$FIRSTUSERHOME/.ssh"
    echo "$AUTHORIZED_SSH_KEYS" | install -o "$FIRSTUSER" -m 600 /dev/stdin "$FIRSTUSERHOME/.ssh/authorized_keys"
    [[ -d /etc/ssh/sshd_config.d ]] || install -o root -m 644 -d /etc/ssh/sshd_config.d
    echo 'PasswordAuthentication no' >>/etc/ssh/sshd_config.d/no_password_login.conf
}
systemctl enable ssh

[[ $WIFI_NAME ]] && {

  cat >/etc/wpa_supplicant/wpa_supplicant.conf <<WPAEOF
  country=$WIFI_COUNTRY_CODE
  ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
  ap_scan=1

  update_config=1
  network={
    ssid="$WIFI_NAME"
    psk="$WIFI_PASSPHRASE"
  }

WPAEOF
  chmod 600 /etc/wpa_supplicant/wpa_supplicant.conf
  rfkill unblock wifi
  for filename in /var/lib/systemd/rfkill/*:wlan ; do
    echo 0 > $filename
  done
}

rm -f /boot/firstrun.sh
sed -i 's| systemd.run.*||g' /boot/cmdline.txt
exit 0