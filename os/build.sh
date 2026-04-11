#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

prompt() {
    printf '%s' "$1" >&2
    read -r REPLY
    printf '%s\n' "$REPLY"
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "Missing required command: $1" >&2
        exit 1
    }
}

is_wsl() {
    grep -qi microsoft /proc/version 2>/dev/null
}

select_target() {
    echo "Select target:"
    echo "  1) x86_64 test image"
    echo "  2) arm64 CM4 image"
    choice=$(prompt "Target [1-2]: ")

    case "$choice" in
        1)
            TARGET_SCRIPT="$SCRIPT_DIR/build-x86_64.sh"
            TARGET_NAME="x86_64"
            ;;
        2)
            TARGET_SCRIPT="$SCRIPT_DIR/build-cm4.sh"
            TARGET_NAME="cm4"
            ;;
        *)
            echo "Invalid target: $choice" >&2
            exit 1
            ;;
    esac
}

format_and_mount_external_cache() {
    require_command lsblk
    require_command mkfs.ext4
    require_command mount
    require_command umount
    require_command sudo

    echo
    echo "Available block devices:"
    lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINTS
    echo
    echo "External cache mode formats the selected device or partition as ext4."
    echo "This destroys all data on that device."
    echo "Examples: /dev/sdb or /dev/sdb1"
    device=$(prompt "Device to format: ")

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

    echo
    echo "DANGER: $device will be formatted as ext4."
    echo "Type FORMAT to continue."
    confirm=$(prompt "Confirmation: ")
    if [ "$confirm" != "FORMAT" ]; then
        echo "Aborted." >&2
        exit 1
    fi

    mount_dir=$(prompt "Mount point [/mnt/unlim8ted-build-cache]: ")
    if [ -z "$mount_dir" ]; then
        mount_dir=/mnt/unlim8ted-build-cache
    fi

    sudo umount "$device" 2>/dev/null || true
    sudo mkfs.ext4 -F -L UNLIM8TED_BUILD "$device"
    sudo mkdir -p "$mount_dir"
    sudo mount "$device" "$mount_dir"
    sudo mkdir -p "$mount_dir/work" "$mount_dir/base-images"
    sudo chown -R "$(id -u):$(id -g)" "$mount_dir"

    UNLIM8TED_WORK_DIR="$mount_dir/work"
    UNLIM8TED_BASE_IMAGE_DIR="$mount_dir/base-images"
    export UNLIM8TED_WORK_DIR UNLIM8TED_BASE_IMAGE_DIR
}

select_cache_location() {
    echo
    if is_wsl; then
        echo "Select cache/work location:"
        echo "  1) WSL Linux cache at ~/.cache/unlim8ted-os-build"
        echo "  2) External drive or partition, formatted as ext4"
        choice=$(prompt "Cache option [1-2]: ")

        case "$choice" in
            1)
                UNLIM8TED_WORK_DIR="${HOME:-/tmp}/.cache/unlim8ted-os-build"
                export UNLIM8TED_WORK_DIR
                ;;
            2)
                format_and_mount_external_cache
                ;;
            *)
                echo "Invalid cache option: $choice" >&2
                exit 1
                ;;
        esac
    else
        echo "Select cache/work location:"
        echo "  1) Default repo-local build directory"
        echo "  2) External drive or partition, formatted as ext4"
        choice=$(prompt "Cache option [1-2]: ")

        case "$choice" in
            1)
                UNLIM8TED_WORK_DIR="$SCRIPT_DIR/build"
                export UNLIM8TED_WORK_DIR
                ;;
            2)
                format_and_mount_external_cache
                ;;
            *)
                echo "Invalid cache option: $choice" >&2
                exit 1
                ;;
        esac
    fi
}

select_image_growth() {
    echo
    grow_mb=$(prompt "Extra image size in MiB [0]: ")
    if [ -z "$grow_mb" ]; then
        grow_mb=0
    fi

    case "$grow_mb" in
        *[!0-9]*)
            echo "Extra image size must be a non-negative integer." >&2
            exit 1
            ;;
    esac

    UNLIM8TED_IMAGE_GROW_MB="$grow_mb"
    export UNLIM8TED_IMAGE_GROW_MB
}

main() {
    if [ "$(uname -s)" != "Linux" ]; then
        echo "Run this script from Linux or WSL." >&2
        exit 1
    fi

    if [ "$(id -u)" -eq 0 ]; then
        echo "Do not run this wrapper with sudo. It will ask for sudo only when needed." >&2
        exit 1
    fi

    select_target
    select_cache_location
    select_image_growth

    echo
    echo "Build summary:"
    echo "  Target: $TARGET_NAME"
    echo "  Work/cache: ${UNLIM8TED_WORK_DIR:-default}"
    echo "  Base-image cache: ${UNLIM8TED_BASE_IMAGE_DIR:-default}"
    echo "  Extra image MiB: $UNLIM8TED_IMAGE_GROW_MB"
    echo

    confirm=$(prompt "Start build? [y/N]: ")
    case "$confirm" in
        y | Y | yes | YES)
            ;;
        *)
            echo "Aborted." >&2
            exit 1
            ;;
    esac

    bash "$TARGET_SCRIPT"
}

main "$@"
