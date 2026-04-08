#!/bin/sh
set -eu

BOOT_DIR="${BOOT_DIR:-/boot}"
FIRMWARE_DIR="${FIRMWARE_DIR:-$BOOT_DIR/firmware}"
TARGET="${1:-auto}"

normalize_arch() {
    case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
        x86_64|amd64|x64) echo x86_64 ;;
        aarch64|arm64|armv8|armv8l) echo arm64 ;;
        armv7|armv7l|armv6l|arm) echo arm ;;
        i386|i486|i586|i686|x86) echo x86 ;;
        *) echo "$1" ;;
    esac
}

detect_target() {
    machine="$(normalize_arch "$(uname -m 2>/dev/null || echo unknown)")"
    if [ -r /sys/firmware/devicetree/base/model ] && grep -qi 'raspberry pi' /sys/firmware/devicetree/base/model; then
        echo rpi
        return
    fi
    case "$machine" in
        arm64|arm) echo generic-arm ;;
        x86_64|x86) echo pc ;;
        *) echo pc ;;
    esac
}

if [ "$TARGET" = "auto" ]; then
    TARGET="$(detect_target)"
fi

case "$TARGET" in
    rpi)
        cp /bootfs/rpi/config.txt "$FIRMWARE_DIR/config.txt"
        ;;
    generic-arm)
        mkdir -p "$BOOT_DIR/extlinux"
        cp /bootfs/generic-arm/extlinux/extlinux.conf "$BOOT_DIR/extlinux/extlinux.conf"
        ;;
    pc)
        mkdir -p /etc/grub.d
        cp /bootfs/pc/grub/grub.cfg /etc/grub.d/40_unlim8ted
        ;;
    *)
        printf 'unknown target: %s\n' "$TARGET" >&2
        exit 1
        ;;
esac
