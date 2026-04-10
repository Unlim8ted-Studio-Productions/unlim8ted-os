#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=./build-common.sh
. "$SCRIPT_DIR/build-common.sh"

build_target \
    "x86_64" \
    "x86_64" \
    "$UNLIM8TED_X86_64_IMAGE_URL" \
    "$UNLIM8TED_X86_64_ARCHIVE_NAME" \
    "$UNLIM8TED_X86_64_PACKAGES" \
    "unlim8ted-x86_64.img"
