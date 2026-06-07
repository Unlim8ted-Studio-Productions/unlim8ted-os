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

error_recovery_shell() {
    status=$1
    line=$2
    cmd=$3

    set +e
    printf '\nERROR: command failed at line %s: %s\n' "$line" "$cmd"
    printf 'An interactive recovery shell is opening on tty1.\n'
    printf "Fix the issue, then run '/opt/unlim8ted/bin/firstboot-install.sh' again.\n"
    printf "Type 'exit' to leave the recovery shell.\n\n"
    exec </dev/tty1 >/dev/tty1 2>&1
    export PS1='firstboot-recovery# '
    /bin/bash -i
    exit "$status"
}

trap 'error_recovery_shell "$?" "$LINENO" "$BASH_COMMAND"' ERR

if [ -f "$ENV_FILE" ]; then
    # The deferred image writes package and Wi-Fi settings here before first boot.
    # shellcheck disable=SC1090
    . "$ENV_FILE"
fi

PACKAGES=${UNLIM8TED_FIRSTBOOT_PACKAGES:-python3 chromium bluez wpasupplicant xserver-xorg xinit x11-xserver-utils xserver-xorg-input-libinput keyboard-configuration usbutils openbox mesa-utils dbus-x11 fonts-dejavu-core}
PLYMOUTH_CONFIG=/etc/plymouth/plymouthd.conf
PLYMOUTH_STASH=/var/lib/unlim8ted/plymouthd.conf.custom

apply_keyboard_defaults() {
    keyboard_layout=${KEYBOARD_LAYOUT:-us}
    keyboard_model=${KEYBOARD_MODEL:-pc105}

    cat >/etc/default/keyboard <<EOF
XKBMODEL="$keyboard_model"
XKBLAYOUT="$keyboard_layout"
XKBVARIANT=""
XKBOPTIONS=""
BACKSPACE="guess"
EOF

    if command -v debconf-set-selections >/dev/null 2>&1; then
        {
            printf 'keyboard-configuration keyboard-configuration/layoutcode string %s\n' "$keyboard_layout"
            printf 'keyboard-configuration keyboard-configuration/modelcode string %s\n' "$keyboard_model"
            printf 'keyboard-configuration keyboard-configuration/variantcode string \n'
            printf 'keyboard-configuration keyboard-configuration/optionscode string \n'
        } | debconf-set-selections
    fi

    setupcon --force >/dev/null 2>&1 || true
}

stash_custom_plymouth_config() {
    if [ -f "$PLYMOUTH_CONFIG" ]; then
        mkdir -p "$(dirname "$PLYMOUTH_STASH")"
        cp "$PLYMOUTH_CONFIG" "$PLYMOUTH_STASH"
        rm -f "$PLYMOUTH_CONFIG"
    fi
}

restore_custom_plymouth_config() {
    [ -f "$PLYMOUTH_STASH" ] || return 0

    mkdir -p /etc/plymouth
    if command -v dpkg-divert >/dev/null 2>&1; then
        if ! dpkg-divert --list "$PLYMOUTH_CONFIG" 2>/dev/null | grep -F "$PLYMOUTH_CONFIG" >/dev/null 2>&1; then
            dpkg-divert --quiet --local --rename --divert "${PLYMOUTH_CONFIG}.distrib" --add "$PLYMOUTH_CONFIG"
        fi
    fi
    cp "$PLYMOUTH_STASH" "$PLYMOUTH_CONFIG"
    chmod 644 "$PLYMOUTH_CONFIG"
}

ensure_boot_mount() {
    if mountpoint -q /boot/firmware; then
        return 0
    fi

    mkdir -p /boot/firmware /boot

    if ! mountpoint -q /boot/firmware; then
        mount LABEL=bootfs /boot/firmware 2>/dev/null || true
    fi
    if ! mountpoint -q /boot/firmware; then
        mount LABEL=boot /boot/firmware 2>/dev/null || true
    fi
    if ! mountpoint -q /boot && ! mountpoint -q /boot/firmware; then
        mount LABEL=bootfs /boot 2>/dev/null || true
    fi
}

