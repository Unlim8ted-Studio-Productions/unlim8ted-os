# Unlim8ted OS

`os/` now contains the overlay, Buildroot metadata, build scripts, and generated artifacts for Unlim8ted OS.

## Layout

- `overlay/` is the filesystem overlay copied onto the built rootfs. It contains the existing `/boot`, `/etc`, and `/opt` payload.
- `build/` is reserved for generated outputs. Scripts place per-target Buildroot outputs and final ISO artifacts here.
- `build-config.env` defines shared Buildroot source, output, and artifact naming defaults.
- `build-x86_64.sh` builds the generic `x86_64` image path.
- `build-cm4.sh` builds the Raspberry Pi CM4 image path.
- `buildroot-external/` is the Buildroot external tree with board hooks and target config fragments.

## Targets

### x86_64

The `x86_64` target is intended for a minimal kiosk-style Linux image that includes:

- `systemd`
- Wi-Fi support
- Bluetooth support
- `chromium`
- `libcamera`
- `python3`
- the Unlim8ted overlay and kiosk service

The build script tries to preserve a bootable ISO if Buildroot generates one. If the selected Buildroot configuration does not emit a native bootable ISO, the script still emits an ISO artifact that bundles the generated image set.

### Raspberry Pi CM4

The CM4 target builds from the Raspberry Pi 4 64-bit Buildroot baseline and layers the Unlim8ted overlay on top. Because Raspberry Pi firmware boots from a raw disk image rather than ISO9660 media, the CM4 script emits an ISO transport artifact containing the produced `sdcard.img`, boot overlay files, and metadata. The flashable medium remains the raw image inside that ISO bundle.

## Usage

Run from a Linux shell with Buildroot host dependencies installed:

```sh
cd os
sh ./build-x86_64.sh
sh ./build-cm4.sh
```

Outputs land under:

- `build/x86_64/`
- `build/cm4/`

## Overlay Notes

The overlay keeps the existing behavior:

- `/etc/default/unlim8ted` carries runtime environment overrides.
- `/etc/systemd/system/getty@tty1.service.d/autologin.conf` skips the TTY login prompt.
- `/etc/systemd/system/unlim8ted.service` now starts an X11 kiosk session directly with `xinit`.
- `/opt/unlim8ted/bin/kiosk-session.sh` launches the Python backend inside the kiosk session, which in turn starts Chromium in app mode.

## Current Limitation

The CM4 boot firmware overlay under `overlay/boot/firmware/` is bundled into the CM4 output ISO and copied into the Buildroot image staging flow, but the exact final boot partition layout still depends on the selected Buildroot Raspberry Pi image recipe. That path should be validated on real CM4 hardware before treating the image as production-ready.
