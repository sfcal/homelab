# Cloud Gaming (Wolf, RomM)

[Wolf](https://games-on-whales.github.io/wolf/stable/) streams games and desktops to Moonlight clients from the `gaming` VM (ldn, `10.3.20.55`, VM 3005) using an Intel Arc Pro B50 SR-IOV virtual function. [RomM](https://docs.romm.app) manages the ROM library the Wolf emulator apps read.

```bash
task ansible:deploy-cloud-gaming ENV=ldn
```

Prerequisite: the VF must be visible in the guest, which depends on the [Proxmox host play](proxmox.md). The playbook aborts if the render node (`wolf_render_node`, `/dev/dri/renderD128`) is missing.

The play ends with `docker compose up -d` for both stacks. Compose recreates a container whenever its stored config hash differs from the current one, which ends any Moonlight session and restarts MariaDB, even when `compose.yaml` did not change (seen 2026-10-18). Before deploying while someone is streaming, compare the hashes on the VM; identical hashes mean no recreate:

```bash
ssh sfcal@10.3.20.55 'for p in wolf romm; do docker compose --project-directory /opt/$p config --hash="*"; done; docker inspect wolf romm romm-db --format "{{.Name}} {{index .Config.Labels \"com.docker.compose.config-hash\"}}"'
```

## Files

| Path | Purpose |
|------|---------|
| `ansible/playbooks/apps/cloud-gaming/deploy.yml` | Playbook (group `app_cloud_gaming`) |
| `ansible/playbooks/apps/cloud-gaming/templates/compose.yaml.j2` | Wolf container (matches the upstream quickstart compose) |
| `ansible/playbooks/apps/cloud-gaming/templates/config.toml.j2` | Wolf `config.toml` (version 7), seeded once |
| `ansible/playbooks/apps/cloud-gaming/templates/romm-compose.yaml.j2` | RomM and MariaDB |
| `ansible/playbooks/apps/cloud-gaming/templates/romm-config.yml.j2` | RomM library layout |
| `ansible/playbooks/apps/cloud-gaming/files/85-wolf.rules` | Upstream udev rules (`/dev/uinput`, `/dev/uhid`, virtual pads off the host seat) |
| `ansible/playbooks/apps/cloud-gaming/files/dolphin/startup-app.sh` | Start script of the Dolphin app (bind-mounted into the Pegasus image) |
| `ansible/playbooks/apps/cloud-gaming/files/dolphin/cfg/*.ini` | Dolphin config seeds: ROM paths and fullscreen, 3x internal resolution, Wolf pad mapping |
| `ansible/environments/ldn/group_vars/app_cloud_gaming/vars.yml` | Images, paths, render node |
| `ansible/environments/ldn/group_vars/app_cloud_gaming/secrets.sops.yml` | RomM database, auth and IGDB secrets |

## How Wolf is deployed

- Wolf runs as root in one container with the Docker socket, `/dev` and `/run/udev` mounted; it starts the app containers (Wolf UI, Pegasus, RetroArch, Dolphin, Steam) as siblings and maps paths back to the host by introspecting its own container. No host paths are passed in.
- State lives in `/var/lib/wolf/state` on the VM, mounted at `/etc/wolf`. Wolf reads `/etc/wolf/cfg/config.toml`, keeps TLS keys next to it and per-app data under `profile-data/<profile>/<runner name>/` (for example `profile-data/user/WolfDolphin`), which each app sees as `/home/retro`.
- `config.toml` is seeded on the first deploy only (`force: false`). Wolf rewrites the file when a client pairs and when apps or profiles change through Wolf UI or its API, so re-rendering it would drop pairings. To add or change an app on a running host, see [Changing apps on a running Wolf](#changing-apps-on-a-running-wolf).
- The seed contains the default Moonlight profile (Wolf UI, a synthetic "Test ball" stream useful to check the encoder) and a `User` profile with Pegasus, RetroArch, Dolphin (ROMs at `/ROMs`) and Steam, plus the upstream `[gstreamer]` encoder table. On Intel, Wolf picks the first working VA-API encoder.
- Dolphin has no upstream Wolf image. The Pegasus image is built on games-on-whales `base-emu`, which bundles the upstream Dolphin AppImage (`/Applications/dolphin-emu.AppImage`, with its own Mesa), so the Dolphin app runs that image with two bind mounts: `files/dolphin/startup-app.sh` over `/opt/gow/startup-app.sh`, and `files/dolphin/cfg/` at `/cfg/dolphin`. On its first run the script copies the seeds into `~/.config/dolphin-emu/` and never touches them again; later changes in Dolphin's UI persist in the app home. The seeds point the game list at `/ROMs/gc` and `/ROMs/wii`, start fullscreen on the Vulkan backend (switch to OpenGL in Graphics settings if Vulkan misbehaves on the B50), set 3x internal resolution, and map GameCube port 1 to the "Wolf X-Box One (virtual) pad" over evdev (positional layout: GC A/B/X/Y on Xbox A/X/B/Y). The mapping assumes Wolf creates an Xbox-type pad, which it does unless the paired client's `controllers_override` says otherwise; for a different pad, remap under Controllers in Dolphin. `DISABLE_AUTO_UPDATES=1` keeps the AppImage's self-updater from prompting mid-session. Dolphin needs no `/dev/uinput`.
- No memory limit is set on the Wolf container: the app containers are siblings, so a limit would only starve the compositor and encoder.
- Steam Input does not work inside the Steam container (known Wolf limitation, issues #81 and #403): it hides the Wolf pad from games and replaces it with a virtual gamepad created through uinput, whose device node never appears inside the container because no udev runs there. Do not pass `/dev/uinput` to the Steam app; that only makes Steam stop its keyboard/mouse fallback, which breaks menus and look. Disable Steam Input per game (Properties > Controller) and let the game read the "Wolf X-Box One (virtual) pad" directly. Symptom of Steam Input being on: look and jump work (emulated mouse/keys) but analog movement does not.
- Games never see the physical controller. Moonlight sends a controller type (Xbox, PS, Nintendo, Steam or unknown) plus capability flags, and Wolf creates a matching virtual pad on the VM: "Wolf X-Box One (virtual) pad" for Xbox and unknown, "Wolf DualSense (virtual) pad" for PS, "Wolf Nintendo (virtual) pad" for Nintendo. Wolf (revision `facb8e0`) does not know the Steam type that moonlight-qt sends for a Steam Controller since August 2026, so it falls into the unknown branch: a client that also advertises gyro or accelerometer gets a DualSense pad, otherwise an Xbox pad. The game-side binds (Half-Life `autoexec.cfg`, Dolphin seeds) are verified against the Xbox pad only. To keep that pad for a motion-capable controller such as the Steam Controller (2026), pin it per client in `/var/lib/wolf/state/cfg/config.toml` and restart Wolf between sessions:
  ```toml
  [[paired_clients]]
  app_state_folder = '...'
  client_cert = '''...'''
  [paired_clients.settings]
  motion_controller_override = "XBOX"   # or controllers_override = ["XBOX"] to force slot 0 regardless of motion
  ```
  Precedence is `controllers_override` (per slot) over `motion_controller_override` over auto-detection. The Steam Controller's trackpads, gyro and grip buttons only reach a game through Steam Input, which cannot run inside the Wolf Steam container, so with the Xbox pad it behaves as a plain Xbox-layout pad. Without Steam running on the client the controller only acts as a gamepad where the client's SDL is new enough (moonlight-qt nightly/Flatpak with SDL 3.4.10 or later); on Android TV and Apple TV it appears as a keyboard and mouse (the d-pad types arrow keys, so Half-Life "moves on the d-pad" and Wolf never logs a joypad). The TV client here is Android TV: a Shizuku-based bridge app ([steam-controller-android-tv](https://github.com/lluppi/steam-controller-android-tv), fork of [SteamController-Android](https://github.com/SonicDX12/SteamController-Android)) reads the controller over Bluetooth LE or the puck on USB OTG and exposes an "X-Box 360" virtual pad, which Moonlight reports as Xbox. Shizuku has to be restarted after every TV reboot.

## Android TV controller bridge

The Moonlight client is a TCL "Smart TV Pro" (Android 12, Realtek RTD6748, locked bootloader, no root). It only sees the Steam Controller as a gamepad through [Steam Controller Bridge](https://github.com/lluppi/steam-controller-android-tv) (package `io.github.lluppi.steamcontrollerbridge`), which reads the controller over the puck on USB and exposes a virtual "Microsoft X-Box 360 pad" through [Shizuku](https://shizuku.rikka.app) (`moe.shizuku.privileged.api`). Both were sideloaded over network ADB; the TV keeps ADB on port 5555 enabled across reboots.

Shizuku stops on every TV reboot and cannot restart itself without root, and the bridge's boot receiver gives up when Shizuku is not ready. Standby on this TV behaves like a reboot (the Android side restarts and USB power to the puck is cut), so an always-on recovery meant apps flashing on screen at every wake. The gaming VM therefore runs `tv-bridge-watchdog.timer` (every `tv_bridge_check_interval`, tasks in `tasks/tv-bridge.yml`, tag `tv_bridge`) in **manual mode** (`tv_bridge_manual: true`): it only acts while the bridge app is open on the TV. The user picks the "Connect controller" tile (the bridge app in its own "Controller" row on the Projectivy home) and within about 20 seconds the VM starts Shizuku's native starter (`lib/<abi>/libshizuku.so` inside the Shizuku APK; Shizuku 13 has no `start.sh`), taps the app's Start button (located through `uiautomator dump`), and accepts the TV's USB access dialog if it appears; the app then shows "Ready" and the user presses Home. With `tv_bridge_manual: false` the same recovery runs unattended whenever the service is down, the puck is on USB and the TV is awake. The service cannot be started directly: it is not exported, and the boot broadcast is protected. The watchdog also clears two traps seen in testing: when `shizuku_server` dies, Shizuku's own starter force-stops the Shizuku app, which puts it in Android's stopped state and makes the bridge's helper fail with "provider is null" until the app is launched once; and the helper process (`<package>:uinput`) outlives the app, so stale ones are killed before a restart to avoid duplicate pads. Health is judged by the service record plus a live helper, because a failed start leaves a service record behind for a while.

- One-time: the VM's ADB key must be accepted on the TV ("Allow USB debugging", tick Always allow). The watchdog logs when it is not.
- Pressing Stop Service in the app only holds for about a minute; the watchdog restarts it. Disable the timer on the VM for a longer pause.
- Give the TV a DHCP reservation; `tv_bridge_adb_host` is a fixed address.
- The TV's home screen is Projectivy Launcher (Play Store), trimmed to an Inputs row (HDMI 1 to 3) and a TV Apps row with Plex, Moonlight and YouTube; every other tile is hidden from its long-press menu. It takes the Home button through its accessibility service plus "Override current launcher" in Projectivy settings > General; the stock Google TV launcher stays installed, so unticking that option reverts it. After every reboot this TV leaves Projectivy force-stopped and wipes the accessibility settings (`accessibility_enabled` and, on some boots, the whole `enabled_accessibility_services` list), so Android never binds the service and the stock launcher comes back. Re-asserting the flag alone does nothing: the app has to be started and the enabled-services list written again. The watchdog does that (`tv_launcher_*` vars), but only while the stock launcher or Projectivy is in front so it never pulls the user out of an app, and presses Home once if the stock launcher is still showing; the stock launcher is visible for at most a minute after boot.
- Check: `journalctl -u tv-bridge-watchdog.service -n 20` on the VM, and "Creating Xbox joypad" in Wolf's log when a stream starts.

## Changing apps on a running Wolf

Wolf owns `config.toml` after the first seed, so editing `config.toml.j2` only affects future re-seeds. To apply an app change to the running host without re-pairing:

1. Render the template locally or deploy (the play never overwrites the live file) and copy the new `[[profiles.apps]]` block.
2. Append it to `/var/lib/wolf/state/cfg/config.toml` under the `[[profiles]]` it belongs to (the `user` profile is last in the file, so appending at the end adds to it). Check the result parses: `python3 -c 'import tomllib; tomllib.load(open("/var/lib/wolf/state/cfg/config.toml","rb"))'`.
3. `docker restart wolf` when no session is streaming. Wolf reads the file only at start-up; `paired_clients` are kept.

Wolf's API (unix socket `wolf.sock` inside the Wolf container's `/run/user/wolf` volume) is not a shortcut here: `POST /api/v1/apps/add` only adds to the Moonlight profile, apps added through the API cannot stream until the next restart anyway (upstream PR #506), and any API-driven profile write drops the Test ball `[profiles.apps.video]`/`[profiles.apps.audio]` overrides from the file.

## Network

Moonlight talks directly to the VM; it cannot go through Caddy. Ports: 47984/tcp, 47989/tcp, 47999/udp, 48010/tcp, 48100/udp, 48200/udp. `wolf.ldn.5am.cloud` is a plain A record for the VM. Pair a client by opening the PIN URL Wolf logs (`http://wolf.ldn.5am.cloud:47989/pin/#<secret>`).

RomM is proxied as `https://roms.ldn.5am.cloud` (container port 8080, host port 8085).

## ROM library

`romm_library_path` (`/srv/romm/library`) holds `roms/<platform>/<game>` and `bios/<platform>`, RomM's default layout. Pegasus, RetroArch and Dolphin mount `roms/` at `/ROMs`. The library is local to the VM; to use a NAS, add `nfs_mounts` in `ansible/environments/ldn/group_vars/app_cloud_gaming/nfs.yml` and point `romm_library_path` at the mount.

GameCube games go in `roms/gc/` and Wii games in `roms/wii/` (the play creates both). RomM maps `gc` to its `ngc` platform, and these are the folder names the Pegasus image and the Dolphin seed scan; `roms/ngc/` would work for RomM and Dolphin but not Pegasus. Use RVZ dumps (one file per game; multi-disc games may be a folder, Dolphin scans recursively). Neither console needs firmware: Dolphin skips the GameCube IPL by default and builds the Wii NAND itself. Dolphin's saves, Wii NAND and settings live in `/var/lib/wolf/state/profile-data/user/WolfDolphin/`.

Back up `/var/lib/romm/db` and `/var/lib/romm/assets` (saves and states); `resources` is a regenerable metadata cache.

## Verify in the guest

```bash
ssh sfcal@10.3.20.55
lspci -nn | grep -i display                      # Intel Battlemage G21 [8086:e212]
sudo dmesg | grep -iE 'xe .*SR-IOV|PRELOADED'    # Running in SR-IOV VF mode
ls -l /dev/dri                                   # renderD128
docker logs wolf 2>&1 | grep -iE 'encoder|vendor|pin'
```

A successful `qm start` is not yet a successful stream: Linux-guest 3D on Battlemage VFs is still maturing upstream. Use the "Test ball" app to confirm encoding before debugging a game.
