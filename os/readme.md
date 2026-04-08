# Unlim8ted OS Documentation

## Overview

**Unlim8ted OS** is a phone-style Linux environment built around a custom kernel plus a portable userspace tree. The repository is organized around three canonical directories:

- `./build/` for build scripts
- `./rootfs/` for the runtime filesystem tree
- `./bootfs/` for bootloader configuration and built kernel payloads

The same userspace is intended to run on both Raspberry Pi CM4-class `arm64` hardware and regular `x86_64` PCs. Kernel builds are architecture-specific, but the runtime auto-detects the machine and follows the correct boot path.

## Repo Structure

- `./build/build.sh` is the single top-level build entrypoint.
- `./build/build-kernel-arm64-cm4.sh` builds the Raspberry Pi CM4 `arm64` kernel.
- `./build/build-kernel-x86_64.sh` builds the generic `x86_64` PC kernel.
- `./build/install-unlim8ted-kernel-feature.sh` injects the custom Unlim8ted kernel feature into downloaded kernel sources.
- `./rootfs/etc/systemd/system/unlim8ted.service` starts the launcher on boot.
- `./rootfs/etc/default/unlim8ted` contains runtime overrides and Chromium flags.
- `./rootfs/etc/chromium-browser/default` provides Chromium defaults.
- `./rootfs/etc/xdg/autostart/unlim8ted-chromium.desktop` starts Chromium in desktop sessions.
- `./rootfs/opt/unlim8ted/` contains the backend, UI, built-in apps, state, and helper scripts.
- `./bootfs/rpi/config.txt` is the Raspberry Pi firmware boot profile.
- `./bootfs/generic-arm/extlinux/extlinux.conf` is the generic ARM64 boot profile.
- `./bootfs/pc/grub/grub.cfg` is the `x86_64` GRUB boot entry.
- `./bootfs/kernel/` is where built kernel and initramfs payloads land.

## Platform Model

Architecture mapping:

- `aarch64` / `arm64` -> `arm64`
- `amd64` / `x86_64` -> `x86_64`
- Raspberry Pi hardware overrides generic ARM and selects the `rpi` boot target

Boot model:

- Raspberry Pi CM4 uses firmware-driven boot via `config.txt`
- Generic ARM64 uses `extlinux.conf`
- `x86_64` PCs use GRUB and an ISO-oriented boot path

Important architecture constraint:

- Raspberry Pi Compute Module 4 hardware is `arm64`, not `x86_64`
- You can build an `x86_64` kernel for PCs and an `arm64` kernel for CM4 from the same repo
- You cannot boot an `amd64`/`x86_64` kernel natively on CM4 hardware

## Custom Kernel

This repo now includes explicit kernel build scripts and custom kernel modifications.

Two target kernels:

- `arm64` CM4 kernel from the Raspberry Pi Linux tree
- `x86_64` PC kernel from the upstream stable Linux tree

Custom kernel feature:

- the build injects an Unlim8ted identity driver
- built kernels expose `/proc/unlim8ted_identity`

Kernel source locations are configured in `./build/kernel-sources.env`.

Built kernel payload locations:

- `./bootfs/kernel/arm64/Image`
- `./bootfs/kernel/arm64/initramfs-unlim8ted.img`
- `./bootfs/kernel/x86_64/vmlinuz-unlim8ted`
- `./bootfs/kernel/x86_64/initramfs-unlim8ted.img`

## Build Flow

Top-level build:

```bash
TARGET_ARCH=x86_64 ./os/build/build.sh
TARGET_ARCH=arm64 ./os/build/build.sh
```

Kernel-only builds:

```bash
./os/build/build-kernel-x86_64.sh
./os/build/build-kernel-arm64-cm4.sh
```

Outputs:

- `x86_64` -> `./os/build/out/unlim8ted-x86_64.iso`
- `arm64` -> `./os/build/out/arm64/`

WSL note:

- do not build Linux sources under `/mnt/<drive>/...`
- the kernel scripts default to `$HOME/.cache/unlim8ted-kernel-build`

Required Linux build tools:

- `git`
- `make`
- `gcc`
- `flex`
- `bison`
- `perl`
- `bc`
- `libssl-dev`
- `libelf-dev`
- `aarch64-linux-gnu-gcc` for `arm64`
- `grub-mkrescue` and `mksquashfs` for `x86_64` ISO output

## Installation Layout

When deployed to a target system, the important paths are:

- `/etc/default/unlim8ted`
- `/etc/systemd/system/unlim8ted.service`
- `/etc/chromium-browser/default`
- `/etc/xdg/autostart/unlim8ted-chromium.desktop`
- `/opt/unlim8ted/...`

To enable the service on the target system:

```bash
sudo systemctl daemon-reload
sudo chmod +x /opt/unlim8ted/bin/*.sh
sudo systemctl enable unlim8ted.service
sudo systemctl restart unlim8ted.service
```

## Runtime Configuration

Edit `./rootfs/etc/default/unlim8ted` only when auto-detection is wrong:

- `UNLIM8TED_BROWSER` to pin a browser binary
- `UNLIM8TED_DISPLAY` and `UNLIM8TED_XAUTHORITY` for X11 startup
- `UNLIM8TED_WLR_OUTPUT` or `UNLIM8TED_XRANDR_OUTPUT` for display power and brightness helpers
- `UNLIM8TED_BACKLIGHT_PATH` to force a specific sysfs brightness file
- `UNLIM8TED_PLATFORM_AUTO_INSTALL=1` if service startup should refresh the boot target
- `UNLIM8TED_CHROMIUM_FLAGS` to append Chromium runtime flags

## Verification

1. Confirm the kernel and initramfs were built into `./bootfs/kernel/`.
2. Confirm the built kernel exposes `/proc/unlim8ted_identity` after boot.
3. Verify `systemctl status unlim8ted.service`.
4. Check `journalctl -u unlim8ted.service -b`.
5. Verify Chromium launches the Unlim8ted UI locally.
6. Test brightness, sleep/wake, and camera behavior on the real hardware.
