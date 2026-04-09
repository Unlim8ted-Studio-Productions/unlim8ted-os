#!/bin/sh
set -eu

export DISPLAY="${UNLIM8TED_DISPLAY:-:0}"
export XAUTHORITY="${UNLIM8TED_XAUTHORITY:-/root/.Xauthority}"

if command -v xset >/dev/null 2>&1; then
    xset -dpms
    xset s off
    xset s noblank
fi

if command -v openbox >/dev/null 2>&1; then
    openbox >/tmp/unlim8ted-openbox.log 2>&1 &
fi

exec /usr/bin/python3 /opt/unlim8ted/backend/main.py
