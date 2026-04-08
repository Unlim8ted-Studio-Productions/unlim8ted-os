#!/bin/sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
OS_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
ROOTFS_DIR="${ROOTFS_DIR:-$OS_DIR/rootfs}"
BOOTFS_DIR="${BOOTFS_DIR:-$OS_DIR/bootfs}"
OUT_DIR="${OUT_DIR:-$SCRIPT_DIR/out}"
TARGET_ARCH="${TARGET_ARCH:-$(uname -m 2>/dev/null || echo unknown)}"
KERNEL_AUTOBUILD="${KERNEL_AUTOBUILD:-1}"

normalize_arch() {
    case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
        x86_64|amd64|x64) printf '%s\n' x86_64 ;;
        aarch64|arm64|armv8|armv8l) printf '%s\n' arm64 ;;
        armv7|armv7l|armv6l|arm) printf '%s\n' arm ;;
        *) printf '%s\n' "$1" ;;
    esac
}

copy_tree() {
    src="$1"
    dst="$2"
    if [ -d "$src" ]; then
        mkdir -p "$dst"
        cp -R "$src"/. "$dst"/
    fi
}

TARGET_ARCH="$(normalize_arch "$TARGET_ARCH")"
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

if [ "$KERNEL_AUTOBUILD" = "1" ]; then
    case "$TARGET_ARCH" in
        x86_64)
            if [ ! -f "$BOOTFS_DIR/kernel/x86_64/vmlinuz-unlim8ted" ] || [ ! -f "$BOOTFS_DIR/kernel/x86_64/initramfs-unlim8ted.img" ]; then
                ROOTFS_DIR="$ROOTFS_DIR" BOOTFS_DIR="$BOOTFS_DIR" "$SCRIPT_DIR/build-kernel-x86_64.sh"
            fi
            ;;
        arm64)
            if [ ! -f "$BOOTFS_DIR/kernel/arm64/Image" ] || [ ! -f "$BOOTFS_DIR/kernel/arm64/initramfs-unlim8ted.img" ]; then
                ROOTFS_DIR="$ROOTFS_DIR" BOOTFS_DIR="$BOOTFS_DIR" "$SCRIPT_DIR/build-kernel-arm64-cm4.sh"
            fi
            ;;
    esac
fi

cat > "$OUT_DIR/build.env" <<EOF
UNLIM8TED_ARCH=$TARGET_ARCH
UNLIM8TED_ROOTFS=$ROOTFS_DIR
UNLIM8TED_BOOTFS=$BOOTFS_DIR
EOF

case "$TARGET_ARCH" in
    x86_64)
        if ! command -v grub-mkrescue >/dev/null 2>&1; then
            printf 'missing required tool: grub-mkrescue\n' >&2
            exit 1
        fi
        ISO_ROOT="$OUT_DIR/iso"
        mkdir -p "$ISO_ROOT/boot/grub" "$ISO_ROOT/live"
        cp "$BOOTFS_DIR/kernel/x86_64/vmlinuz-unlim8ted" "$ISO_ROOT/boot/vmlinuz-unlim8ted"
        cp "$BOOTFS_DIR/kernel/x86_64/initramfs-unlim8ted.img" "$ISO_ROOT/boot/initramfs-unlim8ted.img"
        cp "$BOOTFS_DIR/pc/grub/grub.cfg" "$ISO_ROOT/boot/grub/grub.cfg"
        if command -v mksquashfs >/dev/null 2>&1; then
            mksquashfs "$ROOTFS_DIR" "$ISO_ROOT/live/filesystem.squashfs" -noappend >/dev/null
        fi
        grub-mkrescue -o "$OUT_DIR/unlim8ted-x86_64.iso" "$ISO_ROOT" >/dev/null
        printf '[unlim8ted] wrote %s\n' "$OUT_DIR/unlim8ted-x86_64.iso"
        ;;
    arm64)
        IMAGE_ROOT="$OUT_DIR/arm64"
        mkdir -p "$IMAGE_ROOT/boot/extlinux" "$IMAGE_ROOT/rootfs"
        copy_tree "$ROOTFS_DIR" "$IMAGE_ROOT/rootfs"
        cp "$BOOTFS_DIR/kernel/arm64/Image" "$IMAGE_ROOT/boot/Image"
        cp "$BOOTFS_DIR/kernel/arm64/initramfs-unlim8ted.img" "$IMAGE_ROOT/boot/initramfs-unlim8ted.img"
        cp "$BOOTFS_DIR/generic-arm/extlinux/extlinux.conf" "$IMAGE_ROOT/boot/extlinux/extlinux.conf"
        printf '[unlim8ted] staged %s\n' "$IMAGE_ROOT"
        ;;
    *)
        printf 'unsupported TARGET_ARCH: %s\n' "$TARGET_ARCH" >&2
        exit 1
        ;;
esac
