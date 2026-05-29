# Repository Map

## Top level

- `README.md`: project overview and current hardware cost summary
- `docs/`: repo documentation
- `os/`: Unlim8ted OS image builder, overlay, backend, UI, and bundled apps
- `3d/`: enclosure exports, renders, and model assets
- `pcb/`: archived KiCad projects, fabrication output, vendor libraries, and references

## `os/`

This is the active software side of the project.

- `build.sh`: single build entrypoint for image creation, direct CM4 flashing, deferred first-boot installs, overlay reapply, hotpatch, repair, and continue flows
- `overlay/boot/config.txt`: tracked Raspberry Pi boot configuration for the Waveshare DSI panel and camera setup
- `overlay/etc/default/unlim8ted`: runtime environment variables for display, storage, captures, and Chromium profile paths
- `overlay/etc/systemd/system/unlim8ted.service`: kiosk systemd service that launches `xinit`
- `overlay/opt/unlim8ted/bin/kiosk-session.sh`: starts Openbox and then the Python backend
- `overlay/opt/unlim8ted/backend/`: Python backend and runtime services
- `overlay/opt/unlim8ted/ui/`: phone shell HTML and JavaScript
- `overlay/opt/unlim8ted/apps/`: per-app templates, Python logic, and optional client scripts
- `overlay/opt/unlim8ted/commands/registry.json`: command surface exposed to the shell and companion-facing clients

## `os/overlay/opt/unlim8ted/apps/`

Current app folders discovered from the repo:

- `browser`: local tab state and embedded browser shell
- `camera`: camera actions and capture flow
- `clock`: alarms, timers, and world clock state
- `code`: text/code editor over the user files area
- `files`: file browser, preview, editing, rename, and delete operations
- `gallery`: capture browser
- `mail`: local mailbox and draft state
- `maps`: placeholder destination/search state
- `messages`: local conversation state plus companion sync support
- `music`: local queue and playback state
- `notes`: local notes state
- `phone`: favorites, dial, contacts, and recents
- `settings`: account, system, notification, and connectivity summary
- `store`: installed app list and command surface view
- `terminal`: terminal app frontend/backend

Several of these apps are local-first modules backed by JSON state rather than external service integrations.

## `3d/`

This tree contains printable and presentation assets for the enclosure side of the project.

- Exported printable parts such as `Back_Cover.stl`, `Bottom_Cover.stl`, `Battery_Holder.stl`, and `Main_Case.stl`
- Render outputs such as `render.gif`, `render.mkv`, and `Components.gif`
- Mixed source/reference assets including `.glb` and `.stl` files.


## `pcb/`

This tree is archived.

- `custom pcb files/`: primary KiCad project folders and board revisions
- `libraries/`: imported or custom footprints/symbols
- `models/`: vendor and reference 3D assets
- `fabrication/`: gerbers and fabrication exports
- `references/`: screenshots, diagrams, schematics, datasheets, and videos
- `scripts/`: helper tooling such as the KiCad-to-OpenSCAD case generator
- `archives/`: backups, candidate layouts, zips, and superseded revisions

## `docs/assets`

Various renders used in the documentation.