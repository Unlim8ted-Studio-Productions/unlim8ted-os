#!/bin/sh
set -eu

export DISPLAY="${UNLIM8TED_DISPLAY:-:0}"
export XAUTHORITY="${UNLIM8TED_XAUTHORITY:-/root/.Xauthority}"

echo "[kiosk-session] X session started on ${DISPLAY}" >&2

wait_for_x() {
    if ! command -v xset >/dev/null 2>&1; then
        return 0
    fi

    attempts=0
    while [ "$attempts" -lt 20 ]; do
        if xset q >/tmp/unlim8ted-xset.log 2>&1; then
            return 0
        fi
        attempts=$((attempts + 1))
        sleep 1
    done

    echo "[kiosk-session] X display ${DISPLAY} did not become ready for xset" >&2
    return 1
}

if command -v xset >/dev/null 2>&1; then
    if wait_for_x; then
        xset -dpms >>/tmp/unlim8ted-xset.log 2>&1 || true
        xset s off >>/tmp/unlim8ted-xset.log 2>&1 || true
        xset s noblank >>/tmp/unlim8ted-xset.log 2>&1 || true
    fi
fi

if command -v openbox >/dev/null 2>&1; then
    openbox >/tmp/unlim8ted-openbox.log 2>&1 &
fi

sleep "${UNLIM8TED_KIOSK_START_DELAY:-1}"

exec /usr/bin/python3 -u /opt/unlim8ted/backend/main.py
