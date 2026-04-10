#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=./build-common.sh
. "$SCRIPT_DIR/build-common.sh"

build_target \
    "cm4" \
    "arm64" \
    "$UNLIM8TED_CM4_IMAGE_URL" \
    "$UNLIM8TED_CM4_ARCHIVE_NAME" \
    "$UNLIM8TED_CM4_PACKAGES" \
    "unlim8ted-cm4.img"
