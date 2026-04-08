#!/bin/sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
UNLIM8TED_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
ARCH="${1:-$(uname -m 2>/dev/null || echo unknown)}"
OUTPUT="${2:-$UNLIM8TED_ROOT/share/build/rootfs-manifest.env}"

normalize_arch() {
    case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
        x86_64|amd64|x64) printf '%s\n' x86_64 ;;
        aarch64|arm64|armv8|armv8l) printf '%s\n' arm64 ;;
        armv7|armv7l|armv6l|arm) printf '%s\n' arm ;;
        i386|i486|i586|i686|x86) printf '%s\n' x86 ;;
        *) printf '%s\n' "$1" ;;
    esac
}

ARCH="$(normalize_arch "$ARCH")"
BOOT_TARGET="pc"
if [ "$ARCH" = "arm64" ] || [ "$ARCH" = "arm" ]; then
    BOOT_TARGET="generic-arm"
fi

mkdir -p "$(dirname "$OUTPUT")"
cat > "$OUTPUT" <<EOF
UNLIM8TED_ARCH=$ARCH
UNLIM8TED_BOOT_TARGET=$BOOT_TARGET
UNLIM8TED_SERVICE_PATH=/etc/systemd/system/unlim8ted.service
UNLIM8TED_ENV_PATH=/etc/default/unlim8ted
UNLIM8TED_INSTALL_ROOT=/opt/unlim8ted
EOF

printf '[unlim8ted] wrote manifest: %s\n' "$OUTPUT"
