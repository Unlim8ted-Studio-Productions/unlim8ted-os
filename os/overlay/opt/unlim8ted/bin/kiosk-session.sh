#!/bin/sh
set -eu

export DISPLAY="${UNLIM8TED_DISPLAY:-:0}"
export XAUTHORITY="${UNLIM8TED_XAUTHORITY:-/root/.Xauthority}"

echo "[kiosk-session] X session started on ${DISPLAY}" >&2

if command -v xset >/dev/null 2>&1; then
    xset -dpms >/tmp/unlim8ted-xset.log 2>&1 || true
    xset s off >>/tmp/unlim8ted-xset.log 2>&1 || true
    xset s noblank >>/tmp/unlim8ted-xset.log 2>&1 || true
fi

if command -v openbox >/dev/null 2>&1; then
    openbox >/tmp/unlim8ted-openbox.log 2>&1 &
fi

sleep "${UNLIM8TED_KIOSK_START_DELAY:-1}"

exec /usr/bin/python3 -u /opt/unlim8ted/backend/main.py
