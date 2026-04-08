#!/bin/sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

normalize_arch() {
    case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
        x86_64|amd64|x64) printf '%s\n' x86_64 ;;
        aarch64|arm64|armv8|armv8l) printf '%s\n' arm64 ;;
        *) printf '%s\n' "$1" ;;
    esac
}

TARGET_ARCH="${TARGET_ARCH:-$(uname -m 2>/dev/null || echo unknown)}"
TARGET_ARCH="$(normalize_arch "$TARGET_ARCH")"

case "$TARGET_ARCH" in
    x86_64)
        exec "$SCRIPT_DIR/build-pc-iso.sh" "$@"
        ;;
    arm64)
        exec "$SCRIPT_DIR/stage-generic-arm64-image.sh" "$@"
        ;;
    *)
        printf 'unsupported TARGET_ARCH: %s\n' "$TARGET_ARCH" >&2
        exit 1
        ;;
esac
