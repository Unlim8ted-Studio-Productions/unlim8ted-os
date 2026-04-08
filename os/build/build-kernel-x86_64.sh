#!/bin/sh
set -eu

PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
OS_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
ROOTFS_DIR="${ROOTFS_DIR:-$OS_DIR/rootfs}"
BOOTFS_DIR="${BOOTFS_DIR:-$OS_DIR/bootfs}"
WORK_DIR="${WORK_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/unlim8ted-kernel-build}"
JOBS="${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)}"

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
require_tool gcc
require_tool flex
require_tool bison
require_tool perl

SRC="$WORK_DIR/src/linux-x86_64"
mkdir -p "$WORK_DIR/src" "$BOOTFS_DIR/kernel/x86_64"

if [ ! -d "$SRC/.git" ]; then
    if [ -n "$X86_KERNEL_REF" ]; then
        git clone --depth=1 --branch "$X86_KERNEL_REF" "$X86_KERNEL_REPO" "$SRC"
    else
        git clone --depth=1 "$X86_KERNEL_REPO" "$SRC"
    fi
else
    git -C "$SRC" fetch --depth=1 origin
    if [ -n "$X86_KERNEL_REF" ]; then
        git -C "$SRC" checkout -q "$X86_KERNEL_REF"
        git -C "$SRC" reset --hard "origin/$X86_KERNEL_REF"
    fi
fi

sh "$SCRIPT_DIR/install-unlim8ted-kernel-feature.sh" "$SRC"

make -C "$SRC" ARCH=x86_64 defconfig
sh "$SRC/scripts/kconfig/merge_config.sh" -m "$SRC/.config" "$SCRIPT_DIR/configs/x86_64-generic.fragment"
make -C "$SRC" ARCH=x86_64 olddefconfig
make -C "$SRC" -j"$JOBS" ARCH=x86_64 bzImage modules
make -C "$SRC" -j"$JOBS" ARCH=x86_64 INSTALL_MOD_PATH="$ROOTFS_DIR" modules_install

cp "$SRC/arch/x86/boot/bzImage" "$BOOTFS_DIR/kernel/x86_64/vmlinuz-unlim8ted"
cp "$SCRIPT_DIR/initramfs/initramfs-unlim8ted.img" "$BOOTFS_DIR/kernel/x86_64/initramfs-unlim8ted.img"

printf '[unlim8ted] built x86_64 kernel\n'
