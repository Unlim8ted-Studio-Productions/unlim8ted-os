# Unlim8ted OS

This directory now builds Unlim8ted OS by customizing official upstream Linux images instead of compiling a full Buildroot system from source.

## Structure

- `overlay/` holds the files copied into the target image, including `/etc`, `/opt`, and the Raspberry Pi boot configuration tracked in this repo.
- `build.sh` is the only build entrypoint. It handles image builds, direct CM4 device builds, deferred first-boot installs, overlay reapplies, runtime hotpatches, and repair/continue flows.
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

The build script mounts the image, installs packages with `apt`, copies the overlay, and enables `unlim8ted.service`.

## CM4 Card Layout

Default Unlim8ted card partitions:

- `3 - storage ext4` is the user storage partition for files, downloads, pictures, videos, music, and captures.
- `2 - rootfs ext4` is the OS filesystem with `/opt/unlim8ted`.
- `1 - bootfs FAT` is the Raspberry Pi boot partition.

The boot files must be on the real FAT `bootfs` partition. An empty `rootfs\boot\firmware` directory is normal when `bootfs` is not mounted there.

For the Waveshare DSI1 + double-camera CM4 setup, `build.sh` can optionally install `dt-blob.bin` into `bootfs`. By default it builds that file from Waveshare's `dt-blob-disp1-double_cam.dts`, which can affect camera and HDMI behavior. The build script does not copy `.dts` files into `bootfs`; set `UNLIM8TED_CM4_DSI1_DT_BLOB=1` to enable `dt-blob.bin` generation, or place a prebuilt `overlay/boot/dt-blob.bin` in the repo to override the generated path.

The tracked boot overlay also forces `dtoverlay=dwc2,dr_mode=host` so USB input devices enumerate in host mode during CM4 testing.

## Build Script

Interactive mode:

```sh
cd os
bash ./build.sh
```

The interactive script can run every supported operation:

- `x86_64` test image build
- CM4 image build
- direct CM4 SD/USB build
- deferred CM4 first-boot install build
- full overlay reapply
- runtime hotpatch
- CM4 repair with rootfs resize
- CM4 package continuation without resize
- device listing

Cache/work options for image builds:

- On WSL, use the WSL Linux filesystem cache at `~/.cache/unlim8ted-os-build`, or select an external device/partition.
- On Linux, use the repo-local `build/` directory, or select an external device/partition.
- If you select an external cache device or partition, the script formats it as ext4 after requiring an explicit `FORMAT` confirmation.
- The interactive script automatically runs `sync` and unmounts that external cache device when the build exits.
- You can select an existing mounted folder; this does not format anything.

Common commands:

```sh
# Show disks before selecting a target.
bash os/build.sh list-devices

# Build normal image artifacts.
bash os/build.sh image --arch x86_64 --grow-mb 4096
bash os/build.sh image --arch cm4 --grow-mb 12288

# Build directly onto a CM4 SD/USB device.
bash os/build.sh image --arch cm4 --direct-device /dev/sdi

# Deferred CM4 build: flash the pinned stock OS, resize rootfs, apply overlay, install packages on first boot.
bash os/build.sh deferred --device /dev/sdi

# Override the deferred CM4 rootfs target size.
bash os/build.sh deferred --device /dev/sdi --root-size-mib 9728

# Seed first-boot Wi-Fi credentials during a deferred build.
bash os/build.sh deferred --device /dev/sdi --wifi-ssid "MyWiFi" --wifi-password "secret" --wifi-country US

# Reapply the complete overlay to an existing CM4 card without package installs.
bash os/build.sh overlay --device /dev/sdi

# Copy only the current runtime hotpatch files. Package install: never.
bash os/build.sh hotpatch --device /dev/sdi

# If your partitions are nonstandard, you can map them explicitly.
bash os/build.sh overlay --device /dev/sdi --boot-part /dev/sdi1 --root-part /dev/sdi2 --storage-part /dev/sdi3
bash os/build.sh hotpatch --device /dev/sdi --boot-part /dev/sdi1 --root-part /dev/sdi2 --storage-part /dev/sdi3

# Repair a partially customized CM4 card by resizing rootfs and continuing install.
bash os/build.sh repair --device /dev/sdi --add-mb 8192
bash os/build.sh repair --device /dev/sdi --size-gib 32

# Continue a failed CM4 package install without resizing partitions.
bash os/build.sh continue --device /dev/sdi

# Skip resizing during repair when the layout is already correct.
bash os/build.sh repair --device /dev/sdi --no-resize --boot-part /dev/sdi1 --root-part /dev/sdi2 --storage-part /dev/sdi3
```

Direct CM4 device builds flash Raspberry Pi OS directly to the selected SD/USB device, calculate the OS root partition size from the selected package set plus a 5 GiB buffer, create a separate `storage` partition from the remaining space, then install packages and the overlay on that device. If the selected CM4 device already has `bootfs` and `rootfs` partitions, the script reuses it and continues customization instead of rewriting the base image.

Deferred CM4 builds now flash the pinned stock Raspberry Pi OS Lite image directly to the selected device, expand `rootfs` to 10GiB by default, create `LABEL=storage` from the remaining space, apply the overlay, and skip host-side package installation. If the build is running interactively, the script offers an optional Wi-Fi SSID/password prompt and writes those credentials into the first-boot environment file. On first boot, the autologin root shell on `tty1` uses any build-provided Wi-Fi profile first, then prompts for network access if needed, installs the CM4 package set on the Pi, cleans apt/temp files, enables `unlim8ted.service`, and starts the kiosk.

Overlay and hotpatch modes never install packages:

- `overlay` reapplies the full repo overlay and service setup.
- `hotpatch` copies only selected runtime files used for the current UI/backend/apps/Plymouth updates.

The `storage` partition is mounted at `/home/unlim8ted` and is used for user files, downloads, pictures, videos, music, and captures.

Optional environment variables:

- `UNLIM8TED_WORK_DIR=...` sets the build work/cache directory.
- `UNLIM8TED_BASE_IMAGE_DIR=...` sets the base image cache directory.
- `UNLIM8TED_IMAGE_GROW_MB=512` adds extra space to the image before resizing the root filesystem.
- `UNLIM8TED_CM4_PACKAGES=...` overrides the apt package list for CM4.
- `UNLIM8TED_CM4_DSI1_DT_BLOB=1` enables optional Waveshare `dt-blob.bin` generation during overlay application.
- `UNLIM8TED_X86_64_PACKAGES=...` overrides the apt package list for `x86_64`.

## Output

- `build/x86_64/unlim8ted-x86_64.img` is the customized `x86_64` test image.
- `build/cm4/unlim8ted-cm4.img` is the customized Raspberry Pi OS image to flash to CM4 storage.

Each target directory also includes a `README.txt` noting the upstream base image URL and installed package set.

## Notes

- The build is now much faster than a full Buildroot desktop stack because it reuses prebuilt distro packages.
- You still keep the repo-managed overlay and boot config.
- If you want the `x86_64` image to boot cleanly in QEMU, install the image onto a VM with UEFI or convert it with your preferred virtualization tooling after customization.
