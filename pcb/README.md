# PCB Folder

This folder contains outdated and unfinished PCB design work, archived revisions, fabrication output, supporting libraries, and reference material for the phone project. None of the custom PCB files should be fabricated, and ignoring this warning could result in damage.

## Layout

- `custom pcb files/`
  - the KiCad project folders and board files
  - currently includes `phone/`, `phone-part-1/`, and `phone6layer/`
- `libraries/`
  - custom symbol and footprint libraries
  - vendor library imports used by the projects
- `models/`
  - component, enclosure, and vendor-supplied 3D assets
- `fabrication/`
  - gerbers, pick-and-place files, plots, and JLCPCB exports
- `references/`
  - datasheets, diagrams, screenshots, and video captures
- `scripts/`
  - helper scripts used alongside the PCB workflow
- `archives/`
  - backups, candidate revisions, zip bundles, and superseded files

## Working Projects

- `custom pcb files/phone/`
  - main phone schematic project and its exported 3D artifacts
- `custom pcb files/phone6layer/`
  - 6-layer phone board revision
- `custom pcb files/phone-part-1/`
  - partial board split-out
