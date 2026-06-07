#!/bin/bash
set -Eeu -o pipefail

ENV_FILE=/etc/default/unlim8ted-firstboot
MARKER=/var/lib/unlim8ted/packages-installed
LOG=/var/log/unlim8ted-firstboot-install.log
AUTO_WIFI_ATTEMPTED=0
NONINTERACTIVE_WIFI=${UNLIM8TED_FIRSTBOOT_NONINTERACTIVE_WIFI:-0}

mkdir -p /var/lib/unlim8ted
touch "$LOG"
exec > >(tee -a "$LOG") 2>&1

trap 'printf "\nERROR: command failed at line %s: %s\n" "$LINENO" "$BASH_COMMAND"' ERR

if [ -f "$ENV_FILE" ]; then
    # The deferred image writes package and Wi-Fi settings here before first boot.
    # shellcheck disable=SC1090
    . "$ENV_FILE"
fi

PACKAGES=${UNLIM8TED_FIRSTBOOT_PACKAGES:-python3 chromium bluez wpasupplicant xserver-xorg xinit x11-xserver-utils xserver-xorg-input-libinput keyboard-configuration usbutils openbox mesa-utils dbus-x11 fonts-dejavu-core plymouth plymouth-themes}

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

configure_wifi_nmcli() {
    ssid=$1
    password=$2

    if [ -n "$password" ]; then
        nmcli dev wifi connect "$ssid" password "$password"
    else
        nmcli dev wifi connect "$ssid"
    fi
}

configure_wifi_wpa() {
    ssid=$1
    password=$2

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

configure_wifi_credentials() {
    ssid=$1
    password=$2

    [ -n "$ssid" ] || return 1

    if command -v nmcli >/dev/null 2>&1; then
        configure_wifi_nmcli "$ssid" "$password"
        return
    fi

    if command -v wpa_passphrase >/dev/null 2>&1 || [ -z "$password" ]; then
        configure_wifi_wpa "$ssid" "$password"
        return
    fi

    return 1
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

    configure_wifi_nmcli "$ssid" "$password"
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

    configure_wifi_wpa "$ssid" "$password"
}

ensure_network() {
    while ! have_internet; do
        clear || true

        if [ "$AUTO_WIFI_ATTEMPTED" -eq 0 ] && [ -n "${UNLIM8TED_FIRSTBOOT_WIFI_SSID:-}" ]; then
            AUTO_WIFI_ATTEMPTED=1
            printf 'Trying build-provided Wi-Fi profile: %s\n' "$UNLIM8TED_FIRSTBOOT_WIFI_SSID"
            configure_wifi_credentials "${UNLIM8TED_FIRSTBOOT_WIFI_SSID}" "${UNLIM8TED_FIRSTBOOT_WIFI_PASSWORD:-}" || true
            printf 'Waiting for network...\n'
            sleep 8
            continue
        fi

        case "$(printf '%s' "$NONINTERACTIVE_WIFI" | tr '[:upper:]' '[:lower:]')" in
            1 | true | yes | on)
                printf 'Waiting for internet without prompting for input...\n'
                sleep 8
                continue
                ;;
        esac

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
            printf 'No nmcli or wpa_passphrase is available. Connect Ethernet, then press Enter.\n'
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
read -r -a package_args <<< "$PACKAGES"
dpkg --configure -a || true
apt-get -f install -y || true
apt-get update
apt-get install -y "${package_args[@]}"
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
rm -f /etc/default/unlim8ted-firstboot
systemctl enable unlim8ted.service >/dev/null 2>&1 || true

printf '\nPackage install complete. Starting kiosk...\n'
systemctl start unlim8ted.service
