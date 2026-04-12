#!/bin/bash
set -eu

PACKAGES=${UNLIM8TED_FIRSTBOOT_PACKAGES:-python3 chromium libcamera-apps bluez wpasupplicant xserver-xorg xinit x11-xserver-utils xserver-xorg-input-libinput keyboard-configuration usbutils openbox mesa-utils dbus-x11 fonts-dejavu-core plymouth plymouth-themes}
MARKER=/var/lib/unlim8ted/packages-installed
LOG=/var/log/unlim8ted-firstboot-install.log

mkdir -p /var/lib/unlim8ted
touch "$LOG"
exec > >(tee -a "$LOG") 2>&1

expand_rootfs() {
    root_source=$(findmnt -n -o SOURCE /)
    [ -n "$root_source" ] || return 0

    printf 'Expanding root filesystem on %s...\n' "$root_source"
    resize2fs "$root_source" || true
}

have_internet() {
    if command -v ping >/dev/null 2>&1; then
        ping -c 1 -W 3 1.1.1.1 >/dev/null 2>&1 || ping -c 1 -W 3 deb.debian.org >/dev/null 2>&1
        return
    fi

    getent ahosts deb.debian.org >/dev/null 2>&1
}

prompt_wifi_nmcli() {
    printf '\nAvailable Wi-Fi networks:\n'
    nmcli -f SSID,SIGNAL,SECURITY dev wifi list 2>/dev/null || true
    printf '\nWi-Fi SSID: '
    read -r ssid
    [ -n "$ssid" ] || return 1
    printf 'Wi-Fi password, leave blank for open network: '
    stty -echo 2>/dev/null || true
    read -r password
    stty echo 2>/dev/null || true
    printf '\n'

    if [ -n "$password" ]; then
        nmcli dev wifi connect "$ssid" password "$password"
    else
        nmcli dev wifi connect "$ssid"
    fi
}

prompt_wifi_wpa() {
    printf '\nWi-Fi SSID: '
    read -r ssid
    [ -n "$ssid" ] || return 1
    printf 'Wi-Fi password, leave blank for open network: '
    stty -echo 2>/dev/null || true
    read -r password
    stty echo 2>/dev/null || true
    printf '\n'

    country=${WIFI_COUNTRY:-US}
    mkdir -p /etc/wpa_supplicant
    {
        printf 'country=%s\n' "$country"
        printf 'ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev\n'
        printf 'update_config=1\n\n'
        if [ -n "$password" ]; then
            wpa_passphrase "$ssid" "$password"
        else
            printf 'network={\n'
            printf '    ssid="%s"\n' "$ssid"
            printf '    key_mgmt=NONE\n'
            printf '}\n'
        fi
    } >/etc/wpa_supplicant/wpa_supplicant.conf
    chmod 600 /etc/wpa_supplicant/wpa_supplicant.conf

    systemctl restart wpa_supplicant.service 2>/dev/null || true
    systemctl restart dhcpcd.service 2>/dev/null || true
    systemctl restart NetworkManager.service 2>/dev/null || true
}

ensure_network() {
    while ! have_internet; do
        clear || true
        cat <<EOF
Unlim8ted OS needs internet access to finish installing packages.

Connect Ethernet now, or enter Wi-Fi credentials below.
Press Enter on an empty SSID to retry network detection.
EOF

        if command -v nmcli >/dev/null 2>&1; then
            prompt_wifi_nmcli || true
        elif command -v wpa_passphrase >/dev/null 2>&1; then
            prompt_wifi_wpa || true
        else
            printf 'No nmcli or wpa_passphrase is available. Connect Ethernet, then press Enter.'
            read -r _
        fi

        printf 'Waiting for network...\n'
        sleep 8
    done
}

if [ -f "$MARKER" ]; then
    systemctl enable unlim8ted.service >/dev/null 2>&1 || true
    systemctl start unlim8ted.service >/dev/null 2>&1 || true
    exit 0
fi

systemctl disable unlim8ted.service >/dev/null 2>&1 || true
expand_rootfs
ensure_network

export DEBIAN_FRONTEND=noninteractive
dpkg --configure -a || true
apt-get -f install -y || true
apt-get update
apt-get install -y $PACKAGES
apt-get clean
apt-get autoclean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

if command -v chromium >/dev/null 2>&1 && ! command -v chromium-browser >/dev/null 2>&1; then
    ln -sf /usr/bin/chromium /usr/bin/chromium-browser
fi

if command -v plymouth-set-default-theme >/dev/null 2>&1; then
    plymouth-set-default-theme -R unlim8ted-eight || true
elif [ -f /usr/share/plymouth/themes/unlim8ted-eight/unlim8ted-eight.plymouth ]; then
    ln -sfn unlim8ted-eight/unlim8ted-eight.plymouth /usr/share/plymouth/themes/default.plymouth
fi

touch "$MARKER"
systemctl disable unlim8ted-firstboot-install.service >/dev/null 2>&1 || true
systemctl enable unlim8ted.service >/dev/null 2>&1 || true

printf '\nPackage install complete. Starting kiosk...\n'
systemctl start unlim8ted.service
