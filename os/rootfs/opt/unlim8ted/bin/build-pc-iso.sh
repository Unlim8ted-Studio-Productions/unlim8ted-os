#!/bin/sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
UNLIM8TED_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
WORKDIR="${WORKDIR:-$UNLIM8TED_ROOT/build/pc-iso}"
ISO_NAME="${ISO_NAME:-unlim8ted-x86_64.iso}"
KERNEL_IMAGE="${KERNEL_IMAGE:-}"
INITRAMFS_IMAGE="${INITRAMFS_IMAGE:-}"
ROOTFS_DIR="${ROOTFS_DIR:-}"
ROOT_LIVE_LABEL="${ROOT_LIVE_LABEL:-UNLIM8TED_LIVE}"

normalize_arch() {
    case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
        x86_64|amd64|x64) printf '%s\n' x86_64 ;;
        aarch64|arm64|armv8|armv8l) printf '%s\n' arm64 ;;
        *) printf '%s\n' "$1" ;;
    esac
}

require_tool() {
    if ! command -v "$1" >/dev/null 2>&1; then
        printf 'missing required tool: %s\n' "$1" >&2
        exit 1
    fi
}

ARCH="$(normalize_arch "$(uname -m 2>/dev/null || echo unknown)")"
if [ "$ARCH" != "x86_64" ]; then
    printf 'build-pc-iso.sh only builds PC ISO images on x86_64 hosts, got: %s\n' "$ARCH" >&2
    exit 1
fi

if [ -z "$KERNEL_IMAGE" ] || [ -z "$INITRAMFS_IMAGE" ] || [ -z "$ROOTFS_DIR" ]; then
    cat >&2 <<EOF
usage:
  KERNEL_IMAGE=/path/to/vmlinuz-unlim8ted \\
  INITRAMFS_IMAGE=/path/to/initramfs-unlim8ted.img \\
  ROOTFS_DIR=/path/to/rootfs \\
  $0
EOF
    exit 1
fi

require_tool grub-mkrescue

STAGING="$WORKDIR/staging"
ISO_ROOT="$STAGING/iso"
OUTPUT_ISO="$WORKDIR/$ISO_NAME"

rm -rf "$STAGING"
mkdir -p "$ISO_ROOT/boot/grub" "$ISO_ROOT/live"

cp "$KERNEL_IMAGE" "$ISO_ROOT/boot/vmlinuz-unlim8ted"
cp "$INITRAMFS_IMAGE" "$ISO_ROOT/boot/initramfs-unlim8ted.img"

if command -v mksquashfs >/dev/null 2>&1; then
    mksquashfs "$ROOTFS_DIR" "$ISO_ROOT/live/filesystem.squashfs" -noappend >/dev/null
else
    printf '[unlim8ted] warning: mksquashfs not found, ISO will be generated without live rootfs squashfs\n' >&2
fi

cat > "$ISO_ROOT/boot/grub/grub.cfg" <<EOF
set timeout=3
set default=0

menuentry "Unlim8ted OS (x86_64)" {
    linux /boot/vmlinuz-unlim8ted boot=live live-media-path=/live root=live:CDLABEL=${ROOT_LIVE_LABEL} quiet splash
    initrd /boot/initramfs-unlim8ted.img
}
EOF

cat > "$ISO_ROOT/ARCHITECTURE" <<EOF
UNLIM8TED_ARCH=x86_64
UNLIM8TED_BOOT_TARGET=pc
EOF

grub-mkrescue -o "$OUTPUT_ISO" "$ISO_ROOT" >/dev/null
printf '[unlim8ted] wrote ISO: %s\n' "$OUTPUT_ISO"
