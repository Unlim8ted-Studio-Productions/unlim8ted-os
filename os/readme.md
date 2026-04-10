# Unlim8ted OS

This directory now builds Unlim8ted OS by customizing official upstream Linux images instead of compiling a full Buildroot system from source.

## Structure

- `overlay/` holds the files copied into the target image, including `/etc`, `/opt`, and the Raspberry Pi boot configuration tracked in this repo.
- `build-cm4.sh` customizes a Raspberry Pi OS Lite 64-bit image for CM4.
- `build-x86_64.sh` customizes an official Debian 12 amd64 generic cloud image for local `x86_64` testing.
- `build/` receives the finished artifacts after each build.

## Base Images

- CM4 uses the official Raspberry Pi OS Lite 64-bit image alias from Raspberry Pi downloads.
- `x86_64` uses the official Debian 12 amd64 generic cloud image. That keeps Chromium available as a normal apt package and is straightforward to boot under QEMU or other desktop virtualization.

## Included software

Both targets install kiosk-oriented packages with `apt`, then apply the repo overlay:

- `systemd` from the base image
- `python3`
- `chromium`
- Bluetooth support
- Wi-Fi support
- Xorg and `xinit`
- `openbox`

CM4 also installs:

- `libcamera-apps`

The overlay still provides the kiosk startup path:

- `etc/systemd/system/getty@tty1.service.d/autologin.conf` skips the tty1 login prompt.
- `etc/systemd/system/unlim8ted.service` starts X with `xinit`.
- `opt/unlim8ted/bin/kiosk-session.sh` starts the backend, and the backend launches Chromium in app mode.

## Requirements

Run the scripts from a Linux shell, including WSL.

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

Additional requirement when building the CM4 image on an `x86_64` host:

- `qemu-aarch64-static`

The scripts mount the image, install packages with `apt`, copy the overlay, and enable `unlim8ted.service`. They do not work from plain Windows PowerShell.

## Building

```sh
cd os
bash ./build-x86_64.sh
bash ./build-cm4.sh
```

Optional environment variables:

- `UNLIM8TED_IMAGE_GROW_MB=512` adds extra space to the image before resizing the root filesystem.
- `UNLIM8TED_CM4_PACKAGES=...` overrides the apt package list for CM4.
- `UNLIM8TED_X86_64_PACKAGES=...` overrides the apt package list for `x86_64`.

## Output

- `build/x86_64/unlim8ted-x86_64.img` is the customized `x86_64` test image.
- `build/cm4/unlim8ted-cm4.img` is the customized Raspberry Pi OS image to flash to CM4 storage.

Each target directory also includes a `README.txt` noting the upstream base image URL and installed package set.

## Notes

- The build is now much faster than a full Buildroot desktop stack because it reuses prebuilt distro packages.
- You still keep the repo-managed overlay and boot config.
- If you want the `x86_64` image to boot cleanly in QEMU, install the image onto a VM with UEFI or convert it with your preferred virtualization tooling after customization.
