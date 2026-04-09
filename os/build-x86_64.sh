#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=./build-common.sh
. "$SCRIPT_DIR/build-common.sh"

build_target \
    "x86_64" \
    "qemu_x86_64_defconfig" \
    "$UNLIM8TED_EXTERNAL_DIR/configs/unlim8ted_x86_64.fragment" \
    "unlim8ted-x86_64.iso"
