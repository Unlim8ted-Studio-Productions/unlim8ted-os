#!/bin/sh
set -eu

if [ -f /etc/default/unlim8ted ]; then
    # shellcheck disable=SC1091
    . /etc/default/unlim8ted
fi

if [ "${UNLIM8TED_PLATFORM_AUTO_INSTALL:-0}" = "1" ] && [ -x /opt/unlim8ted/bin/install-platform.sh ]; then
    /opt/unlim8ted/bin/install-platform.sh auto || true
fi

exec /usr/bin/python3 /opt/unlim8ted/backend/main.py
