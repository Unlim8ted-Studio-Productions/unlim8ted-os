# Unlim8ted Build Outputs

This directory stores generated staging artifacts and build metadata for the
portable Unlim8ted OS tree.

Targets:

- `x86_64`: build a GRUB bootable ISO with `build-pc-iso.sh`
- `arm64`: stage a generic ARM boot tree with `stage-generic-arm64-image.sh`

The runtime itself detects architecture at startup and chooses a boot target:

- `x86_64` -> `pc`
- `arm64` -> `generic-arm`
- Raspberry Pi hardware -> `rpi`
