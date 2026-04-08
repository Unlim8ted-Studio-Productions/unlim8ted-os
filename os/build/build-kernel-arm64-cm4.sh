#!/bin/sh
set -eu

PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
OS_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
ROOTFS_DIR="${ROOTFS_DIR:-$OS_DIR/rootfs}"
BOOTFS_DIR="${BOOTFS_DIR:-$OS_DIR/bootfs}"
WORK_DIR="${WORK_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/unlim8ted-kernel-build}"
JOBS="${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)}"
ARM64_CROSS_COMPILE="${ARM64_CROSS_COMPILE:-aarch64-linux-gnu-}"

require_tool() {
    tool="$1"
    resolved="$(command -v "$tool" 2>/dev/null || true)"
    if [ -z "$resolved" ] || [ ! -x "$resolved" ]; then
        printf 'missing executable tool: %s\n' "$tool" >&2
        exit 1
    fi
}

# shellcheck disable=SC1091
. "$SCRIPT_DIR/kernel-sources.env"

require_tool git
require_tool make
require_tool flex
require_tool bison
require_tool perl
require_tool "${ARM64_CROSS_COMPILE}gcc"

SRC="$WORK_DIR/src/linux-rpi-arm64"
mkdir -p "$WORK_DIR/src" "$BOOTFS_DIR/kernel/arm64" "$BOOTFS_DIR/rpi/broadcom" "$BOOTFS_DIR/rpi/overlays"

if [ ! -d "$SRC/.git" ]; then
    if [ -n "$RPI_KERNEL_REF" ]; then
        git clone --depth=1 --branch "$RPI_KERNEL_REF" "$RPI_KERNEL_REPO" "$SRC"
    else
        git clone --depth=1 "$RPI_KERNEL_REPO" "$SRC"
    fi
else
    git -C "$SRC" fetch --depth=1 origin
    if [ -n "$RPI_KERNEL_REF" ]; then
        git -C "$SRC" checkout -q "$RPI_KERNEL_REF"
        git -C "$SRC" reset --hard "origin/$RPI_KERNEL_REF"
    fi
fi

sh "$SCRIPT_DIR/install-unlim8ted-kernel-feature.sh" "$SRC"

make -C "$SRC" ARCH=arm64 CROSS_COMPILE="$ARM64_CROSS_COMPILE" bcm2711_defconfig
sh "$SRC/scripts/kconfig/merge_config.sh" -m "$SRC/.config" "$SCRIPT_DIR/configs/arm64-cm4.fragment"
make -C "$SRC" ARCH=arm64 CROSS_COMPILE="$ARM64_CROSS_COMPILE" olddefconfig
make -C "$SRC" -j"$JOBS" ARCH=arm64 CROSS_COMPILE="$ARM64_CROSS_COMPILE" Image modules dtbs
make -C "$SRC" -j"$JOBS" ARCH=arm64 CROSS_COMPILE="$ARM64_CROSS_COMPILE" INSTALL_MOD_PATH="$ROOTFS_DIR" modules_install

cp "$SRC/arch/arm64/boot/Image" "$BOOTFS_DIR/kernel/arm64/Image"
cp "$SCRIPT_DIR/initramfs/initramfs-unlim8ted.img" "$BOOTFS_DIR/kernel/arm64/initramfs-unlim8ted.img"
cp "$SRC/arch/arm64/boot/dts/broadcom/"*.dtb "$BOOTFS_DIR/rpi/broadcom/"
cp "$SRC/arch/arm64/boot/dts/overlays/"*.dtb* "$BOOTFS_DIR/rpi/overlays/"
cp "$SRC/arch/arm64/boot/dts/overlays/README" "$BOOTFS_DIR/rpi/overlays/README"

printf '[unlim8ted] built CM4 arm64 kernel\n'
