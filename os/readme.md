# Unlim8ted OS

This directory contains the Buildroot setup for the Unlim8ted kiosk image and the filesystem overlay that gets installed into it.

## Structure

- `overlay/` holds the files that end up inside the target image, including `/etc`, `/opt`, and the boot configuration tracked in this repo.
- `buildroot-external/` contains the Buildroot fragments and board hook used to customize the stock targets.
- `build-x86_64.sh` builds the desktop `x86_64` image.
- `build-cm4.sh` builds the Raspberry Pi CM4 image.
- `build/` receives the finished artifacts after each build.

## Included software

Both targets are configured as small kiosk-oriented systems with:

- `systemd`
- Wi-Fi support
- Bluetooth support
- `chromium`
- `libcamera`
- `python3`

The overlay also provides the kiosk startup path:

- `etc/systemd/system/getty@tty1.service.d/autologin.conf` skips the tty1 login prompt.
- `etc/systemd/system/unlim8ted.service` starts X with `xinit`.
- `opt/unlim8ted/bin/kiosk-session.sh` starts the backend, and the backend launches Chromium in app mode.

## Building

Run the scripts from a Linux shell:

```sh
cd os
bash ./build-x86_64.sh
bash ./build-cm4.sh
```

If you build from WSL on a Windows-mounted path such as `/mnt/o/...`, the scripts move the Buildroot working tree to a Linux-native cache directory and copy the finished artifacts back into `os/build/`. That avoids the symlink issues that break host-package installs on DrvFS.

## Output

- `build/x86_64/` contains the `x86_64` image set and the final ISO.
- `build/cm4/` contains the CM4 image set and a convenience ISO bundle.

For CM4, the image you actually flash is `sdcard.img` from the CM4 output directory. The ISO is just a wrapper so the build products stay packaged together in one file.

## CM4 boot configuration

The CM4 build uses Buildroot's standard `raspberrypi4_64_defconfig` image flow.

That target already uses the Raspberry Pi `post-image.sh` script to assemble `sdcard.img` from the kernel image, the generated DTBs, and the files placed in `output/images/rpi-firmware/`. Buildroot's `rpi-firmware` package writes `config.txt` into that `rpi-firmware` directory through `BR2_PACKAGE_RPI_FIRMWARE_CONFIG_FILE`.

Unlim8ted sets `BR2_PACKAGE_RPI_FIRMWARE_CONFIG_FILE` to `overlay/boot/firmware/config.txt`, so the CM4 boot partition is built from the boot config tracked in this repository rather than copied in later by a custom script.
