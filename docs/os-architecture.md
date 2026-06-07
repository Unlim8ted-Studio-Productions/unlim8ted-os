# OS Architecture

## Overview

Unlim8ted OS in this repository is an image-customization workflow rather than a full distribution source tree. It starts from upstream base images, installs the required packages, applies the repo overlay, and enables the kiosk runtime.

There is one supported target:

- `cm4`: Raspberry Pi OS Lite 64-bit based image for the device

## Boot and runtime flow

At runtime the system follows this boot chain:

1. `unlim8ted.service` starts `xinit` on `tty1`
2. `kiosk-session.sh` disables screen blanking, starts Openbox, and launches the backend
3. `backend/main.py` starts a local HTTP server on port `8080`
4. The same Python process launches Chromium in app/kiosk mode pointed at `http://localhost:8080`
5. Chromium loads `ui/index.html` and `ui/app.js`
6. The shell opens apps by calling backend routes, which dispatch into `apps/<app>/main.py`

## Backend responsibilities

`os/overlay/opt/unlim8ted/backend/main.py` is the main runtime process. It is responsible for:

- Serving the shell HTML and JavaScript
- Serving app templates and client scripts
- Routing app API requests
- Sleep, wake, brightness, reboot, shutdown, and kiosk-exit actions
- Wi-Fi and Bluetooth toggles
- Companion pairing/session endpoints
- Media file serving for captures
- Chromium launch

## Runtime services

`os/overlay/opt/unlim8ted/backend/runtime.py` provides the local service layer used by apps.

Key services:

- `StateStore`: JSON-backed persistence under the runtime state directory
- `ContactsService`: default/favorite contacts
- `CommunicationsService`: calls, threads, and messages
- `AccountsService`: owner and mail account state
- `MediaService`: captures and music queue state
- `FilesService`: sandboxed access to allowed filesystem roots
- `NotificationsService`: badge counts and notification state
- `CompanionService`: pairing codes, sessions, device list, and push token metadata
- `AppRegistry`: app discovery and dynamic loading from `apps/*/main.py`

## UI shell

The shell is a mobile-style single-page interface implemented in `ui/index.html` and `ui/app.js`.

Key shell behavior visible in the current implementation:

- Lock screen and home screen flow
- Control center and quick toggles
- Sleep/wake behavior with idle timeout
- App switcher
- Soft keyboard with suggestions and glide typing
- Home screen page swiping and icon rearrangement
- Lightweight performance mode detection for ARM/Linux targets
- Error isolation so a failed app does not kill the shell

## App model

Apps are local modules under `os/overlay/opt/unlim8ted/apps/<app-id>/`.

Common parts:

- `main.py`: manifest plus server-side payload/action logic
- `index.html`: optional app template
- `client.js`: optional rich client behavior

The backend loads app manifests dynamically. Some apps return structured payloads for generic rendering, while others ship dedicated templates and client-side behavior.

## Data and storage

Default runtime paths are configured in `overlay/etc/default/unlim8ted`:

- state: `/var/lib/unlim8ted`
- user storage: `/home/unlim8ted`
- user files: `/home/unlim8ted/Files`
- captures: `/home/unlim8ted/Pictures/Captures`
- Chromium profile: `/var/lib/unlim8ted/chromium-profile`

The CM4 image layout also reserves a separate `storage` partition mounted at `/home/unlim8ted`.

## Build workflow summary

`os/build.sh` now supports one provisioning flow only:

- flash the pinned Raspberry Pi OS Lite base image to an SD or USB device
- resize the root partition to a fixed size
- create a `storage` partition for `/home/unlim8ted`
- apply the tracked overlay
- suppress Raspberry Pi OS first-run setup
- boot into `tty1` root autologin
- run `firstboot-install.sh` on the device after network is available

The deferred first-boot script installs packages on the target device instead of preinstalling them during image creation.

Current first-boot behavior:

- `tty1` autologins root
- `firstboot-install.sh` prompts for network access if needed and waits indefinitely
- on failure, the script opens an interactive recovery shell on `tty1`
- if the system is otherwise ready, a simple `reboot` may be enough to continue cleanly on the next boot

The image also seeds a default local user for Raspberry Pi OS first-run setup suppression:

- username: `unlim8ted`
- password: `unlim8ted`

## Practical caveats

- The build script must run from Linux or WSL, not native Windows.
- Several apps are intentionally local-state implementations rather than fully integrated phone services.
- Package installation now happens on first boot, so network availability on the device is part of provisioning.
