#!/bin/sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
TARGET_ARCH="${TARGET_ARCH:-$(uname -m 2>/dev/null || echo unknown)}"

normalize_arch() {
    case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
        x86_64|amd64|x64) printf '%s\n' x86_64 ;;
        aarch64|arm64|armv8|armv8l) printf '%s\n' arm64 ;;
        *) printf '%s\n' "$1" ;;
    esac
}

TARGET_ARCH="$(normalize_arch "$TARGET_ARCH")"

case "$TARGET_ARCH" in
    arm64)
        exec "$SCRIPT_DIR/build-kernel-arm64-cm4.sh"
        ;;
    x86_64)
        exec "$SCRIPT_DIR/build-kernel-x86_64.sh"
        ;;
    *)
        printf 'unsupported TARGET_ARCH for kernel build: %s\n' "$TARGET_ARCH" >&2
        exit 1
        ;;
esac
