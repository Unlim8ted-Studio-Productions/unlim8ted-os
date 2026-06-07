#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
UNLIM8TED_OS_DIR=${UNLIM8TED_OS_DIR:-$SCRIPT_DIR}
UNLIM8TED_WORK_DIR=${UNLIM8TED_WORK_DIR:-$UNLIM8TED_OS_DIR/build}
UNLIM8TED_BASE_IMAGE_DIR=${UNLIM8TED_BASE_IMAGE_DIR:-$UNLIM8TED_WORK_DIR/base-images}
UNLIM8TED_BUILD_DIR=${UNLIM8TED_BUILD_DIR:-$UNLIM8TED_WORK_DIR/work}
UNLIM8TED_OVERLAY_DIR=${UNLIM8TED_OVERLAY_DIR:-$UNLIM8TED_OS_DIR/overlay}

UNLIM8TED_CM4_IMAGE_URL=${UNLIM8TED_CM4_IMAGE_URL:-https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2026-04-21/2026-04-21-raspios-trixie-arm64-lite.img.xz}
UNLIM8TED_CM4_ARCHIVE_NAME=${UNLIM8TED_CM4_ARCHIVE_NAME:-2026-04-21-raspios-trixie-arm64-lite.img.xz}
UNLIM8TED_CM4_PACKAGES=${UNLIM8TED_CM4_PACKAGES:-python3 chromium libcamera-apps bluez wpasupplicant xserver-xorg xinit x11-xserver-utils xserver-xorg-input-libinput keyboard-configuration usbutils openbox mesa-utils dbus-x11 fonts-dejavu-core}
UNLIM8TED_CM4_ROOT_SIZE_MIB=${UNLIM8TED_CM4_ROOT_SIZE_MIB:-9728}
UNLIM8TED_DEFAULT_USER=${UNLIM8TED_DEFAULT_USER:-unlim8ted}
UNLIM8TED_DEFAULT_PASSWORD=${UNLIM8TED_DEFAULT_PASSWORD:-unlim8ted}

sanitize_path() {
    original_path=${PATH-}
    safe_path=

    OLD_IFS=$IFS
    IFS=:
    set -f
    for entry in $original_path; do
        case "$entry" in
            *[![:print:]]* | *[[:space:]]* | "")
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
    IFS=$OLD_IFS

    if [ -n "$safe_path" ]; then
        PATH=$safe_path
        export PATH
    fi
}

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

ensure_prerequisites() {
    require_linux_host
    for cmd in awk blkid curl dd e2fsck find grep install losetup lsblk mkdir mount mountpoint openssl parted resize2fs rsync sed sudo sync tee truncate umount xz; do
        require_command "$cmd"
    done
    mkdir -p "$UNLIM8TED_WORK_DIR" "$UNLIM8TED_BASE_IMAGE_DIR" "$UNLIM8TED_BUILD_DIR"
}

prompt() {
    printf '%s' "$1" >&2
    read -r REPLY
    printf '%s\n' "$REPLY"
}

prompt_secret() {
    printf '%s' "$1" >&2
    stty -echo 2>/dev/null || true
    read -r REPLY
    stty echo 2>/dev/null || true
    printf '\n' >&2
    printf '%s\n' "$REPLY"
}

shell_quote() {
    printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

keyboard_layout_for_country() {
    country=$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')
    case "$country" in
        GB) printf '%s\n' gb ;;
        FR) printf '%s\n' fr ;;
        DE) printf '%s\n' de ;;
        ES) printf '%s\n' es ;;
        IT) printf '%s\n' it ;;
        PT) printf '%s\n' pt ;;
        BR) printf '%s\n' br ;;
        JP) printf '%s\n' jp ;;
        *) printf '%s\n' us ;;
    esac
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
        *.img.xz)
            image_name=$(basename "$archive_path" .xz)
            image_path=$extract_dir/$image_name
            if [ ! -f "$image_path" ]; then
                mkdir -p "$extract_dir"
                xz -dc "$archive_path" > "$image_path"
            fi
            printf '%s\n' "$image_path"
            ;;
        *.img)
            printf '%s\n' "$archive_path"
            ;;
        *)
            echo "Unsupported base image format: $archive_path" >&2
            exit 1
            ;;
    esac
}

