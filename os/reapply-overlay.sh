#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
OVERLAY_DIR=${UNLIM8TED_OVERLAY_DIR:-$SCRIPT_DIR/overlay}
MOUNT_ROOT=${UNLIM8TED_BUILD_DIR:-$SCRIPT_DIR/build/work}/mount-cm4-overlay

require_command() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "Missing required command: $1" >&2
        exit 1
    }
}

require_linux_host() {
    [ "$(uname -s)" = "Linux" ] || {
        echo "Run this script from Linux or WSL." >&2
        exit 1
    }
}

find_partition_by_fstype() {
    block_device=$1
    fstype=$2
    lsblk -rnpo NAME,FSTYPE "$block_device" | awk -v want="$fstype" -v dev="$block_device" '$2 == want && $1 != dev { print $1; exit }'
}

find_partition_by_label() {
    block_device=$1
    label=$2
    lsblk -rnpo NAME,LABEL,PARTLABEL "$block_device" | awk -v want="$label" '$2 == want || $3 == want { print $1; exit }'
}

find_root_partition() {
    block_device=$1
    for fstype in ext4 xfs btrfs; do
        partition=$(find_partition_by_fstype "$block_device" "$fstype" || true)
        if [ -n "$partition" ]; then
            printf '%s\n' "$partition"
            return
        fi
    done
    for label in root rootfs ROOT ROOTFS; do
        partition=$(find_partition_by_label "$block_device" "$label" || true)
        if [ -n "$partition" ]; then
            printf '%s\n' "$partition"
            return
        fi
    done
    lsblk -lnpo NAME "$block_device" 2>/dev/null | awk -v dev="$block_device" '$1 != dev { last=$1 } END { if (last) print last }'
}

find_boot_partition() {
    block_device=$1
    for fstype in vfat fat fat32; do
        partition=$(find_partition_by_fstype "$block_device" "$fstype" || true)
        if [ -n "$partition" ]; then
            printf '%s\n' "$partition"
            return
        fi
    done
    for label in EFI EFI-SYSTEM boot BOOT bootfs; do
        partition=$(find_partition_by_label "$block_device" "$label" || true)
        if [ -n "$partition" ]; then
            printf '%s\n' "$partition"
            return
        fi
    done
}

unmount_device_tree() {
    block_device=$1
    {
        findmnt -rn -S "$block_device" -o TARGET 2>/dev/null || true
        lsblk -rnpo NAME,MOUNTPOINTS "$block_device" 2>/dev/null | awk 'NF > 1 { for (i = 2; i <= NF; i++) print $i }' || true
    } | awk 'NF && !seen[$0]++' | while IFS= read -r mounted_at; do
        sudo umount "$mounted_at" 2>/dev/null || true
    done
}

device=${1:-}
case "$device" in
    /dev/*) ;;
    *)
        echo "Usage: sh os/reapply-overlay.sh /dev/sdX" >&2
        exit 1
        ;;
esac

require_linux_host
for cmd in awk findmnt lsblk mkdir mount rsync sudo umount; do
    require_command "$cmd"
done
[ -d "$OVERLAY_DIR" ] || {
    echo "Overlay directory not found: $OVERLAY_DIR" >&2
    exit 1
}

root_partition=$(find_root_partition "$device")
boot_partition=$(find_boot_partition "$device" || true)
[ -n "$root_partition" ] || {
    echo "Could not find root partition on $device" >&2
    exit 1
}

root_mount=$MOUNT_ROOT/root
boot_mount=$MOUNT_ROOT/boot

cleanup() {
    set +e
    if mountpoint -q "$root_mount/home/unlim8ted"; then
        sudo umount "$root_mount/home/unlim8ted"
    fi
    if [ -n "${boot_partition:-}" ] && mountpoint -q "$boot_mount"; then
        sudo umount "$boot_mount"
    fi
    if mountpoint -q "$root_mount"; then
        sudo umount "$root_mount"
    fi
    sudo rm -rf "$MOUNT_ROOT"
}
trap cleanup EXIT INT TERM

unmount_device_tree "$device"
sudo rm -rf "$MOUNT_ROOT"
sudo mkdir -p "$root_mount"
sudo mount "$root_partition" "$root_mount"

if [ -n "$boot_partition" ]; then
    sudo mkdir -p "$boot_mount"
    sudo mount "$boot_partition" "$boot_mount"
fi

sudo rsync -a --exclude '/boot' "$OVERLAY_DIR/" "$root_mount/"
if [ -d "$OVERLAY_DIR/boot" ] && [ -n "$boot_partition" ] && [ -d "$boot_mount" ]; then
    sudo rsync -rt --no-owner --no-group --no-perms "$OVERLAY_DIR/boot/" "$boot_mount/"
fi

# Remove stale state from earlier provisioning attempts so the updated
# first-boot flow can run with the current repo behavior.
sudo rm -f "$root_mount/etc/initramfs-tools/update-initramfs.conf"
sudo rm -f "$root_mount/var/lib/unlim8ted/packages-installed"
sudo mkdir -p "$root_mount/etc/systemd/system/multi-user.target.wants"
sudo rm -f "$root_mount/etc/systemd/system/multi-user.target.wants/unlim8ted.service"
sudo ln -sfn /etc/systemd/system/unlim8ted-firstboot-install.service \
    "$root_mount/etc/systemd/system/multi-user.target.wants/unlim8ted-firstboot-install.service"

echo "Overlay reapplied to $device"
