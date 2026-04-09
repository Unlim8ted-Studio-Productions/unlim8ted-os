#!/bin/sh
set -eu

TARGET_DIR=$1
TARGET_KIND=${2:-generic}

mkdir -p "$TARGET_DIR/etc/systemd/system/multi-user.target.wants"
ln -snf ../unlim8ted.service \
    "$TARGET_DIR/etc/systemd/system/multi-user.target.wants/unlim8ted.service"