trim_value() {
    printf '%s' "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

ensure_wifi_country() {
    country=${WIFI_COUNTRY:-US}
    mkdir -p /etc/wpa_supplicant

    if [ -f /etc/wpa_supplicant/wpa_supplicant.conf ]; then
        if grep -q '^country=' /etc/wpa_supplicant/wpa_supplicant.conf 2>/dev/null; then
            sed -i "s/^country=.*/country=$country/" /etc/wpa_supplicant/wpa_supplicant.conf
        else
            tmp_conf=/etc/wpa_supplicant/wpa_supplicant.conf.unlim8ted
            {
                printf 'country=%s\n' "$country"
                cat /etc/wpa_supplicant/wpa_supplicant.conf
            } >"$tmp_conf"
            mv "$tmp_conf" /etc/wpa_supplicant/wpa_supplicant.conf
        fi
    else
        {
            printf 'country=%s\n' "$country"
            printf 'ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev\n'
            printf 'update_config=1\n'
        } >/etc/wpa_supplicant/wpa_supplicant.conf
    fi

    chmod 600 /etc/wpa_supplicant/wpa_supplicant.conf
}

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

unblock_radios() {
    ensure_wifi_country

    if command -v rfkill >/dev/null 2>&1; then
        rfkill unblock wifi 2>/dev/null || true
        rfkill unblock wlan 2>/dev/null || true
        rfkill unblock bluetooth 2>/dev/null || true
        rfkill unblock all 2>/dev/null || true
    fi

    systemctl restart wpa_supplicant.service 2>/dev/null || true
    systemctl restart dhcpcd.service 2>/dev/null || true
    systemctl restart NetworkManager.service 2>/dev/null || true
}

configure_wifi_nmcli() {
    ssid=$(trim_value "$1")
    password=$2

    unblock_radios

    nmcli radio wifi on >/dev/null 2>&1 || true
    nmcli dev wifi rescan >/dev/null 2>&1 || true
    sleep 2

    if ! nmcli -t -f SSID dev wifi list 2>/dev/null | sed 's/[[:space:]]*$//' | grep -Fx -- "$ssid" >/dev/null 2>&1; then
        nmcli dev wifi rescan >/dev/null 2>&1 || true
        sleep 4
    fi

    if [ -n "$password" ]; then
        nmcli dev wifi connect "$ssid" password "$password"
    else
        nmcli dev wifi connect "$ssid"
    fi
}

configure_wifi_wpa() {
    ssid=$(trim_value "$1")
    password=$2

    unblock_radios

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

    unblock_radios
}

configure_wifi_credentials() {
    ssid=$(trim_value "$1")
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
    unblock_radios
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
        unblock_radios

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
                printf 'Waiting indefinitely for internet without prompting for input...\n'
                sleep 8
                continue
                ;;
        esac

        cat <<EOF
Unlim8ted OS needs internet access to finish installing packages.

Connect Ethernet now, or enter Wi-Fi credentials below.
Press Enter on an empty SSID to retry network detection.
This prompt will wait indefinitely on tty1 until network setup succeeds.
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
    systemctl disable unlim8ted-firstboot-install.service >/dev/null 2>&1 || true
    systemctl enable unlim8ted.service >/dev/null 2>&1 || true
    systemctl start unlim8ted.service >/dev/null 2>&1 || true
    exit 0
fi

systemctl disable unlim8ted.service >/dev/null 2>&1 || true
expand_rootfs
apply_keyboard_defaults
ensure_network
ensure_boot_mount

export DEBIAN_FRONTEND=noninteractive
APT_DPKG_OPTS='-o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold'
read -r -a package_args <<< "$PACKAGES"
stash_custom_plymouth_config
dpkg --configure -a || true
apt-get $APT_DPKG_OPTS -f install -y || true
apt-get update
apt-get $APT_DPKG_OPTS install -y "${package_args[@]}"
restore_custom_plymouth_config
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
systemctl disable unlim8ted-firstboot-install.service >/dev/null 2>&1 || true
systemctl enable unlim8ted.service >/dev/null 2>&1 || true

printf '\nPackage install complete. Starting kiosk...\n'
systemctl start unlim8ted.service
