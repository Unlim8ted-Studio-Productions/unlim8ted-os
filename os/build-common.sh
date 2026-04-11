#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=./build-config.env
. "$SCRIPT_DIR/build-config.env"

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

require_linux_host() {
    host_kernel=$(uname -s)
    if [ "$host_kernel" != "Linux" ]; then
        echo "These build scripts must run from Linux or WSL, not directly from Windows PowerShell." >&2
        exit 1
    fi
}

ensure_prerequisites() {
    require_linux_host

    for cmd in awk blkid cp curl e2fsck find grep install losetup lsblk mkdir mount mountpoint parted resize2fs rsync sed sudo tar truncate umount unzip xz; do
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
            fi
            printf '%s\n' "$image_path"
            ;;
        *.img.xz | *.raw.xz)
            image_name=$(basename "$archive_path" .xz)
            image_path=$extract_dir/$image_name
            if [ ! -f "$image_path" ]; then
                mkdir -p "$extract_dir"
                xz -dc "$archive_path" > "$image_path"
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

find_partition_by_fstype() {
    loop_device=$1
    fstype=$2

    if [ -z "$loop_device" ]; then
        echo "find_partition_by_fstype called without a loop device" >&2
        exit 1
    fi

    result=$(lsblk -lnpo NAME,FSTYPE "$loop_device" | awk -v want="$fstype" '$2 == want { print $1; exit }')
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
        echo "Could not locate a writable root partition in $image_path" >&2
        exit 1
    fi

    part_num=$(printf '%s\n' "$root_partition" | sed 's|.*p||')
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

mount_image_partitions() {
    loop_device=$1
    mount_root=$2

    root_partition=$(find_root_partition "$loop_device")
    boot_partition=$(find_boot_partition "$loop_device" || true)

    if [ -z "$root_partition" ]; then
        echo "Could not find a writable root partition on $loop_device" >&2
        exit 1
    fi

    root_mount=$mount_root/root
    boot_mount=$mount_root/boot
    sudo mkdir -p "$root_mount"
    sudo mount "$root_partition" "$root_mount"

    if [ -n "$boot_partition" ]; then
        sudo mkdir -p "$boot_mount"
        sudo mount "$boot_partition" "$boot_mount"
    fi

    printf '%s\n%s\n' "$root_mount" "$boot_mount"
}

unmount_image_partitions() {
    root_mount=$1
    boot_mount=$2

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

    bind_mount_chroot_support "$root_mount"
    copy_qemu_static_if_needed "$target_arch" "$root_mount"

    run_in_chroot "$root_mount" "$target_arch" \
        "export DEBIAN_FRONTEND=noninteractive; apt-get update; apt-get install -y $package_list"

    remove_qemu_static_if_present "$root_mount"
    unbind_mount_chroot_support "$root_mount"
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
            sudo rsync -a "$UNLIM8TED_OVERLAY_DIR/boot/firmware/" "$boot_mount/firmware/"
        else
            sudo rsync -a "$UNLIM8TED_OVERLAY_DIR/boot/" "$boot_mount/"
        fi
    fi
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

    target_dir=$UNLIM8TED_ARTIFACT_DIR/$target_name
    mount_root=$UNLIM8TED_BUILD_DIR/mount-$target_name
    output_image=$target_dir/$output_name
    boot_mount=
    root_mount=
    loop_device=

    sudo rm -rf "$mount_root"
    rm -rf "$target_dir"
    mkdir -p "$target_dir"

    copy_base_image "$source_image" "$output_image"
    grow_image_if_needed "$output_image" "$UNLIM8TED_IMAGE_GROW_MB"

    cleanup() {
        set +e
        if [ -n "$root_mount" ]; then
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

    loop_device=$(attach_loop_device "$output_image")
    loop_device=$(grow_root_partition_if_needed "$output_image" "$loop_device" "$UNLIM8TED_IMAGE_GROW_MB")

    mounts=$(mount_image_partitions "$loop_device" "$mount_root")
    root_mount=$(printf '%s\n' "$mounts" | sed -n '1p')
    boot_mount=$(printf '%s\n' "$mounts" | sed -n '2p')

    install_target_packages "$root_mount" "$target_arch" "$package_list"
    install_browser_compatibility "$root_mount" "$target_arch"
    apply_overlay "$root_mount" "$boot_mount"
    enable_services "$root_mount" "$target_arch"
    write_build_metadata "$target_dir" "$output_name" "$base_image_url" "$package_list"
}
