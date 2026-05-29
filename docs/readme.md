# Unlim8ted Phone Docs

This folder documents the Unlim8ted Phone repository as it exists today: the CM4 software stack, enclosure assets, hardware baseline, and archived board work.

## What is in this repo

- A Raspberry Pi CM4 kiosk-style phone shell and backend under `os/`
- Printable enclosure exports and supporting 3D assets under `3d/`
- Archived custom PCB work under `pcb/`
- Project-level notes in this `docs/` folder

## Start here

- [Repository Map](repo-map.md)
- [OS Architecture](os-architecture.md)
- [Hardware And Design Notes](hardware-and-design.md)

## Current direction

The project is currently built around off-the-shelf CM4 hardware, a custom enclosure, and a custom kiosk-style software stack.

The `pcb/` tree remains useful reference material, but it is no longer the active hardware path.

## Important repo realities

- The main software entrypoint is `os/build.sh`, not a full Buildroot tree.
- The device UI is a local web app served by a Python backend on port `8080`.
- The app set is mostly local-first and stateful, with several apps backed by JSON files under the runtime state directory.
- Some Blender source may live outside the pushed repository; the tracked tree primarily preserves exports and reference assets.
