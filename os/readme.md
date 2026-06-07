# Unlim8ted OS

This directory now builds Unlim8ted OS by customizing official upstream Linux images instead of compiling a full Buildroot system from source.

## Structure

- `overlay/` holds the files copied into the target image, including `/etc`, `/opt`, and the Raspberry Pi boot configuration tracked in this repo.
- `build.sh` is the main build entrypoint for the deferred CM4 provisioning flow.
- `reapply-overlay.sh` reapplies the current overlay to an existing CM4 card without reflashing the base image.
- `build/` receives the finished artifacts after each build.

## Base Images

- CM4 now defaults to the official Raspberry Pi OS Lite 64-bit image `2026-04-21-raspios-trixie-arm64-lite.img.xz`. This is the April 21, 2026 Raspberry Pi OS Lite release for Raspberry Pi 4 / CM4 class hardware.
- `x86_64` uses the official Debian 12 amd64 generic cloud image. That keeps Chromium available as a normal apt package and is straightforward to boot under QEMU or other desktop virtualization.

## Included software

Both targets install kiosk-oriented packages with `apt`, then apply the repo overlay:

- `systemd` from the base image
- `python3`
- `Chromium`
- Bluetooth support
- Wi-Fi support
- Xorg and `xinit`
- `openbox`

The overlay still provides the kiosk startup path:

- `etc/systemd/system/getty@tty1.service.d/autologin.conf` skips the tty1 login prompt.
- `etc/systemd/system/unlim8ted.service` starts X with `xinit`.
- `opt/unlim8ted/bin/kiosk-session.sh` starts the backend, and the backend launches Chromium in app mode.

## Requirements

Run `build.sh` from a Linux shell, including WSL.

Required host tools:

- `sudo`
- `curl`
- `losetup`
- `mount`
- `parted`
- `resize2fs`
- `e2fsck`
- `rsync`
- `unzip`
- `xz-utils`

Additional requirement for CM4 DSI1 boot overlay generation:

- `p7zip-full`
- `device-tree-compiler`

Additional requirement when building the default CM4 image on an `x86_64` host:

- `qemu-arm-static`

The build script flashes the base image, resizes partitions, applies the overlay, seeds first-boot settings, and enables the first-boot installer.

## CM4 Card Layout

Default Unlim8ted card partitions:

- `3 - storage ext4` is the user storage partition for files, downloads, pictures, videos, music, and captures.
- `2 - rootfs ext4` is the OS filesystem with `/opt/unlim8ted`.
- `1 - bootfs FAT` is the Raspberry Pi boot partition.

The boot files must be on the real FAT `bootfs` partition. An empty `rootfs\boot\firmware` directory is normal when `bootfs` is not mounted there.

For the Waveshare DSI1 + double-camera CM4 setup, `build.sh` can optionally install `dt-blob.bin` into `bootfs`. By default it builds that file from Waveshare's `dt-blob-disp1-double_cam.dts`, which can affect camera and HDMI behavior. The build script does not copy `.dts` files into `bootfs`; set `UNLIM8TED_CM4_DSI1_DT_BLOB=1` to enable `dt-blob.bin` generation, or place a prebuilt `overlay/boot/dt-blob.bin` in the repo to override the generated path.

The tracked boot overlay also forces `dtoverlay=dwc2,dr_mode=host` so USB input devices enumerate in host mode during CM4 testing.

## Build Script

Common commands:

```sh
# Show disks before selecting a target.
bash os/build.sh list-devices

# Deferred CM4 build: flash the pinned stock OS, resize rootfs, apply overlay, install packages on first boot.
bash os/build.sh deferred --device /dev/sdi

# Override the deferred CM4 rootfs target size.
bash os/build.sh deferred --device /dev/sdi --root-size-mib 9728

# Seed first-boot Wi-Fi credentials during a deferred build.
bash os/build.sh deferred --device /dev/sdi --wifi-ssid "MyWiFi" --wifi-password "secret" --wifi-country US

# Reapply the current overlay to an already-flashed CM4 card.
sh os/reapply-overlay.sh /dev/sdi
```

Deferred CM4 builds flash the pinned stock Raspberry Pi OS Lite image directly to the selected device, expand `rootfs` to 10GiB by default, create `LABEL=storage` from the remaining space, apply the overlay, and skip host-side package installation. If the build is running interactively, the script asks for the Wi-Fi country first, defaulting to `US`, then optionally asks for an SSID/password and writes those settings into the first-boot environment file.

On first boot:

- the image autologins root on `tty1`
- `firstboot-install.sh` waits indefinitely for network input if needed
- package installation runs on the CM4
- on success, `unlim8ted.service` starts the kiosk
- on failure, the script drops into an interactive recovery shell on `tty1`

If you land in the recovery shell and the system is otherwise ready, you may only need to type `reboot`.

Default credentials seeded into the image:

- username: `unlim8ted`
- password: `unlim8ted`

The `storage` partition is mounted at `/home/unlim8ted` and is used for user files, downloads, pictures, videos, music, and captures.

Optional environment variables:

- `UNLIM8TED_WORK_DIR=...` sets the build work/cache directory.
- `UNLIM8TED_BASE_IMAGE_DIR=...` sets the base image cache directory.
- `UNLIM8TED_CM4_PACKAGES=...` overrides the apt package list for CM4.
- `UNLIM8TED_DEFAULT_USER=...` overrides the seeded default username.
- `UNLIM8TED_DEFAULT_PASSWORD=...` overrides the seeded default password.

## Notes

- The build is now much faster than a full Buildroot desktop stack because it reuses prebuilt distro packages.
- You still keep the repo-managed overlay and boot config.
