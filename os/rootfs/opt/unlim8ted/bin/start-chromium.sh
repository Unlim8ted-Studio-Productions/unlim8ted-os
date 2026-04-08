#!/bin/sh
set -eu

if [ -f /etc/default/unlim8ted ]; then
    # shellcheck disable=SC1091
    . /etc/default/unlim8ted
fi

BROWSER="${UNLIM8TED_BROWSER:-chromium-browser}"
FLAGS="${UNLIM8TED_CHROMIUM_FLAGS:-}"
DISPLAY_VALUE="${UNLIM8TED_DISPLAY:-:0}"

export DISPLAY="$DISPLAY_VALUE"
if [ -n "${UNLIM8TED_XAUTHORITY:-}" ]; then
    export XAUTHORITY="$UNLIM8TED_XAUTHORITY"
fi

PROFILE_DIR="${UNLIM8TED_CHROMIUM_PROFILE_DIR:-/opt/unlim8ted/state/chromium-profile}"
mkdir -p "$PROFILE_DIR"

exec "$BROWSER" \
    --user-data-dir="$PROFILE_DIR" \
    --app=http://localhost:8080 \
    --window-size=720,1560 \
    --no-sandbox \
    $FLAGS
