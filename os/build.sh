#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

# Shared base-image customization settings for Unlim8ted OS.

UNLIM8TED_OS_DIR="${UNLIM8TED_OS_DIR:-$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)}"
case "$UNLIM8TED_OS_DIR" in
    /mnt/*)
        UNLIM8TED_DEFAULT_WORK_DIR="${HOME:-/tmp}/.cache/unlim8ted-os-build"
        ;;
    *)
        UNLIM8TED_DEFAULT_WORK_DIR="$UNLIM8TED_OS_DIR/build"
        ;;
esac

UNLIM8TED_WORK_DIR="${UNLIM8TED_WORK_DIR:-$UNLIM8TED_DEFAULT_WORK_DIR}"
UNLIM8TED_ARTIFACT_DIR="${UNLIM8TED_ARTIFACT_DIR:-$UNLIM8TED_OS_DIR/build}"
UNLIM8TED_OVERLAY_DIR="${UNLIM8TED_OVERLAY_DIR:-$UNLIM8TED_OS_DIR/overlay}"
UNLIM8TED_BASE_IMAGE_DIR="${UNLIM8TED_BASE_IMAGE_DIR:-$UNLIM8TED_WORK_DIR/base-images}"
UNLIM8TED_BUILD_DIR="${UNLIM8TED_BUILD_DIR:-$UNLIM8TED_WORK_DIR/work}"

UNLIM8TED_CM4_IMAGE_URL="${UNLIM8TED_CM4_IMAGE_URL:-https://downloads.raspberrypi.org/raspios_lite_arm64_latest}"
UNLIM8TED_X86_64_IMAGE_URL="${UNLIM8TED_X86_64_IMAGE_URL:-https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.raw}"

UNLIM8TED_CM4_ARCHIVE_NAME="${UNLIM8TED_CM4_ARCHIVE_NAME:-raspios_lite_arm64_latest.img.xz}"
UNLIM8TED_X86_64_ARCHIVE_NAME="${UNLIM8TED_X86_64_ARCHIVE_NAME:-debian-12-generic-amd64.raw}"

UNLIM8TED_CM4_PACKAGES="${UNLIM8TED_CM4_PACKAGES:-python3 chromium libcamera-apps bluez wpasupplicant xserver-xorg xinit x11-xserver-utils xserver-xorg-input-libinput keyboard-configuration usbutils openbox mesa-utils dbus-x11 fonts-dejavu-core plymouth plymouth-themes}"
UNLIM8TED_X86_64_PACKAGES="${UNLIM8TED_X86_64_PACKAGES:-python3 chromium bluez wpasupplicant xorg xinit x11-xserver-utils openbox mesa-utils dbus-x11 fonts-dejavu-core xterm xserver-xorg-video-qxl xserver-xorg-input-libinput plymouth plymouth-themes}"

UNLIM8TED_IMAGE_GROW_MB="${UNLIM8TED_IMAGE_GROW_MB:-0}"
UNLIM8TED_CM4_IMAGE_GROW_MB="${UNLIM8TED_CM4_IMAGE_GROW_MB:-12288}"
UNLIM8TED_CM4_ROOT_SIZE_GIB="${UNLIM8TED_CM4_ROOT_SIZE_GIB:-32}"
UNLIM8TED_CM4_BOOT_SIZE_MIB="${UNLIM8TED_CM4_BOOT_SIZE_MIB:-512}"
UNLIM8TED_CM4_ROOT_SIZE_MIB="${UNLIM8TED_CM4_ROOT_SIZE_MIB:-9728}"


sanitize_path() {
    original_path=${PATH-}
    safe_path=""
    changed=0

    OLD_IFS=${IFS}
    IFS=:
    set -f
    for entry in $original_path; do
        case "$entry" in
            *[![:print:]]* | *[[:space:]]* | "")
                changed=1
                continue
                ;;
        esac

        if [ -z "$safe_path" ]; then
            safe_path=$entry
        else
            safe_path=$safe_path:$entry
        fi
    done
    set +f
    IFS=${OLD_IFS}

    if [ -n "$safe_path" ]; then
        PATH=$safe_path
        export PATH
    fi

    if [ "$changed" -eq 1 ]; then
        echo "Sanitized PATH by dropping entries with whitespace or empty segments." >&2
    fi
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "Missing required command: $1" >&2
        exit 1
    }
}

partition_number() {
    partition=$1
    number=$(lsblk -no PARTN "$partition" 2>/dev/null | awk 'NF { print; exit }')
    if [ -n "$number" ]; then
        printf '%s\n' "$number"
        return
    fi
    printf '%s\n' "$partition" | sed 's|.*[^0-9]\([0-9][0-9]*\)$|\1|'
}

require_linux_host() {
    host_kernel=$(uname -s)
    if [ "$host_kernel" != "Linux" ]; then
        echo "These build scripts must run from Linux or WSL, not directly from Windows PowerShell." >&2
        exit 1
    fi
}

ensure_prerequisites() {
    require_linux_host

    for cmd in awk blkid cp curl dd e2fsck find grep install ln losetup lsblk mkdir mount mountpoint parted resize2fs rsync sed sudo sync tar tee truncate umount unzip xz; do
        require_command "$cmd"
    done

    mkdir -p "$UNLIM8TED_WORK_DIR" "$UNLIM8TED_ARTIFACT_DIR" "$UNLIM8TED_BASE_IMAGE_DIR" "$UNLIM8TED_BUILD_DIR"
}

download_file() {
    url=$1
    output=$2
    temp_output=$output.partial

    if [ -f "$output" ]; then
        return
    fi

    rm -f "$temp_output"
    curl -L --fail --progress-bar -o "$temp_output" "$url"
    mv "$temp_output" "$output"
}

resolve_image_path_from_archive() {
    archive_path=$1
    extract_dir=$2

    case "$archive_path" in
        *.zip)
            image_name=$(unzip -Z -1 "$archive_path" | grep '\.img$' | head -n 1 || true)
            if [ -z "$image_name" ]; then
                echo "Could not find an .img inside $archive_path" >&2
                exit 1
            fi
            image_path=$extract_dir/$image_name
            if [ ! -f "$image_path" ]; then
                mkdir -p "$extract_dir"
                unzip -o "$archive_path" -d "$extract_dir" >/dev/null
                rm -f "$archive_path"
            fi
            printf '%s\n' "$image_path"
            ;;
        *.img.xz | *.raw.xz)
            image_name=$(basename "$archive_path" .xz)
            image_path=$extract_dir/$image_name
            if [ ! -f "$image_path" ]; then
                mkdir -p "$extract_dir"
                xz -dc "$archive_path" > "$image_path"
                rm -f "$archive_path"
            fi
            printf '%s\n' "$image_path"
            ;;
        *.img | *.raw)
            printf '%s\n' "$archive_path"
            ;;
        *)
            echo "Unsupported base image format: $archive_path" >&2
            exit 1
            ;;
    esac
}

get_base_image() {
    target_name=$1
    image_url=$2
    archive_name=$3

    archive_path=$UNLIM8TED_BASE_IMAGE_DIR/$archive_name
    extracted_dir=$UNLIM8TED_BASE_IMAGE_DIR/$target_name
    extracted_image=$(find "$extracted_dir" -maxdepth 1 -type f \( -name "*.img" -o -name "*.raw" \) 2>/dev/null | head -n 1 || true)

    if [ -n "$extracted_image" ] && [ -f "$extracted_image" ]; then
        printf '%s\n' "$extracted_image"
        return
    fi

    download_file "$image_url" "$archive_path"
    resolve_image_path_from_archive "$archive_path" "$extracted_dir"
}

copy_base_image() {
    source_image=$1
    destination_image=$2

    install -d "$(dirname "$destination_image")"
    cp "$source_image" "$destination_image"
}

grow_image_if_needed() {
    image_path=$1
    grow_mb=$2

    if [ "$grow_mb" -le 0 ] 2>/dev/null; then
        return
    fi

    truncate -s +"${grow_mb}M" "$image_path"
}

attach_loop_device() {
    image_path=$1
    sudo losetup -Pf --show "$image_path"
}

detach_loop_device() {
    loop_device=$1
    sudo losetup -d "$loop_device"
}

unmount_block_device_tree() {
    block_device=$1

    {
        findmnt -rn -S "$block_device" -o TARGET 2>/dev/null || true
        lsblk -rnpo MOUNTPOINTS "$block_device" | awk 'NF { print }' || true
        for partition in "${block_device}"p* "${block_device}"[0-9]*; do
            if [ -b "$partition" ]; then
                findmnt -rn -S "$partition" -o TARGET 2>/dev/null || true
                lsblk -rnpo MOUNTPOINTS "$partition" | awk 'NF { print }' || true
            fi
        done
    } | awk 'NF && !seen[$0]++' | while IFS= read -r mounted_at; do
        [ -n "$mounted_at" ] || continue
        sudo umount "$mounted_at" 2>/dev/null || true
    done

    sudo umount "$block_device" 2>/dev/null || true
    for partition in "${block_device}"p* "${block_device}"[0-9]*; do
        if [ -b "$partition" ]; then
            sudo umount "$partition" 2>/dev/null || true
        fi
    done
}

find_partition_by_fstype() {
    loop_device=$1
    fstype=$2

    if [ -z "$loop_device" ]; then
        echo "find_partition_by_fstype called without a loop device" >&2
        exit 1
    fi

    result=$(lsblk -rnpo NAME,FSTYPE "$loop_device" | awk -v want="$fstype" -v dev="$loop_device" '$2 == want && $1 != dev { print $1; exit }')
    if [ -n "$result" ]; then
        printf '%s\n' "$result"
        return
    fi

    for partition in "${loop_device}"p* "${loop_device}"[0-9]*; do
        if [ ! -b "$partition" ]; then
            continue
        fi
        partition_fstype=$(blkid -o value -s TYPE "$partition" 2>/dev/null || true)
        if [ "$partition_fstype" = "$fstype" ]; then
            printf '%s\n' "$partition"
            return
        fi
    done
}

find_partition_by_label() {
    loop_device=$1
    label=$2

    result=$(lsblk -rnpo NAME,LABEL,PARTLABEL "$loop_device" | awk -v want="$label" '$2 == want || $3 == want { print $1; exit }')
    if [ -n "$result" ]; then
        printf '%s\n' "$result"
        return
    fi

    for partition in "${loop_device}"p* "${loop_device}"[0-9]*; do
        if [ ! -b "$partition" ]; then
            continue
        fi
        part_label=$(blkid -o value -s PARTLABEL "$partition" 2>/dev/null || true)
        fs_label=$(blkid -o value -s LABEL "$partition" 2>/dev/null || true)
        if [ "$part_label" = "$label" ] || [ "$fs_label" = "$label" ]; then
            printf '%s\n' "$partition"
            return
        fi
    done
}

find_root_partition() {
    loop_device=$1

    if [ -n "${UNLIM8TED_PARTITION_DEVICE:-}" ] && [ "$loop_device" = "$UNLIM8TED_PARTITION_DEVICE" ]; then
        if [ -n "${UNLIM8TED_ROOT_PART_OVERRIDE:-}" ]; then
            printf '%s\n' "$UNLIM8TED_ROOT_PART_OVERRIDE"
            return
        fi
    fi

    for fstype in ext4 xfs btrfs; do
        partition=$(find_partition_by_fstype "$loop_device" "$fstype" || true)
        if [ -n "$partition" ]; then
            printf '%s\n' "$partition"
            return
        fi
    done

    for label in root rootfs ROOT ROOTFS; do
        partition=$(find_partition_by_label "$loop_device" "$label" || true)
        if [ -n "$partition" ]; then
            printf '%s\n' "$partition"
            return
        fi
    done
}

find_boot_partition() {
    loop_device=$1

    if [ -n "${UNLIM8TED_PARTITION_DEVICE:-}" ] && [ "$loop_device" = "$UNLIM8TED_PARTITION_DEVICE" ]; then
        if [ -n "${UNLIM8TED_BOOT_PART_OVERRIDE:-}" ]; then
            printf '%s\n' "$UNLIM8TED_BOOT_PART_OVERRIDE"
            return
        fi
    fi

    for fstype in vfat fat fat32; do
        partition=$(find_partition_by_fstype "$loop_device" "$fstype" || true)
        if [ -n "$partition" ]; then
            printf '%s\n' "$partition"
            return
        fi
    done

    for label in EFI EFI-SYSTEM boot BOOT; do
        partition=$(find_partition_by_label "$loop_device" "$label" || true)
        if [ -n "$partition" ]; then
            printf '%s\n' "$partition"
            return
        fi
    done
}

find_storage_partition() {
    loop_device=$1
    if [ -n "${UNLIM8TED_PARTITION_DEVICE:-}" ] && [ "$loop_device" = "$UNLIM8TED_PARTITION_DEVICE" ]; then
        if [ -n "${UNLIM8TED_STORAGE_PART_OVERRIDE:-}" ]; then
            printf '%s\n' "$UNLIM8TED_STORAGE_PART_OVERRIDE"
            return
        fi
    fi
    partition=$(find_partition_by_label "$loop_device" storage || true)
    if [ -n "$partition" ]; then
        printf '%s\n' "$partition"
    fi
}

create_storage_partition_on_device() {
    block_device=$1
    root_size_gib=${2:-}
    force_resize=${3:-0}

    if [ -z "$root_size_gib" ]; then
        root_size_gib=${UNLIM8TED_CM4_ROOT_SIZE_GIB:-32}
    fi

    storage_partition=$(find_storage_partition "$block_device" || true)
    root_end=$(sudo parted -m "$block_device" unit GiB print | awk -F: '/rootfs|ext4/ { value=$3; sub(/GiB$/, "", value); print value; exit }')
    if [ -n "$root_end" ]; then
        root_end_int=${root_end%.*}
        if [ "$force_resize" -ne 1 ] && [ "$root_end_int" -ge "$root_size_gib" ] 2>/dev/null && [ -n "$storage_partition" ]; then
            return
        fi
        if [ "$root_end_int" -gt "$root_size_gib" ] 2>/dev/null && [ -z "$storage_partition" ]; then
            echo "Storage partition is missing, but rootfs already extends beyond ${root_size_gib}GiB." >&2
            echo "Refusing to shrink rootfs automatically. Reflash the device to create a separated storage partition." >&2
            exit 1
        fi
    fi

    root_partition=$(find_root_partition "$block_device")
    if [ -z "$root_partition" ]; then
        echo "Cannot create storage partition without a root partition on $block_device" >&2
        exit 1
    fi

    root_part_num=$(partition_number "$root_partition")
    if [ -n "$storage_partition" ]; then
        storage_part_num=$(partition_number "$storage_partition")
        sudo umount "$storage_partition" 2>/dev/null || true
        sudo parted -s "$block_device" rm "$storage_part_num"
        sudo partprobe "$block_device" 2>/dev/null || true
        sleep 2
    fi

    sudo parted -s "$block_device" resizepart "$root_part_num" "${root_size_gib}GiB"
    sudo partprobe "$block_device" 2>/dev/null || true
    sleep 2
    root_partition=$(find_root_partition "$block_device")
    if [ "$(blkid -o value -s TYPE "$root_partition" 2>/dev/null || true)" = "ext4" ]; then
        sudo e2fsck -pf "$root_partition" >/dev/null || true
        sudo resize2fs "$root_partition" >/dev/null
    fi

    sudo parted -s "$block_device" mkpart primary ext4 "${root_size_gib}GiB" 100%
    sudo partprobe "$block_device" 2>/dev/null || true
    sleep 2

    root_partition=$(find_root_partition "$block_device")
    if [ "$(blkid -o value -s TYPE "$root_partition" 2>/dev/null || true)" = "ext4" ]; then
        sudo e2fsck -pf "$root_partition" >/dev/null || true
        sudo resize2fs "$root_partition" >/dev/null
    fi

    storage_partition=$(find_storage_partition "$block_device" || true)
    if [ -z "$storage_partition" ]; then
        storage_partition=$(lsblk -rnpo NAME "$block_device" | tail -n 1)
    fi
    sudo mkfs.ext4 -F -L storage "$storage_partition"
}

create_partition_layout_on_device() {
    block_device=$1
    boot_size_mib=$2
    root_size_mib=$3

    case "$boot_size_mib" in
        *[!0-9]* | "")
            echo "boot size must be a positive integer MiB." >&2
            exit 1
            ;;
    esac
    case "$root_size_mib" in
        *[!0-9]* | "")
            echo "root size must be a positive integer MiB." >&2
            exit 1
            ;;
    esac
    if [ "$boot_size_mib" -lt 128 ]; then
        echo "boot size looks too small: ${boot_size_mib}MiB" >&2
        exit 1
    fi
    if [ "$root_size_mib" -lt 2048 ]; then
        echo "root size looks too small: ${root_size_mib}MiB" >&2
        exit 1
    fi

    unmount_block_device_tree "$block_device"
    sudo parted -s "$block_device" mklabel msdos
    sudo parted -s "$block_device" mkpart primary fat32 1MiB "${boot_size_mib}MiB"
    sudo parted -s "$block_device" mkpart primary ext4 "${boot_size_mib}MiB" "$((boot_size_mib + root_size_mib))MiB"
    sudo parted -s "$block_device" mkpart primary ext4 "$((boot_size_mib + root_size_mib))MiB" 100%
    sudo partprobe "$block_device" 2>/dev/null || true
    sleep 3

    boot_part=$(lsblk -rnpo NAME "$block_device" | awk 'NR==2 { print; exit }')
    root_part=$(lsblk -rnpo NAME "$block_device" | awk 'NR==3 { print; exit }')
    storage_part=$(lsblk -rnpo NAME "$block_device" | awk 'NR==4 { print; exit }')

    if [ -z "$boot_part" ] || [ -z "$root_part" ] || [ -z "$storage_part" ]; then
        echo "Could not resolve new partition paths on $block_device" >&2
        lsblk -f "$block_device" >&2 || true
        exit 1
    fi

    sudo mkfs.vfat -F 32 -n bootfs "$boot_part"
    sudo mkfs.ext4 -F -L rootfs "$root_part"
    sudo mkfs.ext4 -F -L storage "$storage_part"
}

device_has_base_os() {
    block_device=$1

    [ -n "$(find_partition_by_label "$block_device" bootfs || true)" ] || return 1
    [ -n "$(find_partition_by_label "$block_device" rootfs || true)" ] || return 1
    return 0
}

grow_root_partition_if_needed() {
    image_path=$1
    loop_device=$2
    grow_mb=$3

    if [ "$grow_mb" -le 0 ] 2>/dev/null; then
        printf '%s\n' "$loop_device"
        return
    fi

    root_partition=$(find_root_partition "$loop_device")
    if [ -z "$root_partition" ]; then
        echo "Partition layout for $loop_device:" >&2
        lsblk -f "$loop_device" >&2 || true
        blkid "${loop_device}"p* "${loop_device}"[0-9]* >&2 || true
        echo "Could not locate a writable root partition in $image_path" >&2
        exit 1
    fi

    part_num=$(partition_number "$root_partition")
    sudo parted -s "$image_path" resizepart "$part_num" 100%
    sudo losetup -d "$loop_device"
    loop_device=$(sudo losetup -Pf --show "$image_path")
    root_partition=$(find_root_partition "$loop_device")
    root_fstype=$(blkid -o value -s TYPE "$root_partition" 2>/dev/null || true)
    if [ "$root_fstype" = "ext4" ]; then
        sudo e2fsck -pf "$root_partition" >/dev/null || true
        sudo resize2fs "$root_partition" >/dev/null
    fi
    printf '%s\n' "$loop_device"
}

grow_root_partition_to_full_device() {
    block_device=$1

    root_partition=$(find_root_partition "$block_device")
    if [ -z "$root_partition" ]; then
        echo "Partition layout for $block_device:" >&2
        lsblk -f "$block_device" >&2 || true
        blkid "${block_device}"p* "${block_device}"[0-9]* >&2 || true
        echo "Could not locate a writable root partition on $block_device" >&2
        exit 1
    fi

    part_num=$(partition_number "$root_partition")
    sudo parted -s "$block_device" resizepart "$part_num" 100%
    sudo partprobe "$block_device" 2>/dev/null || true
    sleep 2
    root_partition=$(find_root_partition "$block_device")
    root_fstype=$(blkid -o value -s TYPE "$root_partition" 2>/dev/null || true)
    if [ "$root_fstype" = "ext4" ]; then
        sudo e2fsck -pf "$root_partition" >/dev/null || true
        sudo resize2fs "$root_partition" >/dev/null
    fi
}

mount_image_partitions() {
    loop_device=$1
    mount_root=$2

    root_partition=$(find_root_partition "$loop_device")
    boot_partition=$(find_boot_partition "$loop_device" || true)
    storage_partition=$(find_storage_partition "$loop_device" || true)

    if [ -z "$root_partition" ]; then
        echo "Partition layout for $loop_device:" >&2
        lsblk -f "$loop_device" >&2 || true
        blkid "${loop_device}"p* "${loop_device}"[0-9]* >&2 || true
        echo "Could not find a writable root partition on $loop_device" >&2
        exit 1
    fi

    root_mount=$mount_root/root
    boot_mount=$mount_root/boot
    sudo mkdir -p "$root_mount"
    sudo mount "$root_partition" "$root_mount" || {
        echo "Failed to mount root partition $root_partition at $root_mount" >&2
        exit 1
    }
    mountpoint -q "$root_mount" || {
        echo "Root mount did not become active at $root_mount" >&2
        exit 1
    }

    if [ -n "$boot_partition" ]; then
        sudo mkdir -p "$boot_mount"
        sudo mount "$boot_partition" "$boot_mount" || {
            echo "Failed to mount boot partition $boot_partition at $boot_mount" >&2
            exit 1
        }
        mountpoint -q "$boot_mount" || {
            echo "Boot mount did not become active at $boot_mount" >&2
            exit 1
        }
    fi

    if [ -n "$storage_partition" ]; then
        storage_mount=$root_mount/home/unlim8ted
        sudo mkdir -p "$storage_mount"
        sudo mount "$storage_partition" "$storage_mount" || {
            echo "Failed to mount storage partition $storage_partition at $storage_mount" >&2
            exit 1
        }
        sudo mkdir -p "$storage_mount/Files" "$storage_mount/Downloads" "$storage_mount/Pictures/Captures" "$storage_mount/Videos" "$storage_mount/Music"
    fi

    printf '%s\n%s\n' "$root_mount" "$boot_mount"
}

unmount_image_partitions() {
    root_mount=$1
    boot_mount=$2

    if mountpoint -q "$root_mount/home/unlim8ted"; then
        sudo umount "$root_mount/home/unlim8ted"
    fi
    if [ -n "$boot_mount" ] && mountpoint -q "$boot_mount"; then
        sudo umount "$boot_mount"
    fi
    if mountpoint -q "$root_mount"; then
        sudo umount "$root_mount"
    fi
}

bind_mount_chroot_support() {
    root_mount=$1

    for dir in dev proc sys run; do
        sudo mkdir -p "$root_mount/$dir"
        sudo mount --bind "/$dir" "$root_mount/$dir"
    done
}

bind_mount_apt_cache() {
    root_mount=$1
    target_name=$2

    apt_cache_dir="$UNLIM8TED_BUILD_DIR/apt-cache-$target_name"
    mkdir -p "$apt_cache_dir/partial"
    sudo mkdir -p "$root_mount/var/cache/apt/archives"
    sudo mount --bind "$apt_cache_dir" "$root_mount/var/cache/apt/archives"
}

unbind_mount_apt_cache() {
    root_mount=$1

    if mountpoint -q "$root_mount/var/cache/apt/archives"; then
        sudo umount "$root_mount/var/cache/apt/archives"
    fi
}

debug_disk_space() {
    root_mount=$1
    target_name=$2

    apt_cache_dir="$UNLIM8TED_BUILD_DIR/apt-cache-$target_name"

    echo "Disk debug for target '$target_name':" >&2
    echo "- root mount: $root_mount" >&2
    echo "- host build dir: $UNLIM8TED_BUILD_DIR" >&2
    echo "- host apt cache: $apt_cache_dir" >&2

    echo "Filesystem usage:" >&2
    df -h "$root_mount" "$root_mount/var" "$root_mount/var/cache/apt/archives" "$UNLIM8TED_BUILD_DIR" "$apt_cache_dir" 2>/dev/null >&2 || true

    echo "Inode usage:" >&2
    df -ih "$root_mount" "$root_mount/var" "$root_mount/var/cache/apt/archives" "$UNLIM8TED_BUILD_DIR" "$apt_cache_dir" 2>/dev/null >&2 || true

    echo "Target root largest directories:" >&2
    sudo du -xhd1 "$root_mount" 2>/dev/null | sort -h | tail -n 12 >&2 || true

    echo "Target /var largest directories:" >&2
    sudo du -xhd1 "$root_mount/var" 2>/dev/null | sort -h | tail -n 12 >&2 || true

    echo "Host build directory largest entries:" >&2
    du -hd1 "$UNLIM8TED_BUILD_DIR" 2>/dev/null | sort -h | tail -n 12 >&2 || true

    echo "Host apt cache largest entries:" >&2
    du -hd1 "$apt_cache_dir" 2>/dev/null | sort -h | tail -n 12 >&2 || true
}

unbind_mount_chroot_support() {
    root_mount=$1

    for dir in run sys proc dev; do
        if mountpoint -q "$root_mount/$dir"; then
            sudo umount "$root_mount/$dir"
        fi
    done
}

copy_qemu_static_if_needed() {
    target_arch=$1
    root_mount=$2

    host_arch=$(uname -m)
    qemu_binary=

    case "$target_arch:$host_arch" in
        arm64:aarch64 | x86_64:x86_64)
            return
            ;;
        arm64:*)
            qemu_binary=$(command -v qemu-aarch64-static || true)
            ;;
        *)
            echo "Unsupported host/target combination: host=$host_arch target=$target_arch" >&2
            exit 1
            ;;
    esac

    if [ -z "$qemu_binary" ]; then
        echo "Missing qemu-aarch64-static for arm64 image customization on a non-arm64 host." >&2
        exit 1
    fi

    sudo install -D "$qemu_binary" "$root_mount/usr/bin/qemu-aarch64-static"
}

remove_qemu_static_if_present() {
    root_mount=$1

    if [ -f "$root_mount/usr/bin/qemu-aarch64-static" ]; then
        sudo rm -f "$root_mount/usr/bin/qemu-aarch64-static"
    fi
}

run_in_chroot() {
    root_mount=$1
    target_arch=$2
    command_text=$3

    case "$target_arch" in
        arm64)
            if [ -f "$root_mount/usr/bin/qemu-aarch64-static" ]; then
                sudo chroot "$root_mount" /usr/bin/qemu-aarch64-static /bin/sh -lc "$command_text"
                return
            fi
            ;;
    esac

    sudo chroot "$root_mount" /bin/sh -lc "$command_text"
}

install_target_packages() {
    root_mount=$1
    target_arch=$2
    package_list=$3
    target_name=$4

    bind_mount_chroot_support "$root_mount"
    bind_mount_apt_cache "$root_mount" "$target_name"
    copy_qemu_static_if_needed "$target_arch" "$root_mount"

    echo "Disk state before apt install:" >&2
    debug_disk_space "$root_mount" "$target_name"

    if ! run_in_chroot "$root_mount" "$target_arch" \
        "export DEBIAN_FRONTEND=noninteractive; dpkg --configure -a || true; apt-get -f install -y || true; apt-get update; apt-get install -y $package_list"; then
        echo "Package install failed. Disk state after apt failure:" >&2
        debug_disk_space "$root_mount" "$target_name"
        echo "If apt reported 'No space left on device', compare the filesystem for root mount and host apt cache above." >&2
        remove_qemu_static_if_present "$root_mount"
        unbind_mount_apt_cache "$root_mount"
        unbind_mount_chroot_support "$root_mount"
        exit 1
    fi

    remove_qemu_static_if_present "$root_mount"
    unbind_mount_apt_cache "$root_mount"
    unbind_mount_chroot_support "$root_mount"
}

estimate_package_install_mib() {
    root_mount=$1
    target_arch=$2
    package_list=$3

    bind_mount_chroot_support "$root_mount"
    copy_qemu_static_if_needed "$target_arch" "$root_mount"

    estimate=$(
        run_in_chroot "$root_mount" "$target_arch" \
            "export LC_ALL=C DEBIAN_FRONTEND=noninteractive; apt-get update >/dev/null; apt-get -s -o Debug::NoLocking=1 install -y $package_list" |
        awk '
            /After this operation/ {
                for (i = 1; i <= NF; i++) {
                    if ($i ~ /^[0-9,.]+$/) {
                        value = $i
                        gsub(/,/, "", value)
                        unit = $(i + 1)
                    }
                }
            }
            END {
                if (value == "") {
                    exit 2
                } else if (unit ~ /^GB/) {
                    printf "%.0f\n", value * 1024
                } else if (unit ~ /^kB/) {
                    printf "%.0f\n", value / 1024
                } else {
                    printf "%.0f\n", value
                }
            }
        '
    )

    remove_qemu_static_if_present "$root_mount"
    unbind_mount_chroot_support "$root_mount"

    case "$estimate" in
        "" | *[!0-9]*)
            echo "Could not estimate apt installed size from: apt-get -s install -y $package_list" >&2
            exit 1
            ;;
    esac

    echo "Apt estimated installed package growth: ${estimate}MiB" >&2
    printf '%s\n' "$estimate"
}

estimate_root_size_gib() {
    root_mount=$1
    target_arch=$2
    package_list=$3

    used_mib=$(df -Pm "$root_mount" | awk 'NR == 2 { print $3 }')
    install_mib=$(estimate_package_install_mib "$root_mount" "$target_arch" "$package_list")
    desired_mib=$((used_mib + install_mib + 5120))
    desired_gib=$(((desired_mib + 1023) / 1024))

    if [ "$desired_gib" -lt 8 ]; then
        desired_gib=8
    fi

    printf '%s\n' "$desired_gib"
}

install_browser_compatibility() {
    root_mount=$1
    target_arch=$2

    bind_mount_chroot_support "$root_mount"
    copy_qemu_static_if_needed "$target_arch" "$root_mount"

    run_in_chroot "$root_mount" "$target_arch" \
        "if command -v chromium >/dev/null 2>&1 && ! command -v chromium-browser >/dev/null 2>&1; then ln -sf /usr/bin/chromium /usr/bin/chromium-browser; fi"

    remove_qemu_static_if_present "$root_mount"
    unbind_mount_chroot_support "$root_mount"
}

apply_overlay() {
    root_mount=$1
    boot_mount=$2

    if [ -d "$UNLIM8TED_OVERLAY_DIR" ]; then
        sudo rsync -a --exclude '/boot' "$UNLIM8TED_OVERLAY_DIR/" "$root_mount/"
    fi

    if [ -d "$UNLIM8TED_OVERLAY_DIR/boot" ] && [ -n "$boot_mount" ] && [ -d "$boot_mount" ]; then
        if [ -d "$UNLIM8TED_OVERLAY_DIR/boot/firmware" ] && [ -d "$boot_mount/firmware" ]; then
            sudo rsync -rt --no-owner --no-group --no-perms "$UNLIM8TED_OVERLAY_DIR/boot/firmware/" "$boot_mount/firmware/"
        else
            sudo rsync -rt --no-owner --no-group --no-perms "$UNLIM8TED_OVERLAY_DIR/boot/" "$boot_mount/"
        fi
    fi
}

configure_plymouth() {
    root_mount=$1
    target_arch=$2

    if [ ! -d "$root_mount/usr/share/plymouth/themes/unlim8ted-eight" ]; then
        return
    fi

    sudo ln -sfn unlim8ted-eight/unlim8ted-eight.plymouth \
        "$root_mount/usr/share/plymouth/themes/default.plymouth"

    bind_mount_chroot_support "$root_mount"
    copy_qemu_static_if_needed "$target_arch" "$root_mount"

    run_in_chroot "$root_mount" "$target_arch" \
        "if command -v plymouth-set-default-theme >/dev/null 2>&1; then plymouth-set-default-theme -R unlim8ted-eight || true; fi"

    remove_qemu_static_if_present "$root_mount"
    unbind_mount_chroot_support "$root_mount"
}

configure_boot_splash() {
    boot_mount=$1
    [ -n "$boot_mount" ] || return

    cmdline_path=
    for candidate in "$boot_mount/cmdline.txt" "$boot_mount/firmware/cmdline.txt"; do
        if [ -f "$candidate" ]; then
            cmdline_path=$candidate
            break
        fi
    done
    [ -n "$cmdline_path" ] || return

    current=$(sudo sed -n '1p' "$cmdline_path")
    next=$current
    for flag in quiet splash plymouth.ignore-serial-consoles logo.nologo vt.global_cursor_default=0; do
        case " $next " in
            *" $flag "*)
                ;;
            *)
                next="$next $flag"
                ;;
        esac
    done
    if [ "$next" != "$current" ]; then
        printf '%s\n' "$next" | sudo tee "$cmdline_path" >/dev/null
    fi
}

setup_storage_mount() {
    root_mount=$1

    sudo mkdir -p "$root_mount/var/lib/unlim8ted" "$root_mount/home/unlim8ted"
    sudo mkdir -p "$root_mount/home/unlim8ted/Files" "$root_mount/home/unlim8ted/Downloads" "$root_mount/home/unlim8ted/Pictures/Captures" "$root_mount/home/unlim8ted/Videos" "$root_mount/home/unlim8ted/Music"

    if grep -q 'LABEL=storage[[:space:]]/home/unlim8ted' "$root_mount/etc/fstab" 2>/dev/null; then
        return
    fi

    cat <<EOF | sudo tee -a "$root_mount/etc/fstab" >/dev/null
LABEL=storage /home/unlim8ted ext4 defaults,nofail,x-systemd.device-timeout=10 0 2
EOF
}

enable_services() {
    root_mount=$1
    target_arch=$2

    bind_mount_chroot_support "$root_mount"
    copy_qemu_static_if_needed "$target_arch" "$root_mount"

    run_in_chroot "$root_mount" "$target_arch" \
        "systemctl enable unlim8ted.service >/dev/null 2>&1 || true"

    remove_qemu_static_if_present "$root_mount"
    unbind_mount_chroot_support "$root_mount"
}

write_build_metadata() {
    target_dir=$1
    image_name=$2
    base_image_url=$3
    package_list=$4

    cat > "$target_dir/README.txt" <<EOF
Unlim8ted OS artifact bundle

Base image:
- $base_image_url

Output:
- $image_name

Customization:
- packages installed with apt: $package_list
- overlay copied from os/overlay/
EOF
}

build_target() {
    target_name=$1
    target_arch=$2
    base_image_url=$3
    archive_name=$4
    package_list=$5
    output_name=$6

    sanitize_path
    ensure_prerequisites

    source_image=$(get_base_image "$target_name" "$base_image_url" "$archive_name")

    if [ -n "${UNLIM8TED_DIRECT_DEVICE:-}" ]; then
        build_target_on_device "$target_name" "$target_arch" "$source_image" "$base_image_url" "$package_list" "$UNLIM8TED_DIRECT_DEVICE"
        return
    fi

    target_dir=$UNLIM8TED_ARTIFACT_DIR/$target_name
    work_target_dir=$UNLIM8TED_BUILD_DIR/artifacts-$target_name
    mount_root=$UNLIM8TED_BUILD_DIR/mount-$target_name
    work_output_image=$work_target_dir/$output_name
    output_image=$target_dir/$output_name
    boot_mount=
    root_mount=
    loop_device=

    sudo rm -rf "$mount_root"
    rm -rf "$target_dir"
    rm -rf "$work_target_dir"
    mkdir -p "$target_dir"
    mkdir -p "$work_target_dir"

    copy_base_image "$source_image" "$work_output_image"
    grow_image_if_needed "$work_output_image" "$UNLIM8TED_IMAGE_GROW_MB"

    cleanup() {
        set +e
        if [ -n "$root_mount" ]; then
            unbind_mount_apt_cache "$root_mount"
            unbind_mount_chroot_support "$root_mount"
        fi
        if [ -n "$root_mount" ]; then
            unmount_image_partitions "$root_mount" "$boot_mount"
        fi
        if [ -n "$loop_device" ]; then
            detach_loop_device "$loop_device"
        fi
        sudo rm -rf "$mount_root"
    }
    trap cleanup EXIT INT TERM

    loop_device=$(attach_loop_device "$work_output_image")
    loop_device=$(grow_root_partition_if_needed "$work_output_image" "$loop_device" "$UNLIM8TED_IMAGE_GROW_MB")

    mounts=$(mount_image_partitions "$loop_device" "$mount_root")
    root_mount=$(printf '%s\n' "$mounts" | sed -n '1p')
    boot_mount=$(printf '%s\n' "$mounts" | sed -n '2p')

    echo "Root filesystem capacity before package install:" >&2
    df -h "$root_mount" >&2 || true

    install_target_packages "$root_mount" "$target_arch" "$package_list" "$target_name"
    install_browser_compatibility "$root_mount" "$target_arch"
    apply_overlay "$root_mount" "$boot_mount"
    configure_boot_splash "$boot_mount"
    configure_plymouth "$root_mount" "$target_arch"
    setup_storage_mount "$root_mount"
    enable_services "$root_mount" "$target_arch"
    unmount_image_partitions "$root_mount" "$boot_mount"
    root_mount=
    boot_mount=
    detach_loop_device "$loop_device"
    loop_device=

    cp "$work_output_image" "$output_image"
    write_build_metadata "$target_dir" "$output_name" "$base_image_url" "$package_list"
}

build_target_on_device() {
    target_name=$1
    target_arch=$2
    source_image=$3
    base_image_url=$4
    package_list=$5
    block_device=$6

    target_dir=$UNLIM8TED_ARTIFACT_DIR/$target_name
    mount_root=$UNLIM8TED_BUILD_DIR/mount-$target_name-direct
    root_mount=
    boot_mount=

    case "$block_device" in
        /dev/*)
            ;;
        *)
            echo "Refusing non-/dev direct target: $block_device" >&2
            exit 1
            ;;
    esac

    if [ ! -b "$block_device" ]; then
        echo "Direct target is not a block device: $block_device" >&2
        exit 1
    fi

    cleanup_direct() {
        set +e
        if [ -n "$root_mount" ]; then
            unbind_mount_apt_cache "$root_mount"
            unbind_mount_chroot_support "$root_mount"
            unmount_image_partitions "$root_mount" "$boot_mount"
        fi
        sudo rm -rf "$mount_root"
    }
    trap cleanup_direct EXIT INT TERM

    sudo rm -rf "$mount_root"
    rm -rf "$target_dir"
    mkdir -p "$target_dir"

    if device_has_base_os "$block_device"; then
        echo "Reusing existing flashed OS on $block_device" >&2
        unmount_block_device_tree "$block_device"
    else
        echo "Writing base image directly to $block_device" >&2
        sudo dd if="$source_image" of="$block_device" bs=16M conv=fsync status=progress
        sync
        sudo partprobe "$block_device" 2>/dev/null || true
        sleep 3
        unmount_block_device_tree "$block_device"
    fi

    mounts=$(mount_image_partitions "$block_device" "$mount_root")
    root_mount=$(printf '%s\n' "$mounts" | sed -n '1p')
    boot_mount=$(printf '%s\n' "$mounts" | sed -n '2p')
    root_size_gib=$(estimate_root_size_gib "$root_mount" "$target_arch" "$package_list")
    echo "Calculated CM4 rootfs size: ${root_size_gib}GiB (installed packages + 5GiB buffer)" >&2
    unmount_image_partitions "$root_mount" "$boot_mount"
    root_mount=
    boot_mount=

    create_storage_partition_on_device "$block_device" "$root_size_gib"
    unmount_block_device_tree "$block_device"

    mounts=$(mount_image_partitions "$block_device" "$mount_root")
    root_mount=$(printf '%s\n' "$mounts" | sed -n '1p')
    boot_mount=$(printf '%s\n' "$mounts" | sed -n '2p')

    echo "Root filesystem capacity before package install:" >&2
    df -h "$root_mount" >&2 || true

    install_target_packages "$root_mount" "$target_arch" "$package_list" "$target_name"
    install_browser_compatibility "$root_mount" "$target_arch"
    apply_overlay "$root_mount" "$boot_mount"
    configure_boot_splash "$boot_mount"
    configure_plymouth "$root_mount" "$target_arch"
    setup_storage_mount "$root_mount"
    enable_services "$root_mount" "$target_arch"

    unmount_image_partitions "$root_mount" "$boot_mount"
    root_mount=
    boot_mount=
    sync

    cat > "$target_dir/README.txt" <<EOF
Unlim8ted OS direct-device build

Base image:
- $base_image_url

Target device:
- $block_device

Customization:
- packages installed with apt: $package_list
- overlay copied from os/overlay/
EOF
}


AUTO_UNMOUNT_CACHE=0
AUTO_UNMOUNT_DIR=
AUTO_UNMOUNT_DEVICE=

cleanup() {
    if [ "$AUTO_UNMOUNT_CACHE" -eq 1 ] && [ -n "$AUTO_UNMOUNT_DIR" ]; then
        echo
        echo "Flushing writes and unmounting external cache: $AUTO_UNMOUNT_DIR" >&2
        sync
        sudo umount "$AUTO_UNMOUNT_DIR" 2>/dev/null || sudo umount "$AUTO_UNMOUNT_DEVICE" 2>/dev/null || true
    fi
}
trap cleanup EXIT INT TERM

usage() {
    cat >&2 <<EOF
Usage:
  bash os/build.sh
  bash os/build.sh image --arch cm4|x86_64 [--direct-device /dev/sdX] [--grow-mb N]
  bash os/build.sh deferred --device /dev/sdX [--boot-size-mib N] [--root-size-mib N | --root-size-gib N]
  bash os/build.sh overlay --device /dev/sdX [--boot-part /dev/sdX1 --root-part /dev/sdX2 --storage-part /dev/sdX3]
  bash os/build.sh hotpatch --device /dev/sdX [--boot-part /dev/sdX1 --root-part /dev/sdX2 --storage-part /dev/sdX3]
  bash os/build.sh repair --device /dev/sdX [--add-mb N | --size-gib N | --no-resize] [--boot-part /dev/sdX1 --root-part /dev/sdX2 --storage-part /dev/sdX3]
  bash os/build.sh continue --device /dev/sdX [--boot-part /dev/sdX1 --root-part /dev/sdX2 --storage-part /dev/sdX3]
  bash os/build.sh list-devices

One comprehensive build entrypoint for:
- full image builds for x86_64 and CM4
- direct CM4 SD/USB builds
- deferred CM4 first-boot package install images
- overlay-only reapply
- runtime hotpatch without package installs
- repair/continue workflows for interrupted CM4 cards

Legacy wrapper names were removed. Use this file for all build flows.
EOF
    exit 1
}

prompt() {
    printf '%s' "$1" >&2
    read -r REPLY
    printf '%s\n' "$REPLY"
}

is_wsl() {
    grep -qi microsoft /proc/version 2>/dev/null
}

show_windows_drive_mounts() {
    if ! is_wsl; then
        return
    fi

    echo
    echo "Windows drive mounts visible to WSL:"
    awk '
        $2 ~ /^\/mnt\/[A-Za-z]$/ {
            drive = toupper(substr($2, 6, 1)) ":"
            printf "  %-3s -> %s\n", drive, $2
        }
    ' /proc/mounts
}

show_windows_volumes() {
    if ! is_wsl || ! command -v powershell.exe >/dev/null 2>&1; then
        return
    fi

    echo
    echo "Windows volumes:"
    powershell.exe -NoProfile -Command 'Get-Volume | Where-Object DriveLetter | Sort-Object DriveLetter | ForEach-Object { "{0}:  {1,-12} {2,-10} {3}" -f $_.DriveLetter, $_.FileSystemLabel, $_.FileSystem, $_.DriveType }' 2>/dev/null | tr -d '\r' || true
}

list_devices() {
    sanitize_path
    require_linux_host
    require_command lsblk
    echo "Linux block devices:"
    lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,PARTLABEL,MODEL,VENDOR,SERIAL,TRAN,MOUNTPOINTS
    show_windows_drive_mounts
    show_windows_volumes
}

require_block_device() {
    device=$1
    case "$device" in
        /dev/*)
            ;;
        *)
            echo "Refusing non-/dev path: $device" >&2
            exit 1
            ;;
    esac
    if [ ! -b "$device" ]; then
        echo "Not a block device: $device" >&2
        exit 1
    fi
}

validate_partition_override() {
    device=$1
    partition=$2
    label=$3

    [ -n "$partition" ] || return 0
    case "$partition" in
        /dev/*)
            ;;
        *)
            echo "Refusing non-/dev $label partition: $partition" >&2
            exit 1
            ;;
    esac
    if [ ! -b "$partition" ]; then
        echo "Not a block device for $label partition: $partition" >&2
        exit 1
    fi

    base=$(lsblk -no PKNAME "$partition" 2>/dev/null | awk 'NF { print; exit }')
    if [ -z "$base" ]; then
        echo "Could not determine base device for $label partition: $partition" >&2
        exit 1
    fi
    if [ "/dev/$base" != "$device" ]; then
        echo "Partition $partition is not part of $device (base: /dev/$base)." >&2
        exit 1
    fi
}

set_partition_overrides() {
    device=$1
    boot_part=$2
    root_part=$3
    storage_part=$4

    validate_partition_override "$device" "$boot_part" "boot"
    validate_partition_override "$device" "$root_part" "rootfs"
    validate_partition_override "$device" "$storage_part" "storage"

    UNLIM8TED_PARTITION_DEVICE=$device
    UNLIM8TED_BOOT_PART_OVERRIDE=${boot_part:-}
    UNLIM8TED_ROOT_PART_OVERRIDE=${root_part:-}
    UNLIM8TED_STORAGE_PART_OVERRIDE=${storage_part:-}
    export UNLIM8TED_PARTITION_DEVICE UNLIM8TED_BOOT_PART_OVERRIDE UNLIM8TED_ROOT_PART_OVERRIDE UNLIM8TED_STORAGE_PART_OVERRIDE
}

confirm_token() {
    token=$1
    message=$2
    echo "$message"
    echo
    echo "Type $token to continue."
    printf 'Confirmation: ' >&2
    read -r confirm
    if [ "$confirm" != "$token" ]; then
        echo "Aborted." >&2
        exit 1
    fi
}

target_values() {
    arch=$1
    case "$arch" in
        cm4 | arm64)
            TARGET_NAME=cm4
            TARGET_ARCH=arm64
            TARGET_URL=$UNLIM8TED_CM4_IMAGE_URL
            TARGET_ARCHIVE=$UNLIM8TED_CM4_ARCHIVE_NAME
            TARGET_PACKAGES=$UNLIM8TED_CM4_PACKAGES
            TARGET_OUTPUT=unlim8ted-cm4.img
            ;;
        x86_64 | amd64)
            TARGET_NAME=x86_64
            TARGET_ARCH=x86_64
            TARGET_URL=$UNLIM8TED_X86_64_IMAGE_URL
            TARGET_ARCHIVE=$UNLIM8TED_X86_64_ARCHIVE_NAME
            TARGET_PACKAGES=$UNLIM8TED_X86_64_PACKAGES
            TARGET_OUTPUT=unlim8ted-x86_64.img
            ;;
        *)
            echo "Unknown architecture: $arch" >&2
            exit 1
            ;;
    esac
}

set_work_dir() {
    if [ -z "$1" ]; then
        echo "Work/cache directory cannot be empty." >&2
        exit 1
    fi
    UNLIM8TED_WORK_DIR=$1
    UNLIM8TED_BASE_IMAGE_DIR="$UNLIM8TED_WORK_DIR/base-images"
    UNLIM8TED_BUILD_DIR="$UNLIM8TED_WORK_DIR/work"
    export UNLIM8TED_WORK_DIR UNLIM8TED_BASE_IMAGE_DIR UNLIM8TED_BUILD_DIR
}

use_existing_folder_cache() {
    echo
    show_windows_drive_mounts
    show_windows_volumes
    echo
    echo "Enter an existing mounted folder path. No formatting will be performed."
    echo "Examples:"
    echo "  /mnt/o/unlim8ted-build-cache"
    echo "  /mnt/e/unlim8ted-build-cache"
    folder=$(prompt "Cache folder: ")

    if [ -z "$folder" ]; then
        echo "Cache folder cannot be empty." >&2
        exit 1
    fi

    mkdir -p "$folder/work" "$folder/base-images"

    if [ ! -w "$folder" ]; then
        echo "Cache folder is not writable: $folder" >&2
        exit 1
    fi

    set_work_dir "$folder"
}

format_and_mount_external_cache() {
    require_command lsblk
    require_command findmnt
    require_command mkfs.ext4
    require_command mount
    require_command umount
    require_command sudo

    echo
    list_devices
    echo
    echo "External cache mode uses the selected ext4 device or partition."
    echo "If it is not already an ext4 UNLIM8TED_BUILD cache device, the script can format it."
    echo "Examples: /dev/sdb or /dev/sdb1"
    device=$(prompt "Device to use: ")
    require_block_device "$device"

    mount_dir=$(prompt "Mount point [/mnt/unlim8ted-build-cache]: ")
    if [ -z "$mount_dir" ]; then
        mount_dir=/mnt/unlim8ted-build-cache
    fi

    unmount_block_device_tree "$device"

    device_fstype=$(blkid -o value -s TYPE "$device" 2>/dev/null || true)
    device_label=$(blkid -o value -s LABEL "$device" 2>/dev/null || true)
    if [ "$device_fstype" = "ext4" ] && [ "$device_label" = "UNLIM8TED_BUILD" ]; then
        echo "Reusing existing ext4 build cache on $device."
    else
        confirm_token FORMAT "DANGER: $device will be formatted as ext4. This destroys all data on the selected device only."
        sudo mkfs.ext4 -F -L UNLIM8TED_BUILD "$device"
    fi

    sudo mkdir -p "$mount_dir"
    if mountpoint -q "$mount_dir"; then
        mounted_source=$(findmnt -rn -T "$mount_dir" -o SOURCE 2>/dev/null || true)
        if [ "$mounted_source" != "$device" ]; then
            echo "Refusing to use $mount_dir because it is already mounted from $mounted_source." >&2
            exit 1
        fi
    else
        sudo mount "$device" "$mount_dir"
    fi
    sudo mkdir -p "$mount_dir/work" "$mount_dir/base-images"
    sudo chown -R "$(id -u):$(id -g)" "$mount_dir"

    AUTO_UNMOUNT_CACHE=1
    AUTO_UNMOUNT_DIR="$mount_dir"
    AUTO_UNMOUNT_DEVICE="$device"

    set_work_dir "$mount_dir"
}

select_cache_location() {
    echo
    if is_wsl; then
        echo "Select cache/work location:"
        echo "  1) WSL Linux cache at ~/.cache/unlim8ted-os-build"
        echo "  2) External drive or partition, formatted as ext4"
        echo "  3) Existing mounted folder, no formatting"
        choice=$(prompt "Cache option [1-3]: ")
    else
        echo "Select cache/work location:"
        echo "  1) Default repo-local build directory"
        echo "  2) External drive or partition, formatted as ext4"
        echo "  3) Existing mounted folder, no formatting"
        choice=$(prompt "Cache option [1-3]: ")
    fi

    case "$choice" in
        1)
            if is_wsl; then
                set_work_dir "${HOME:-/tmp}/.cache/unlim8ted-os-build"
            else
                set_work_dir "$SCRIPT_DIR/build"
            fi
            ;;
        2)
            format_and_mount_external_cache
            ;;
        3)
            use_existing_folder_cache
            ;;
        *)
            echo "Invalid cache option: $choice" >&2
            exit 1
            ;;
    esac
}

run_image_build() {
    arch=
    direct_device=
    grow_mb=
    grow_mb_set=0

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --arch)
                arch=${2:-}
                shift 2
                ;;
            --direct-device | --device)
                direct_device=${2:-}
                shift 2
                ;;
            --grow-mb)
                grow_mb=${2:-}
                grow_mb_set=1
                shift 2
                ;;
            --cache-dir)
                set_work_dir "${2:-}"
                shift 2
                ;;
            --base-cache-dir)
                UNLIM8TED_BASE_IMAGE_DIR=${2:-}
                export UNLIM8TED_BASE_IMAGE_DIR
                shift 2
                ;;
            *)
                usage
                ;;
        esac
    done

    [ -n "$arch" ] || usage
    if [ "$grow_mb_set" -eq 1 ]; then
        case "$grow_mb" in
            *[!0-9]* | "")
                echo "--grow-mb must be a non-negative integer." >&2
                exit 1
                ;;
        esac
    fi

    target_values "$arch"
    if [ "$grow_mb_set" -eq 1 ]; then
        UNLIM8TED_IMAGE_GROW_MB=$grow_mb
    elif [ "$TARGET_NAME" = "cm4" ]; then
        UNLIM8TED_IMAGE_GROW_MB=$UNLIM8TED_CM4_IMAGE_GROW_MB
    else
        UNLIM8TED_IMAGE_GROW_MB=0
    fi
    export UNLIM8TED_IMAGE_GROW_MB
    if [ -n "$direct_device" ]; then
        if [ "$TARGET_NAME" != "cm4" ]; then
            echo "--direct-device is only supported for --arch cm4." >&2
            exit 1
        fi
        require_block_device "$direct_device"
        confirm_token FLASH "DANGER: $direct_device may be overwritten if it is not already a resumable CM4 OS device."
        UNLIM8TED_DIRECT_DEVICE=$direct_device
        UNLIM8TED_IMAGE_GROW_MB=0
        export UNLIM8TED_DIRECT_DEVICE UNLIM8TED_IMAGE_GROW_MB
    fi

    sanitize_path
    ensure_prerequisites
    build_target "$TARGET_NAME" "$TARGET_ARCH" "$TARGET_URL" "$TARGET_ARCHIVE" "$TARGET_PACKAGES" "$TARGET_OUTPUT"
}

run_deferred_cm4() {
    device=
    boot_size_mib=$UNLIM8TED_CM4_BOOT_SIZE_MIB
    root_size_mib=$UNLIM8TED_CM4_ROOT_SIZE_MIB
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --device)
                device=${2:-}
                shift 2
                ;;
            --boot-size-mib)
                boot_size_mib=${2:-}
                shift 2
                ;;
            --root-size-mib)
                root_size_mib=${2:-}
                shift 2
                ;;
            --root-size-gib)
                root_size_gib=${2:-}
                case "$root_size_gib" in
                    *[!0-9]* | "")
                        echo "--root-size-gib must be a positive integer." >&2
                        exit 1
                        ;;
                esac
                root_size_mib=$((root_size_gib * 1024))
                shift 2
                ;;
            *)
                usage
                ;;
        esac
    done

    [ -n "$device" ] || usage
    require_block_device "$device"
    case "$boot_size_mib" in
        *[!0-9]* | "")
            echo "--boot-size-mib must be a positive integer." >&2
            exit 1
            ;;
    esac
    case "$root_size_mib" in
        *[!0-9]* | "")
            echo "--root-size-mib must be a positive integer." >&2
            exit 1
            ;;
    esac

    confirm_token DEFERRED-FLASH "DANGER: $device will be completely reformatted. bootfs=${boot_size_mib}MiB, rootfs=${root_size_mib}MiB, storage=rest. Packages will install on first boot after network login."

    sanitize_path
    ensure_prerequisites

    source_image=$(get_base_image "cm4" "$UNLIM8TED_CM4_IMAGE_URL" "$UNLIM8TED_CM4_ARCHIVE_NAME")
    mount_root="$UNLIM8TED_BUILD_DIR/mount-cm4-deferred"
    source_mount="$UNLIM8TED_BUILD_DIR/mount-cm4-source"
    root_mount=
    boot_mount=
    source_root=
    source_boot=
    loop_device=

    cleanup_deferred() {
        set +e
        if [ -n "$source_root" ]; then
            unmount_image_partitions "$source_root" "$source_boot"
        fi
        if [ -n "$loop_device" ]; then
            detach_loop_device "$loop_device"
        fi
        if [ -n "$root_mount" ]; then
            unbind_mount_chroot_support "$root_mount"
            unmount_image_partitions "$root_mount" "$boot_mount"
        fi
        sudo rm -rf "$mount_root"
        sudo rm -rf "$source_mount"
    }
    trap cleanup_deferred EXIT INT TERM

    unmount_block_device_tree "$device"
    echo "Preparing base image source mounts..." >&2
    sudo rm -rf "$source_mount"
    loop_device=$(attach_loop_device "$source_image")
    mounts=$(mount_image_partitions "$loop_device" "$source_mount")
    source_root=$(printf '%s\n' "$mounts" | sed -n '1p')
    source_boot=$(printf '%s\n' "$mounts" | sed -n '2p')

    echo "Creating partition layout on $device..." >&2
    create_partition_layout_on_device "$device" "$boot_size_mib" "$root_size_mib"

    sudo rm -rf "$mount_root"
    mounts=$(mount_image_partitions "$device" "$mount_root")
    root_mount=$(printf '%s\n' "$mounts" | sed -n '1p')
    boot_mount=$(printf '%s\n' "$mounts" | sed -n '2p')

    echo "Root filesystem capacity before first-boot expansion:" >&2
    df -h "$root_mount" >&2 || true

    if mountpoint -q "$root_mount/home/unlim8ted"; then
        echo "Temporarily unmounting storage partition during base OS copy..." >&2
        sudo umount "$root_mount/home/unlim8ted"
    fi

    echo "Copying base OS into new partitions..." >&2
    sudo rsync -a --delete "$source_boot/" "$boot_mount/"
    sudo rsync -aHAX --delete "$source_root/" "$root_mount/"

    apply_overlay "$root_mount" "$boot_mount"
    configure_boot_splash "$boot_mount"
    setup_storage_mount "$root_mount"

    sudo install -m 0755 "$UNLIM8TED_OVERLAY_DIR/opt/unlim8ted/bin/firstboot-install.sh" "$root_mount/opt/unlim8ted/bin/firstboot-install.sh"
    sudo mkdir -p "$root_mount/etc/default"
    cat <<EOF | sudo tee "$root_mount/etc/default/unlim8ted-firstboot" >/dev/null
UNLIM8TED_FIRSTBOOT_PACKAGES="$UNLIM8TED_CM4_PACKAGES"
EOF

    sudo mkdir -p "$root_mount/etc/systemd/system/multi-user.target.wants"
    sudo rm -f "$root_mount/etc/systemd/system/multi-user.target.wants/unlim8ted.service"
    sudo ln -sf ../unlim8ted-firstboot-install.service "$root_mount/etc/systemd/system/multi-user.target.wants/unlim8ted-firstboot-install.service"

    unmount_image_partitions "$root_mount" "$boot_mount"
    root_mount=
    boot_mount=
    sync

    echo "Deferred CM4 image complete on $device"
    echo "Boot it, connect network on tty1 when prompted, and packages will install there."
}

run_overlay_reapply() {
    device=
    boot_part=
    root_part=
    storage_part=
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --device)
                device=${2:-}
                shift 2
                ;;
            --boot-part)
                boot_part=${2:-}
                shift 2
                ;;
            --root-part)
                root_part=${2:-}
                shift 2
                ;;
            --storage-part)
                storage_part=${2:-}
                shift 2
                ;;
            *)
                usage
                ;;
        esac
    done

    [ -n "$device" ] || usage
    require_block_device "$device"
    if [ -n "$boot_part" ] || [ -n "$root_part" ] || [ -n "$storage_part" ]; then
        set_partition_overrides "$device" "$boot_part" "$root_part" "$storage_part"
    fi
    confirm_token OVERLAY "This will reapply the full overlay to $device without installing packages or resizing partitions."

    sanitize_path
    ensure_prerequisites
    unmount_block_device_tree "$device"

    mount_root="$UNLIM8TED_BUILD_DIR/mount-overlay-reapply"
    sudo rm -rf "$mount_root"
    root_mount=
    boot_mount=

    cleanup_overlay() {
        set +e
        if [ -n "$root_mount" ]; then
            unmount_image_partitions "$root_mount" "$boot_mount"
        fi
        sudo rm -rf "$mount_root"
    }
    trap cleanup_overlay EXIT INT TERM

    mounts=$(mount_image_partitions "$device" "$mount_root")
    root_mount=$(printf '%s\n' "$mounts" | sed -n '1p')
    boot_mount=$(printf '%s\n' "$mounts" | sed -n '2p')

    apply_overlay "$root_mount" "$boot_mount"
    configure_boot_splash "$boot_mount"
    configure_plymouth "$root_mount" "arm64"
    setup_storage_mount "$root_mount"
    enable_services "$root_mount" "arm64"

    unmount_image_partitions "$root_mount" "$boot_mount"
    root_mount=
    boot_mount=
    sync
    echo "Overlay reapplied to $device"
}

copy_hotpatch_file() {
    source_rel=$1
    target_rel=$2
    mode=${3:-0644}
    source_path=$SCRIPT_DIR/overlay/$source_rel
    target_path=$root_mount/$target_rel

    if [ ! -f "$source_path" ]; then
        echo "Missing source file: $source_path" >&2
        exit 1
    fi

    sudo install -D -m "$mode" "$source_path" "$target_path"
    echo "patched /$target_rel"
}

configure_hotpatch_plymouth_theme_link() {
    theme_target=$root_mount/usr/share/plymouth/themes/unlim8ted-eight/unlim8ted-eight.plymouth
    default_link=$root_mount/usr/share/plymouth/themes/default.plymouth
    if [ ! -f "$theme_target" ]; then
        echo "WARNING: Plymouth theme file missing after copy: $theme_target"
        return
    fi
    sudo ln -sfn unlim8ted-eight/unlim8ted-eight.plymouth "$default_link"
    echo "patched /usr/share/plymouth/themes/default.plymouth"
}

warn_hotpatch_plymouth_runtime() {
    if [ -x "$root_mount/usr/sbin/plymouthd" ] || [ -x "$root_mount/usr/bin/plymouth" ]; then
        echo "Plymouth runtime found on target."
        return
    fi
    echo "WARNING: Plymouth is not installed on this target rootfs."
    echo "The hotpatch copied theme files and boot flags, but it does not install packages."
}

run_hotpatch() {
    device=
    boot_part=
    root_part=
    storage_part=
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --device)
                device=${2:-}
                shift 2
                ;;
            --boot-part)
                boot_part=${2:-}
                shift 2
                ;;
            --root-part)
                root_part=${2:-}
                shift 2
                ;;
            --storage-part)
                storage_part=${2:-}
                shift 2
                ;;
            *)
                usage
                ;;
        esac
    done

    [ -n "$device" ] || usage
    require_block_device "$device"
    if [ -n "$boot_part" ] || [ -n "$root_part" ] || [ -n "$storage_part" ]; then
        set_partition_overrides "$device" "$boot_part" "$root_part" "$storage_part"
    fi
    confirm_token PATCH "This will patch selected runtime files on $device only. Package install: never."

    sanitize_path
    require_linux_host
    for cmd in awk blkid cp find grep install ln lsblk mkdir mount mountpoint rsync sed sudo sync tee umount; do
        require_command "$cmd"
    done
    unmount_block_device_tree "$device"

    mount_root="$UNLIM8TED_BUILD_DIR/mount-cm4-hotpatch"
    sudo rm -rf "$mount_root"
    root_mount=
    boot_mount=

    cleanup_hotpatch() {
        set +e
        if [ -n "$root_mount" ]; then
            unmount_image_partitions "$root_mount" "$boot_mount"
        fi
        sudo rm -rf "$mount_root"
    }
    trap cleanup_hotpatch EXIT INT TERM

    mounts=$(mount_image_partitions "$device" "$mount_root")
    root_mount=$(printf '%s\n' "$mounts" | sed -n '1p')
    boot_mount=$(printf '%s\n' "$mounts" | sed -n '2p')

    copy_hotpatch_file "opt/unlim8ted/ui/index.html" "opt/unlim8ted/ui/index.html"
    copy_hotpatch_file "opt/unlim8ted/ui/app.js" "opt/unlim8ted/ui/app.js"
    copy_hotpatch_file "opt/unlim8ted/backend/main.py" "opt/unlim8ted/backend/main.py"
    copy_hotpatch_file "opt/unlim8ted/bin/firstboot-install.sh" "opt/unlim8ted/bin/firstboot-install.sh" 0755
    copy_hotpatch_file "opt/unlim8ted/commands/registry.json" "opt/unlim8ted/commands/registry.json"
    copy_hotpatch_file "etc/plymouth/plymouthd.conf" "etc/plymouth/plymouthd.conf"
    copy_hotpatch_file "usr/share/plymouth/themes/unlim8ted-eight/unlim8ted-eight.plymouth" "usr/share/plymouth/themes/unlim8ted-eight/unlim8ted-eight.plymouth"
    copy_hotpatch_file "usr/share/plymouth/themes/unlim8ted-eight/unlim8ted-eight.script" "usr/share/plymouth/themes/unlim8ted-eight/unlim8ted-eight.script"
    copy_hotpatch_file "opt/unlim8ted/apps/files/index.html" "opt/unlim8ted/apps/files/index.html"
    copy_hotpatch_file "opt/unlim8ted/apps/files/client.js" "opt/unlim8ted/apps/files/client.js"
    copy_hotpatch_file "opt/unlim8ted/apps/files/main.py" "opt/unlim8ted/apps/files/main.py"
    copy_hotpatch_file "opt/unlim8ted/apps/settings/index.html" "opt/unlim8ted/apps/settings/index.html"
    copy_hotpatch_file "opt/unlim8ted/apps/settings/client.js" "opt/unlim8ted/apps/settings/client.js"
    copy_hotpatch_file "opt/unlim8ted/apps/settings/main.py" "opt/unlim8ted/apps/settings/main.py"
    copy_hotpatch_file "opt/unlim8ted/apps/terminal/index.html" "opt/unlim8ted/apps/terminal/index.html"
    copy_hotpatch_file "opt/unlim8ted/apps/terminal/client.js" "opt/unlim8ted/apps/terminal/client.js"
    copy_hotpatch_file "opt/unlim8ted/apps/terminal/main.py" "opt/unlim8ted/apps/terminal/main.py"
    configure_boot_splash "$boot_mount"
    configure_hotpatch_plymouth_theme_link
    warn_hotpatch_plymouth_runtime

    sync
    unmount_image_partitions "$root_mount" "$boot_mount"
    root_mount=
    boot_mount=
    sync
    echo "CM4 runtime hotpatch complete: $device"
}

current_root_fs_mib() {
    device=$1
    root_partition=$(find_root_partition "$device")
    [ -n "$root_partition" ] || {
        echo "Could not find root partition on $device" >&2
        exit 1
    }
    size_mib=$(sudo dumpe2fs -h "$root_partition" 2>/dev/null | awk '
        /Block count:/ { blocks = $3 }
        /Block size:/ { size = $3 }
        END {
            if (blocks && size) {
                printf "%.0f\n", blocks * size / 1024 / 1024
            }
        }
    ')
    if [ -z "$size_mib" ]; then
        echo "Could not read ext4 filesystem size for $root_partition" >&2
        exit 1
    fi
    printf '%s\n' "$size_mib"
}

run_repair() {
    device=
    mode=--add-mb
    amount=8192
    no_resize=0
    boot_part=
    root_part=
    storage_part=

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --device)
                device=${2:-}
                shift 2
                ;;
            --add-mb)
                mode=--add-mb
                amount=${2:-}
                shift 2
                ;;
            --size-gib)
                mode=--size-gib
                amount=${2:-}
                shift 2
                ;;
            --no-resize)
                no_resize=1
                shift 1
                ;;
            --boot-part)
                boot_part=${2:-}
                shift 2
                ;;
            --root-part)
                root_part=${2:-}
                shift 2
                ;;
            --storage-part)
                storage_part=${2:-}
                shift 2
                ;;
            *)
                usage
                ;;
        esac
    done

    [ -n "$device" ] || usage
    require_block_device "$device"
    if [ -n "$boot_part" ] || [ -n "$root_part" ] || [ -n "$storage_part" ]; then
        set_partition_overrides "$device" "$boot_part" "$root_part" "$storage_part"
    fi
    if [ "$no_resize" -eq 1 ]; then
        mode=--no-resize
    fi
    case "$amount" in
        *[!0-9]* | "")
            echo "size amount must be a positive integer." >&2
            exit 1
            ;;
    esac

    case "$mode" in
        --no-resize)
            root_size_gib=
            ;;
        --add-mb)
            current_mib=$(current_root_fs_mib "$device")
            target_mib=$((current_mib + amount))
            root_size_gib=$(((target_mib + 1023) / 1024))
            ;;
        --size-gib)
            root_size_gib=$amount
            ;;
    esac

    if [ "$mode" = "--no-resize" ]; then
        confirm_token REPAIR "Repairing CM4 device: $device without resizing partitions."
    else
        confirm_token REPAIR "Repairing CM4 device: $device. Root partition target size: ${root_size_gib}GiB."
    fi

    sanitize_path
    ensure_prerequisites
    if [ "$mode" != "--no-resize" ]; then
        unmount_block_device_tree "$device"
        create_storage_partition_on_device "$device" "$root_size_gib" 1
        unmount_block_device_tree "$device"
    fi

    mount_root="$UNLIM8TED_BUILD_DIR/mount-cm4-repair"
    sudo rm -rf "$mount_root"
    root_mount=
    boot_mount=

    cleanup_repair() {
        set +e
        if [ -n "$root_mount" ]; then
            unbind_mount_apt_cache "$root_mount"
            unbind_mount_chroot_support "$root_mount"
            unmount_image_partitions "$root_mount" "$boot_mount"
        fi
        sudo rm -rf "$mount_root"
    }
    trap cleanup_repair EXIT INT TERM

    mounts=$(mount_image_partitions "$device" "$mount_root")
    root_mount=$(printf '%s\n' "$mounts" | sed -n '1p')
    boot_mount=$(printf '%s\n' "$mounts" | sed -n '2p')

    echo "Root filesystem capacity before repair/install:" >&2
    df -h "$root_mount" >&2 || true

    install_target_packages "$root_mount" "arm64" "$UNLIM8TED_CM4_PACKAGES" "cm4"
    install_browser_compatibility "$root_mount" "arm64"
    apply_overlay "$root_mount" "$boot_mount"
    configure_boot_splash "$boot_mount"
    configure_plymouth "$root_mount" "arm64"
    setup_storage_mount "$root_mount"
    enable_services "$root_mount" "arm64"

    echo "Final root filesystem capacity:" >&2
    df -h "$root_mount" >&2 || true

    unmount_image_partitions "$root_mount" "$boot_mount"
    root_mount=
    boot_mount=
    sync
    echo "CM4 device repair/install complete: $device"
}

clean_target_package_state() {
    root_mount=$1
    bind_mount_chroot_support "$root_mount"
    copy_qemu_static_if_needed "arm64" "$root_mount"
    run_in_chroot "$root_mount" "arm64" \
        "export DEBIAN_FRONTEND=noninteractive; apt-get clean; apt-get autoclean; rm -rf /var/lib/apt/lists/*; find /tmp /var/tmp -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +"
    remove_qemu_static_if_present "$root_mount"
    unbind_mount_chroot_support "$root_mount"
}

clean_host_package_cache() {
    apt_cache_dir="$UNLIM8TED_BUILD_DIR/apt-cache-cm4"

    if [ -z "$UNLIM8TED_BUILD_DIR" ] || [ "$UNLIM8TED_BUILD_DIR" = "/" ]; then
        echo "Refusing to clean unsafe build directory: $UNLIM8TED_BUILD_DIR" >&2
        exit 1
    fi

    case "$apt_cache_dir" in
        "$UNLIM8TED_BUILD_DIR"/*)
            ;;
        *)
            echo "Refusing to clean apt cache outside build directory: $apt_cache_dir" >&2
            exit 1
            ;;
    esac

    rm -rf "$apt_cache_dir"
}

run_continue() {
    device=
    boot_part=
    root_part=
    storage_part=
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --device)
                device=${2:-}
                shift 2
                ;;
            --boot-part)
                boot_part=${2:-}
                shift 2
                ;;
            --root-part)
                root_part=${2:-}
                shift 2
                ;;
            --storage-part)
                storage_part=${2:-}
                shift 2
                ;;
            *)
                usage
                ;;
        esac
    done

    [ -n "$device" ] || usage
    require_block_device "$device"
    if [ -n "$boot_part" ] || [ -n "$root_part" ] || [ -n "$storage_part" ]; then
        set_partition_overrides "$device" "$boot_part" "$root_part" "$storage_part"
    fi
    confirm_token CONTINUE "Continuing CM4 package install on $device. No partition resize will be performed."

    sanitize_path
    ensure_prerequisites
    unmount_block_device_tree "$device"

    mount_root="$UNLIM8TED_BUILD_DIR/mount-cm4-continue"
    sudo rm -rf "$mount_root"
    root_mount=
    boot_mount=

    cleanup_continue() {
        set +e
        if [ -n "$root_mount" ]; then
            unbind_mount_apt_cache "$root_mount"
            unbind_mount_chroot_support "$root_mount"
            unmount_image_partitions "$root_mount" "$boot_mount"
        fi
        sudo rm -rf "$mount_root"
    }
    trap cleanup_continue EXIT INT TERM

    mounts=$(mount_image_partitions "$device" "$mount_root")
    root_mount=$(printf '%s\n' "$mounts" | sed -n '1p')
    boot_mount=$(printf '%s\n' "$mounts" | sed -n '2p')

    echo "Root filesystem capacity before install:" >&2
    df -h "$root_mount" >&2 || true

    echo "Cleaning previous CM4 host apt cache before retry..." >&2
    clean_host_package_cache
    install_target_packages "$root_mount" "arm64" "$UNLIM8TED_CM4_PACKAGES" "cm4"
    install_browser_compatibility "$root_mount" "arm64"
    apply_overlay "$root_mount" "$boot_mount"
    configure_boot_splash "$boot_mount"
    configure_plymouth "$root_mount" "arm64"
    setup_storage_mount "$root_mount"
    enable_services "$root_mount" "arm64"
    clean_target_package_state "$root_mount"
    echo "Cleaning CM4 host apt cache after install..." >&2
    clean_host_package_cache

    echo "Root filesystem capacity after cleanup:" >&2
    df -h "$root_mount" >&2 || true

    unmount_image_partitions "$root_mount" "$boot_mount"
    root_mount=
    boot_mount=
    sync
    echo "CM4 package continuation complete: $device"
}

run_interactive() {
    if [ "$(id -u)" -eq 0 ]; then
        echo "Do not run this wrapper with sudo. It will ask for sudo only when needed." >&2
        exit 1
    fi

    echo "Select operation:"
    echo "  1) Build x86_64 test image"
    echo "  2) Build CM4 image"
    echo "  3) Flash/build CM4 directly on SD/USB"
    echo "  4) Deferred CM4 first-boot install"
    echo "  5) Reapply full overlay to existing card"
    echo "  6) Runtime hotpatch existing card"
    echo "  7) Repair/resume CM4 card with resize"
    echo "  8) Continue CM4 package install without resize"
    echo "  9) List devices"
    choice=$(prompt "Operation [1-9]: ")

    case "$choice" in
        1)
            select_cache_location
            grow_mb=$(prompt "Extra image size in MiB [4096]: ")
            [ -n "$grow_mb" ] || grow_mb=4096
            run_image_build --arch x86_64 --grow-mb "$grow_mb"
            ;;
        2)
            select_cache_location
            grow_mb=$(prompt "Extra image size in MiB [$UNLIM8TED_CM4_IMAGE_GROW_MB]: ")
            [ -n "$grow_mb" ] || grow_mb=$UNLIM8TED_CM4_IMAGE_GROW_MB
            run_image_build --arch cm4 --grow-mb "$grow_mb"
            ;;
        3)
            list_devices
            device=$(prompt "Device to flash/build directly: ")
            run_image_build --arch cm4 --direct-device "$device"
            ;;
        4)
            list_devices
            device=$(prompt "Device to flash deferred image: ")
            run_deferred_cm4 --device "$device"
            ;;
        5)
            list_devices
            device=$(prompt "Device to reapply overlay: ")
            run_overlay_reapply --device "$device"
            ;;
        6)
            list_devices
            device=$(prompt "Device to hotpatch: ")
            run_hotpatch --device "$device"
            ;;
        7)
            list_devices
            device=$(prompt "Device to repair: ")
            amount=$(prompt "Add MiB to rootfs [8192]: ")
            [ -n "$amount" ] || amount=8192
            run_repair --device "$device" --add-mb "$amount"
            ;;
        8)
            list_devices
            device=$(prompt "Device to continue install: ")
            run_continue --device "$device"
            ;;
        9)
            list_devices
            ;;
        *)
            echo "Invalid operation: $choice" >&2
            exit 1
            ;;
    esac
}

main() {
    if [ "$(uname -s)" != "Linux" ]; then
        echo "Run this script from Linux or WSL." >&2
        exit 1
    fi

    command_name=${1:-interactive}
    if [ "$#" -gt 0 ]; then
        shift
    fi

    case "$command_name" in
        interactive)
            run_interactive "$@"
            ;;
        image)
            run_image_build "$@"
            ;;
        deferred)
            run_deferred_cm4 "$@"
            ;;
        overlay)
            run_overlay_reapply "$@"
            ;;
        hotpatch | patch)
            run_hotpatch "$@"
            ;;
        repair)
            run_repair "$@"
            ;;
        continue)
            run_continue "$@"
            ;;
        list-devices | devices)
            list_devices
            ;;
        -h | --help | help)
            usage
            ;;
        *)
            usage
            ;;
    esac
}

main "$@"



