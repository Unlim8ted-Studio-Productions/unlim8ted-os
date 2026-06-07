
## CM4 Deferred Build

Use the deferred CM4 flow from Linux or WSL:

```sh
bash os/build.sh list-devices
bash os/build.sh deferred --device /dev/sdX
```

During an interactive build, the script asks for:

- Wi-Fi country, default `US`
- optional Wi-Fi SSID
- optional Wi-Fi password

If you need to push updated overlay files onto an already-flashed card without reflashing the base image:

```sh
sh os/reapply-overlay.sh /dev/sdX
```

## First Boot Notes

On first boot, the device autologins root on `tty1` and runs `firstboot-install.sh`.

- If network is not ready, the script waits indefinitely and prompts on `tty1`.
- If package install fails, the script drops into an interactive recovery shell on `tty1`.
- If you get dropped into that shell and the system otherwise looks ready, you may only need to type `reboot`.

Default seeded credentials:

- username: `unlim8ted`
- password: `unlim8ted`
