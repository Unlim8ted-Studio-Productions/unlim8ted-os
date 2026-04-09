#!/bin/sh
set -eu

TARGET_DIR=$1
TARGET_KIND=${2:-generic}
BINARIES_DIR=${BINARIES_DIR:-}
EXTERNAL_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
OVERLAY_DIR=$(CDPATH= cd -- "$EXTERNAL_DIR/../overlay" && pwd)

mkdir -p "$TARGET_DIR/etc/systemd/system/multi-user.target.wants"
ln -snf ../unlim8ted.service \
    "$TARGET_DIR/etc/systemd/system/multi-user.target.wants/unlim8ted.service"

if [ -n "$BINARIES_DIR" ] && [ "$TARGET_KIND" = "cm4" ] && [ -d "$BINARIES_DIR/rpi-firmware" ]; then
    cp -a "$OVERLAY_DIR/boot/firmware/." "$BINARIES_DIR/rpi-firmware/"
fi
