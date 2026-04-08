#!/bin/sh
set -eu

UNLIM8TED_ROOT="${UNLIM8TED_ROOT:-/opt/unlim8ted}"
BOOT_DIR="${BOOT_DIR:-/boot}"
FIRMWARE_DIR="${FIRMWARE_DIR:-$BOOT_DIR/firmware}"
PROFILE_DIR="$UNLIM8TED_ROOT/share/boot"
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

copy_if_present() {
    src="$1"
    dst="$2"
    if [ -f "$src" ]; then
        mkdir -p "$(dirname "$dst")"
        cp "$src" "$dst"
        echo "[unlim8ted] installed $(basename "$src") -> $dst"
    fi
}

if [ "$TARGET" = "auto" ]; then
    TARGET="$(detect_target)"
fi

case "$TARGET" in
    rpi)
        copy_if_present "$PROFILE_DIR/rpi/config.txt" "$FIRMWARE_DIR/config.txt"
        ;;
    pc)
        copy_if_present "$PROFILE_DIR/pc/grub-unlim8ted.cfg" /etc/grub.d/40_unlim8ted
        ;;
    generic-arm)
        copy_if_present "$PROFILE_DIR/generic-arm/extlinux.conf" "$BOOT_DIR/extlinux/extlinux.conf"
        ;;
    *)
        echo "[unlim8ted] unknown target: $TARGET" >&2
        exit 1
        ;;
esac

echo "[unlim8ted] platform target: $TARGET"
