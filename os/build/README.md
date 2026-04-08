# Unlim8ted Build

This is the only public build entrypoint.

Run:

```bash
TARGET_ARCH=x86_64 ./os/build/build.sh
TARGET_ARCH=arm64 ./os/build/build.sh
```

Inputs:

- `../rootfs` contains the filesystem tree
- `../bootfs` contains bootloader config and kernel/initramfs payloads

Outputs:

- `./out/unlim8ted-x86_64.iso` for `x86_64`
- `./out/arm64/` staged boot tree for `arm64`

Kernel sources and configs:

- `./build-kernel-arm64-cm4.sh` builds the CM4 `arm64` kernel
- `./build-kernel-x86_64.sh` builds the generic `x86_64` kernel
- `./build-kernel.sh` remains as a thin dispatcher
- `./kernel-sources.env` defines the official source repositories
- `./configs/arm64-cm4.fragment` customises the CM4 `arm64` kernel
- `./configs/x86_64-generic.fragment` customises the generic `x86_64` kernel
- `./install-unlim8ted-kernel-feature.sh` injects a built-in `/proc/unlim8ted_identity` kernel feature

WSL note:

- Do not build Linux sources under `/mnt/<drive>/...` because the kernel tree contains case-colliding paths.
- By default the kernel build scripts now use a Linux-native cache directory under `$HOME/.cache/unlim8ted-kernel-build`.
- The kernel build scripts force Linux system paths to the front of `PATH` so WSL does not accidentally pick Windows-host tools.

Required build tools inside the Linux environment:

- `git`
- `make`
- `gcc` for `x86_64`
- `flex`
- `bison`
- `perl`
- `aarch64-linux-gnu-gcc` for `arm64`

The build system can only produce:

- a native `arm64` kernel for Raspberry Pi CM4
- a native `x86_64` kernel for regular PCs

It cannot produce an `amd64` kernel that boots natively on CM4 hardware.
