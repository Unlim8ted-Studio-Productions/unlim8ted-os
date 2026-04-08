#!/bin/sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
UNLIM8TED_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
WORKDIR="${WORKDIR:-$UNLIM8TED_ROOT/build/arm64-image}"
BOOT_DIR="$WORKDIR/boot"
ROOTFS_DIR="$WORKDIR/rootfs"
KERNEL_IMAGE="${KERNEL_IMAGE:-}"
INITRAMFS_IMAGE="${INITRAMFS_IMAGE:-}"

normalize_arch() {
    case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
        aarch64|arm64|armv8|armv8l) printf '%s\n' arm64 ;;
        x86_64|amd64|x64) printf '%s\n' x86_64 ;;
        *) printf '%s\n' "$1" ;;
    esac
}

ARCH="$(normalize_arch "$(uname -m 2>/dev/null || echo unknown)")"
if [ "$ARCH" != "arm64" ] && [ "$ARCH" != "x86_64" ]; then
    printf 'unsupported host architecture: %s\n' "$ARCH" >&2
    exit 1
fi

if [ -z "$KERNEL_IMAGE" ] || [ -z "$INITRAMFS_IMAGE" ]; then
    cat >&2 <<EOF
usage:
  KERNEL_IMAGE=/path/to/Image \\
  INITRAMFS_IMAGE=/path/to/initramfs-unlim8ted.img \\
  $0
EOF
    exit 1
fi

rm -rf "$WORKDIR"
mkdir -p "$BOOT_DIR/extlinux" "$ROOTFS_DIR/opt"

cp "$KERNEL_IMAGE" "$BOOT_DIR/Image"
cp "$INITRAMFS_IMAGE" "$BOOT_DIR/initramfs-unlim8ted.img"
cp "$UNLIM8TED_ROOT/share/boot/generic-arm/extlinux.conf" "$BOOT_DIR/extlinux/extlinux.conf"

cat > "$BOOT_DIR/ARCHITECTURE" <<EOF
UNLIM8TED_ARCH=arm64
UNLIM8TED_BOOT_TARGET=generic-arm
EOF

printf '[unlim8ted] staged generic ARM64 boot tree: %s\n' "$WORKDIR"
