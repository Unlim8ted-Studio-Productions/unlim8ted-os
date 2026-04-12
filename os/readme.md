# Unlim8ted OS

This directory now builds Unlim8ted OS by customizing official upstream Linux images instead of compiling a full Buildroot system from source.

## Structure

- `overlay/` holds the files copied into the target image, including `/etc`, `/opt`, and the Raspberry Pi boot configuration tracked in this repo.
- `build.sh` is the only build entrypoint. It handles image builds, direct CM4 device builds, deferred first-boot installs, overlay reapplies, runtime hotpatches, and repair/continue flows.
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

Additional requirement when building the CM4 image on an `x86_64` host:

- `qemu-aarch64-static`

The build script mounts the image, installs packages with `apt`, copies the overlay, and enables `unlim8ted.service`. It does not work from plain Windows PowerShell.

## Editing a CM4 Card from Windows

If the card is plugged into a Windows machine, use the Windows helper to browse and edit its Linux partitions through WSL:

```powershell
powershell -ExecutionPolicy Bypass -File .\os\edit-card-windows.ps1
```

You can also double-click `os\edit-card-windows.cmd`.

The helper opens as Administrator because `wsl --mount` needs elevated access to physical disks. It lists removable/USB/SD disks, mounts the selected partition through WSL, opens the mounted path in Windows Explorer, and has an `Eject` button that syncs WSL, unmounts the disk, and offlines it in Windows.

Default Unlim8ted card partitions:

- `3 - storage ext4` is the user storage partition for files, downloads, pictures, videos, music, and captures.
- `2 - rootfs ext4` is the OS filesystem with `/opt/unlim8ted`.
- `1 - bootfs FAT` is the Raspberry Pi boot partition.

Only use `Show all disks` if the card reader does not report itself as removable. Check the disk number carefully before mounting or ejecting.

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
- You can select an existing mounted folder such as `/mnt/o/unlim8ted-build-cache`; this does not format anything and works with Windows-mounted drives.

Common commands:

```sh
# Show disks before selecting a target.
bash os/build.sh list-devices

# Build normal image artifacts.
bash os/build.sh image --arch x86_64 --grow-mb 4096
bash os/build.sh image --arch cm4 --grow-mb 12288

# Build directly onto a CM4 SD/USB device.
bash os/build.sh image --arch cm4 --direct-device /dev/sdi

# Deferred CM4 build: flash base OS, apply overlay, install packages on first boot.
bash os/build.sh deferred --device /dev/sdi

# Override the default CM4 layout (boot/root sizes in MiB):
bash os/build.sh deferred --device /dev/sdi --boot-size-mib 512 --root-size-mib 9728

# Reapply the complete overlay to an existing CM4 card without package installs.
bash os/build.sh overlay --device /dev/sdi

# Copy only the current runtime hotpatch files. Package install: never.
bash os/build.sh hotpatch --device /dev/sdi

# If your partitions are nonstandard, you can map them explicitly:
bash os/build.sh overlay --device /dev/sdi --boot-part /dev/sdi1 --root-part /dev/sdi2 --storage-part /dev/sdi3
bash os/build.sh hotpatch --device /dev/sdi --boot-part /dev/sdi1 --root-part /dev/sdi2 --storage-part /dev/sdi3

# Repair a partially customized CM4 card by resizing rootfs and continuing install.
bash os/build.sh repair --device /dev/sdi --add-mb 8192
bash os/build.sh repair --device /dev/sdi --size-gib 32

# Continue a failed CM4 package install without resizing partitions.
bash os/build.sh continue --device /dev/sdi

# Skip resizing during repair when the layout is already correct:
bash os/build.sh repair --device /dev/sdi --no-resize --boot-part /dev/sdi1 --root-part /dev/sdi2 --storage-part /dev/sdi3
```

Direct CM4 device builds flash Raspberry Pi OS directly to the selected SD/USB device, calculate the OS root partition size from the selected package set plus a 5 GiB buffer, create a separate `storage` partition from the remaining space, then install packages and the overlay on that device. If the selected CM4 device already has `bootfs` and `rootfs` partitions, the script reuses it and continues customization instead of rewriting the base image.

Deferred CM4 builds fully rewrite the selected device, set `rootfs` to 10GiB by default, create `LABEL=storage` from the remaining space, apply the overlay, and skip host-side package installation. On first boot, tty1 prompts for network access, installs the CM4 package set on the Pi, cleans apt/temp files, enables `unlim8ted.service`, and starts the kiosk.

Overlay and hotpatch modes never install packages:

- `overlay` reapplies the full repo overlay and service setup.
- `hotpatch` copies only selected runtime files used for the current UI/backend/apps/Plymouth updates.

The `storage` partition is mounted at `/home/unlim8ted` and is used for user files, downloads, pictures, videos, music, and captures.

Optional environment variables:

- `UNLIM8TED_WORK_DIR=...` sets the build work/cache directory.
- `UNLIM8TED_BASE_IMAGE_DIR=...` sets the base image cache directory.
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