get_base_image() {
    archive_path=$UNLIM8TED_BASE_IMAGE_DIR/$UNLIM8TED_CM4_ARCHIVE_NAME
    extract_dir=$UNLIM8TED_BASE_IMAGE_DIR/cm4

    existing=$(find "$extract_dir" -maxdepth 1 -type f -name '*.img' 2>/dev/null | head -n 1 || true)
    if [ -n "$existing" ] && [ -f "$existing" ]; then
        printf '%s\n' "$existing"
        return
    fi

    download_file "$UNLIM8TED_CM4_IMAGE_URL" "$archive_path"
    resolve_image_path_from_archive "$archive_path" "$extract_dir"
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

list_child_partitions() {
    block_device=$1
    lsblk -lnpo NAME "$block_device" 2>/dev/null | awk -v dev="$block_device" '$1 != dev { print $1 }'
}

find_partition_by_fstype() {
    loop_device=$1
    fstype=$2
    lsblk -rnpo NAME,FSTYPE "$loop_device" | awk -v want="$fstype" -v dev="$loop_device" '$2 == want && $1 != dev { print $1; exit }'
}

find_partition_by_label() {
    loop_device=$1
    label=$2
    lsblk -rnpo NAME,LABEL,PARTLABEL "$loop_device" | awk -v want="$label" '$2 == want || $3 == want { print $1; exit }'
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
    fallback=$(list_child_partitions "$block_device" | tail -n 1 || true)
    if [ -n "$fallback" ] && [ -b "$fallback" ]; then
        printf '%s\n' "$fallback"
    fi
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

find_storage_partition() {
    block_device=$1
    find_partition_by_label "$block_device" storage || true
}

unmount_block_device_tree() {
    block_device=$1
    {
        findmnt -rn -S "$block_device" -o TARGET 2>/dev/null || true
        lsblk -rnpo MOUNTPOINTS "$block_device" | awk 'NF { print }' || true
        for partition in $(list_child_partitions "$block_device"); do
            findmnt -rn -S "$partition" -o TARGET 2>/dev/null || true
            lsblk -rnpo MOUNTPOINTS "$partition" | awk 'NF { print }' || true
        done
    } | awk 'NF && !seen[$0]++' | while IFS= read -r mounted_at; do
        sudo umount "$mounted_at" 2>/dev/null || true
    done
}

create_storage_partition_on_device() {
    block_device=$1
    root_size_gib=$2

    root_partition=$(find_root_partition "$block_device")
    [ -n "$root_partition" ] || {
        echo "Could not find root partition on $block_device" >&2
        exit 1
    }

    storage_partition=$(find_storage_partition "$block_device" || true)
    if [ -n "$storage_partition" ]; then
        storage_part_num=$(partition_number "$storage_partition")
        sudo umount "$storage_partition" 2>/dev/null || true
        sudo parted -s "$block_device" rm "$storage_part_num"
        sudo partprobe "$block_device" 2>/dev/null || true
        sleep 2
    fi

    root_part_num=$(partition_number "$root_partition")
    sudo parted -s "$block_device" resizepart "$root_part_num" "${root_size_gib}GiB"
    sudo partprobe "$block_device" 2>/dev/null || true
    sleep 2

    # Leave the ext4 filesystem resize for first boot on the Pi.
    # Newer Raspberry Pi OS images can enable ext4 features that older
    # host-side e2fsprogs builds do not understand, but expanding the
    # partition boundary itself is enough for the device-side resize2fs step.
    root_partition=$(find_root_partition "$block_device")
    [ -n "$root_partition" ] || {
        echo "Could not re-detect root partition on $block_device after resizepart" >&2
        exit 1
    }

    sudo parted -s "$block_device" mkpart primary ext4 "${root_size_gib}GiB" 100%
    sudo partprobe "$block_device" 2>/dev/null || true
    sleep 2

    storage_partition=$(find_storage_partition "$block_device" || true)
    if [ -z "$storage_partition" ]; then
        storage_partition=$(lsblk -rnpo NAME "$block_device" | tail -n 1)
    fi
    sudo mkfs.ext4 -F -L storage "$storage_partition" >/dev/null
}

mount_image_partitions() {
    block_device=$1
    mount_root=$2

    root_partition=$(find_root_partition "$block_device")
    boot_partition=$(find_boot_partition "$block_device" || true)
    storage_partition=$(find_storage_partition "$block_device" || true)

    [ -n "$root_partition" ] || {
        echo "Could not find root partition on $block_device" >&2
        exit 1
    }

    root_mount=$mount_root/root
    boot_mount=$mount_root/boot
    sudo mkdir -p "$root_mount"
    sudo mount "$root_partition" "$root_mount"

    if [ -n "$boot_partition" ]; then
        sudo mkdir -p "$boot_mount"
        sudo mount "$boot_partition" "$boot_mount"
    fi

    if [ -n "$storage_partition" ]; then
        storage_mount=$root_mount/home/unlim8ted
        sudo mkdir -p "$storage_mount"
        sudo mount "$storage_partition" "$storage_mount"
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

apply_overlay() {
    root_mount=$1
    boot_mount=$2

    sudo rsync -a --exclude '/boot' "$UNLIM8TED_OVERLAY_DIR/" "$root_mount/"
    if [ -d "$UNLIM8TED_OVERLAY_DIR/boot" ] && [ -n "$boot_mount" ] && [ -d "$boot_mount" ]; then
        sudo rsync -rt --no-owner --no-group --no-perms "$UNLIM8TED_OVERLAY_DIR/boot/" "$boot_mount/"
    fi
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
            *" $flag "*) ;;
            *) next="$next $flag" ;;
        esac
    done
    if [ "$next" != "$current" ]; then
        printf '%s\n' "$next" | sudo tee "$cmdline_path" >/dev/null
    fi
}

configure_tty1_firstboot_login() {
    root_mount=$1

    sudo mkdir -p "$root_mount/root"
    if [ -f "$root_mount/root/.profile" ] && [ ! -f "$root_mount/root/.bash_profile" ]; then
        cat <<'EOF' | sudo tee "$root_mount/root/.bash_profile" >/dev/null
if [ -f /root/.profile ]; then
    . /root/.profile
fi
EOF
    fi

    shadow_path=$root_mount/etc/shadow
    if [ -f "$shadow_path" ]; then
        sudo awk -F: 'BEGIN { OFS=FS }
            $1 == "root" {
                if ($2 ~ /^[!*]/) {
                    $2 = ""
                }
            }
            { print }
        ' "$shadow_path" | sudo tee "$shadow_path.tmp" >/dev/null
        sudo mv "$shadow_path.tmp" "$shadow_path"
        sudo chmod 600 "$shadow_path"
    fi

    passwd_path=$root_mount/etc/passwd
    if [ -f "$passwd_path" ]; then
        sudo awk -F: 'BEGIN { OFS=FS }
            $1 == "root" {
                if ($7 == "" || $7 == "/usr/sbin/nologin" || $7 == "/sbin/nologin") {
                    $7 = "/bin/bash"
                }
            }
            { print }
        ' "$passwd_path" | sudo tee "$passwd_path.tmp" >/dev/null
        sudo mv "$passwd_path.tmp" "$passwd_path"
        sudo chmod 644 "$passwd_path"
    fi
}

configure_raspberry_pi_bootstrap() {
    root_mount=$1
    boot_mount=$2

    for firstrun_path in "$boot_mount/firstrun.sh" "$boot_mount/firmware/firstrun.sh"; do
        if [ -n "$boot_mount" ] && [ -f "$firstrun_path" ]; then
            sudo rm -f "$firstrun_path"
        fi
    done

    cmdline_path=
    for candidate in "$boot_mount/cmdline.txt" "$boot_mount/firmware/cmdline.txt"; do
        if [ -f "$candidate" ]; then
            cmdline_path=$candidate
            break
        fi
    done
    if [ -n "$cmdline_path" ]; then
        current_cmdline=$(sudo sed -n '1p' "$cmdline_path")
        sanitized_cmdline=$(printf '%s\n' "$current_cmdline" | awk '
            {
                for (i = 1; i <= NF; i++) {
                    token = $i
                    if (token ~ /^systemd\.run=/) {
                        continue
                    }
                    if (token ~ /^systemd\.run_success_action=/) {
                        continue
                    }
                    if (token ~ /^init=.*firstboot/) {
                        continue
                    }
                    kept[++count] = token
                }
            }
            END {
                for (i = 1; i <= count; i++) {
                    printf "%s%s", kept[i], (i < count ? " " : "\n")
                }
            }
        ')
        if [ -n "$sanitized_cmdline" ] && [ "$sanitized_cmdline" != "$current_cmdline" ]; then
            printf '%s\n' "$sanitized_cmdline" | sudo tee "$cmdline_path" >/dev/null
        fi
    fi

    sudo mkdir -p "$root_mount/etc/systemd/system"
    sudo ln -sfn /dev/null "$root_mount/etc/systemd/system/systemd-firstboot.service"
    sudo rm -f "$root_mount/etc/systemd/system/userconfig.service"

    sudo ln -sfn /lib/systemd/system/multi-user.target "$root_mount/etc/systemd/system/default.target"
}

setup_storage_mount() {
    root_mount=$1

    sudo mkdir -p "$root_mount/var/lib/unlim8ted" "$root_mount/home/unlim8ted"
    sudo mkdir -p "$root_mount/home/unlim8ted/Files" "$root_mount/home/unlim8ted/Downloads" "$root_mount/home/unlim8ted/Pictures/Captures" "$root_mount/home/unlim8ted/Videos" "$root_mount/home/unlim8ted/Music"

    if ! grep -q 'LABEL=storage[[:space:]]/home/unlim8ted' "$root_mount/etc/fstab" 2>/dev/null; then
        cat <<'EOF' | sudo tee -a "$root_mount/etc/fstab" >/dev/null
LABEL=storage /home/unlim8ted ext4 defaults,nofail,x-systemd.device-timeout=10 0 2
EOF
    fi
}

write_boot_userconf() {
    boot_mount=$1
    username=$2
    password=$3

    case "$username" in
        "" | *[!A-Za-z0-9_-]*)
            echo "Invalid default username: $username" >&2
            exit 1
            ;;
    esac

    [ -n "$boot_mount" ] || {
        echo "Boot partition is required to seed userconf.txt" >&2
        exit 1
    }

    password_hash=$(printf '%s' "$password" | openssl passwd -6 -stdin)
    printf '%s:%s\n' "$username" "$password_hash" | sudo tee "$boot_mount/userconf.txt" >/dev/null
}

write_firstboot_env() {
    root_mount=$1
    package_list=$2
    wifi_ssid=$3
    wifi_password=$4
    wifi_country=$5
    keyboard_layout=$6

    sudo mkdir -p "$root_mount/etc/default"
    {
        printf 'UNLIM8TED_FIRSTBOOT_PACKAGES=%s\n' "$(shell_quote "$package_list")"
        printf 'WIFI_COUNTRY=%s\n' "$(shell_quote "$wifi_country")"
        printf 'KEYBOARD_LAYOUT=%s\n' "$(shell_quote "$keyboard_layout")"
        printf 'KEYBOARD_MODEL=%s\n' "$(shell_quote 'pc105')"
        if [ -n "$wifi_ssid" ]; then
            printf 'UNLIM8TED_FIRSTBOOT_WIFI_SSID=%s\n' "$(shell_quote "$wifi_ssid")"
            printf 'UNLIM8TED_FIRSTBOOT_WIFI_PASSWORD=%s\n' "$(shell_quote "$wifi_password")"
        fi
    } | sudo tee "$root_mount/etc/default/unlim8ted-firstboot" >/dev/null
}

require_block_device() {
    device=$1
    case "$device" in
        /dev/*) ;;
        *)
            echo "Expected a /dev/... block device, got: $device" >&2
            exit 1
            ;;
    esac
    [ -b "$device" ] || {
        echo "Not a block device: $device" >&2
        exit 1
    }
}

list_devices() {
    sanitize_path
    require_linux_host
    require_command lsblk
    echo "Linux block devices:"
    lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,PARTLABEL,MODEL,VENDOR,SERIAL,TRAN,MOUNTPOINTS
}

usage() {
    cat >&2 <<EOF
Usage:
  bash os/build.sh deferred --device /dev/sdX [--root-size-mib N | --root-size-gib N] [--wifi-ssid NAME --wifi-password PASS --wifi-country CC]
  bash os/build.sh list-devices

This script now does one thing only:
- flash the pinned Raspberry Pi OS Lite base image
- resize rootfs for deferred install
- create the storage partition
- apply the Unlim8ted overlay
- boot into tty1 root autologin
- install packages on first boot after network is available
EOF
    exit 1
}

run_deferred_cm4() {
    device=
    root_size_mib=$UNLIM8TED_CM4_ROOT_SIZE_MIB
    wifi_ssid=
    wifi_password=
    wifi_country=${WIFI_COUNTRY:-US}
    keyboard_layout=

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --device)
                device=${2:-}
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
            --wifi-ssid)
                wifi_ssid=${2:-}
                shift 2
                ;;
            --wifi-password)
                wifi_password=${2:-}
                shift 2
                ;;
            --wifi-country)
                wifi_country=${2:-}
                shift 2
                ;;
            *)
                usage
                ;;
        esac
    done

    [ -n "$device" ] || usage
    require_block_device "$device"
    case "$root_size_mib" in
        *[!0-9]* | "")
            echo "--root-size-mib must be a positive integer." >&2
            exit 1
            ;;
    esac
    root_size_gib=$(((root_size_mib + 1023) / 1024))

    if [ -t 0 ]; then
        wifi_country_input=$(prompt "Wi-Fi country [$wifi_country]: ")
        if [ -n "$wifi_country_input" ]; then
            wifi_country=$wifi_country_input
        fi

        if [ -z "$wifi_ssid" ]; then
            wifi_ssid=$(prompt "Optional Wi-Fi SSID for first boot [leave blank to skip]: ")
            if [ -n "$wifi_ssid" ]; then
                wifi_password=$(prompt_secret "Optional Wi-Fi password [leave blank for open network]: ")
            fi
        fi
    fi
    keyboard_layout=$(keyboard_layout_for_country "$wifi_country")

    echo "About to erase $device and prepare a deferred first-boot image." >&2
    echo "Rootfs target size: ${root_size_gib}GiB. Remaining space becomes /home/unlim8ted." >&2
    confirm=$(prompt "Type FLASH to continue: ")
    [ "$confirm" = "FLASH" ] || {
        echo "Cancelled." >&2
        exit 1
    }

    sanitize_path
    ensure_prerequisites

    source_image=$(get_base_image)
    mount_root=$UNLIM8TED_BUILD_DIR/mount-cm4-deferred
    root_mount=
    boot_mount=

    cleanup() {
        set +e
        if [ -n "$root_mount" ]; then
            unmount_image_partitions "$root_mount" "$boot_mount"
        fi
        sudo rm -rf "$mount_root"
    }
    trap cleanup EXIT INT TERM

    unmount_block_device_tree "$device"
    echo "Flashing base image to $device..." >&2
    sudo dd if="$source_image" of="$device" bs=16M conv=fsync status=progress
    sync
    sudo partprobe "$device" 2>/dev/null || true
    sleep 3

    echo "Resizing partitions on $device..." >&2
    create_storage_partition_on_device "$device" "$root_size_gib"
    unmount_block_device_tree "$device"

    sudo rm -rf "$mount_root"
    mounts=$(mount_image_partitions "$device" "$mount_root")
    root_mount=$(printf '%s\n' "$mounts" | sed -n '1p')
    boot_mount=$(printf '%s\n' "$mounts" | sed -n '2p')

    if mountpoint -q "$root_mount/home/unlim8ted"; then
        sudo umount "$root_mount/home/unlim8ted"
    fi

    apply_overlay "$root_mount" "$boot_mount"
    configure_raspberry_pi_bootstrap "$root_mount" "$boot_mount"
    configure_boot_splash "$boot_mount"
    configure_tty1_firstboot_login "$root_mount"
    setup_storage_mount "$root_mount"
    write_boot_userconf "$boot_mount" "$UNLIM8TED_DEFAULT_USER" "$UNLIM8TED_DEFAULT_PASSWORD"

    sudo install -m 0755 "$UNLIM8TED_OVERLAY_DIR/opt/unlim8ted/bin/firstboot-install.sh" "$root_mount/opt/unlim8ted/bin/firstboot-install.sh"
    write_firstboot_env "$root_mount" "$UNLIM8TED_CM4_PACKAGES" "$wifi_ssid" "$wifi_password" "$wifi_country" "$keyboard_layout"

    sudo mkdir -p "$root_mount/etc/systemd/system/multi-user.target.wants"
    sudo rm -f "$root_mount/etc/systemd/system/multi-user.target.wants/unlim8ted.service"
    sudo ln -sfn /etc/systemd/system/unlim8ted-firstboot-install.service "$root_mount/etc/systemd/system/multi-user.target.wants/unlim8ted-firstboot-install.service"
    sudo rm -f "$root_mount/var/lib/unlim8ted/packages-installed"

    unmount_image_partitions "$root_mount" "$boot_mount"
    root_mount=
    boot_mount=
    sync

    echo "Deferred CM4 image complete on $device"
    echo "Boot it. tty1 should autologin as root, firstboot-install.sh should run, and kiosk should start after packages finish."
}

main() {
    command_name=${1:-}
    if [ $# -gt 0 ]; then
        shift
    fi

    case "$command_name" in
        deferred)
            run_deferred_cm4 "$@"
            ;;
        list-devices)
            list_devices
            ;;
        "")
            usage
            ;;
        *)
            usage
            ;;
    esac
}

main "$@"
