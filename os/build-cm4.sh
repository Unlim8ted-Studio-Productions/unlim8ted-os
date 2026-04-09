#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=./build-common.sh
. "$SCRIPT_DIR/build-common.sh"

build_target \
    "cm4" \
    "raspberrypi4_64_defconfig" \
    "$UNLIM8TED_EXTERNAL_DIR/configs/unlim8ted_cm4.fragment" \
    "unlim8ted-cm4.iso"
