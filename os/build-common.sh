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
            *[![:print:]]*)
                changed=1
                continue
                ;;
            *[[:space:]]*)
                changed=1
                continue
                ;;
            "")
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
        echo "Sanitized PATH for Buildroot by dropping entries with whitespace or empty segments." >&2
    fi
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "Missing required command: $1" >&2
        exit 1
    }
}

ensure_buildroot() {
    require_command git
    require_command make

    mkdir -p "$UNLIM8TED_BUILD_DIR" "$UNLIM8TED_ARTIFACT_DIR"

    if [ ! -d "$UNLIM8TED_BUILDROOT_DIR/.git" ]; then
        git clone "$UNLIM8TED_BUILDROOT_REPO" "$UNLIM8TED_BUILDROOT_DIR"
    fi

    git -C "$UNLIM8TED_BUILDROOT_DIR" fetch --tags --force
    git -C "$UNLIM8TED_BUILDROOT_DIR" checkout "$UNLIM8TED_BUILDROOT_REF"
}

apply_fragment() {
    output_dir=$1
    fragment=$2
    merged_config=$output_dir/.config.merged

    awk '
        FNR == NR {
            if ($0 ~ /^BR2_[A-Z0-9_]+=.+$/ || $0 ~ /^# BR2_[A-Z0-9_]+ is not set$/) {
                key = $0
                sub(/^# /, "", key)
                sub(/=.*/, "", key)
                sub(/ is not set$/, "", key)
                drop[key] = 1
            }
            fragment_lines[++fragment_count] = $0
            next
        }
        {
            key = $0
            sub(/^# /, "", key)
            sub(/=.*/, "", key)
            sub(/ is not set$/, "", key)
            if (!(key in drop)) {
                print
            }
        }
        END {
            for (i = 1; i <= fragment_count; i++) {
                print fragment_lines[i]
            }
        }
    ' "$fragment" "$output_dir/.config" > "$merged_config"
    mv "$merged_config" "$output_dir/.config"

    make -C "$UNLIM8TED_BUILDROOT_DIR" \
        O="$output_dir" \
        BR2_EXTERNAL="$UNLIM8TED_EXTERNAL_DIR" \
        olddefconfig
}

stage_iso_contents() {
    target_name=$1
    images_dir=$2
    stage_dir=$3

    rm -rf "$stage_dir"
    mkdir -p "$stage_dir/images"
    cp -a "$images_dir/." "$stage_dir/images/"
    cp -a "$UNLIM8TED_OVERLAY_DIR/boot" "$stage_dir/overlay-boot"

    cat > "$stage_dir/README.txt" <<EOF
Unlim8ted OS artifact bundle for $target_name

Contents:
- images/: Buildroot-generated image files
- overlay-boot/: boot overlay files from the repository

Notes:
- The overlay rootfs content is already applied through BR2_ROOTFS_OVERLAY.
- For Raspberry Pi CM4, the flashable artifact is typically images/sdcard.img.
- The ISO file is used here as a transport bundle for the generated artifacts.
EOF
}

create_iso_bundle() {
    source_dir=$1
    output_iso=$2
    volume_label=$3

    if command -v xorriso >/dev/null 2>&1; then
        xorriso -as mkisofs -R -J -V "$volume_label" -o "$output_iso" "$source_dir" >/dev/null
        return
    fi

    if command -v genisoimage >/dev/null 2>&1; then
        genisoimage -R -J -V "$volume_label" -o "$output_iso" "$source_dir" >/dev/null
        return
    fi

    if command -v mkisofs >/dev/null 2>&1; then
        mkisofs -R -J -V "$volume_label" -o "$output_iso" "$source_dir" >/dev/null
        return
    fi

    echo "Missing ISO creation tool: install xorriso, genisoimage, or mkisofs" >&2
    exit 1
}

collect_artifacts() {
    target_name=$1
    output_dir=$2
    artifact_name=$3

    images_dir="$output_dir/images"
    target_dir="$UNLIM8TED_ARTIFACT_DIR/$target_name"
    stage_dir="$target_dir/iso-stage"
    final_iso="$target_dir/$artifact_name"

    rm -rf "$target_dir"
    mkdir -p "$target_dir"
    cp -a "$images_dir" "$target_dir/images"

    native_iso=$(find "$images_dir" -maxdepth 1 -type f \( -name "*.iso" -o -name "*.iso9660" \) | head -n 1 || true)
    if [ -n "$native_iso" ] && [ "$target_name" = "x86_64" ]; then
        cp "$native_iso" "$final_iso"
        return
    fi

    stage_iso_contents "$target_name" "$images_dir" "$stage_dir"
    create_iso_bundle "$stage_dir" "$final_iso" "UNLIM8TED_${target_name}"
    rm -rf "$stage_dir"
}

build_target() {
    target_name=$1
    base_defconfig=$2
    fragment=$3
    artifact_name=$4

    sanitize_path
    ensure_buildroot

    output_dir="$UNLIM8TED_BUILD_DIR/output-$target_name"
    mkdir -p "$UNLIM8TED_BUILD_DIR" "$UNLIM8TED_ARTIFACT_DIR"

    make -C "$UNLIM8TED_BUILDROOT_DIR" \
        O="$output_dir" \
        BR2_EXTERNAL="$UNLIM8TED_EXTERNAL_DIR" \
        "$base_defconfig"

    apply_fragment "$output_dir" "$fragment"

    make -C "$UNLIM8TED_BUILDROOT_DIR" \
        O="$output_dir" \
        BR2_EXTERNAL="$UNLIM8TED_EXTERNAL_DIR"

    collect_artifacts "$target_name" "$output_dir" "$artifact_name"
}
