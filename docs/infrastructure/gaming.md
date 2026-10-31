# Gaming (Terraria, Wolf, RomM)

One playbook, `ansible/playbooks/apps/gaming/deploy.yml`, deploys every game stack on an environment's `app_gaming` host. A stack runs only where that environment's `group_vars/app_gaming/vars.yml` defines its image (`terraria_image`, `romm_image`, `wolf_image`), so the same command deploys different stacks per environment:

| Environment | VM | Stacks |
|-------------|----|--------|
| wil | `games` (`10.2.20.50`, VM 1111) | [Terraria](#terraria) |
| ldn | `gaming` (`10.3.20.55`, VM 3005) | [Wolf and RomM](#wolf-and-romm) |

```bash
task ansible:deploy-gaming ENV=wil   # Terraria
task ansible:deploy-gaming ENV=ldn   # Wolf and RomM
```

To run a stack in another environment, copy its vars into that environment's `group_vars/app_gaming/vars.yml`, along with its secrets.

## Files

| Path | Purpose |
|------|---------|
| `ansible/playbooks/apps/gaming/deploy.yml` | Playbook (group `app_gaming`) |
| `ansible/playbooks/apps/gaming/templates/terraria-compose.yaml.j2` | Terraria server |
| `ansible/playbooks/apps/gaming/templates/wolf-compose.yaml.j2` | Wolf container (matches the upstream quickstart compose) |
| `ansible/playbooks/apps/gaming/templates/wolf-config.toml.j2` | Wolf `config.toml` (version 7), seeded once |
| `ansible/playbooks/apps/gaming/templates/romm-compose.yaml.j2` | RomM and MariaDB |
| `ansible/playbooks/apps/gaming/templates/romm-config.yml.j2` | RomM library layout |
| `ansible/playbooks/apps/gaming/files/85-wolf.rules` | Upstream udev rules (`/dev/uinput`, `/dev/uhid`, virtual pads off the host seat) |
| `ansible/environments/wil/group_vars/app_gaming/vars.yml` | Terraria image, paths, world settings |
| `ansible/environments/wil/group_vars/all/app.secrets.sops.yml` | Terraria join password (`terraria_server_password`) |
| `ansible/environments/ldn/group_vars/app_gaming/vars.yml` | Wolf and RomM images, paths, render node |
| `ansible/environments/ldn/group_vars/app_gaming/secrets.sops.yml` | RomM database, auth and IGDB secrets |

## Terraria

A dedicated Terraria server (`ryshe/terraria`) on port 7777, with no DNS or proxy entry.

- Compose lives in `/opt/games-server` and the world in `/var/lib/games-server/terraria/worlds` (`terraria_deploy_path`, `terraria_data_path`), the paths it had as the `games-server` registry app. To rename them, run `docker compose down` in the old directory and move the world first: the container is always named `terraria`, so a second compose project would clash with the running one.
- The image tag floats (`latest`), so every deploy pulls it and recreates the container when a newer image arrived.
- World settings (`terraria_worldname`, `terraria_worldsize`, `terraria_difficulty`, `terraria_seed`, ...) become server flags in `terraria-compose.yaml.j2`. An empty `terraria_server_password` runs an open server.

## Wolf and RomM

[Wolf](https://games-on-whales.github.io/wolf/stable/) streams games and desktops to Moonlight clients from the `gaming` VM (ldn, `10.3.20.55`, VM 3005) using an Intel Arc Pro B50 SR-IOV virtual function. [RomM](https://docs.romm.app) manages the ROM library the Wolf emulator apps read.

Prerequisite: the VF must be visible in the guest, which depends on the [Proxmox host play](proxmox.md). The playbook aborts if the render node (`wolf_render_node`, `/dev/dri/renderD128`) is missing.

The play ends with `docker compose up -d` for both stacks. Compose recreates a container whenever its stored config hash differs from the current one, which ends any Moonlight session and restarts MariaDB, even when `compose.yaml` did not change (seen 2026-10-18). Before deploying while someone is streaming, compare the hashes on the VM; identical hashes mean no recreate:

```bash
ssh sfcal@10.3.20.55 'for p in wolf romm; do docker compose --project-directory /opt/$p config --hash="*"; done; docker inspect wolf romm romm-db --format "{{.Name}} {{index .Config.Labels \"com.docker.compose.config-hash\"}}"'
```

## How Wolf is deployed

- Wolf runs as root in one container with the Docker socket, `/dev` and `/run/udev` mounted; it starts the app containers (Wolf UI, Pegasus, RetroArch, Steam) as siblings and maps paths back to the host by introspecting its own container. No host paths are passed in.
- State lives in `/var/lib/wolf/state` on the VM, mounted at `/etc/wolf`. Wolf reads `/etc/wolf/cfg/config.toml`, keeps TLS keys next to it and per-app data under `profile-data/<profile>/<runner name>/` (for example `profile-data/user/WolfPegasus`), which each app sees as `/home/retro`.
- `config.toml` is seeded on the first deploy only (`force: false`). Wolf rewrites the file when a client pairs and when apps or profiles change through Wolf UI or its API, so re-rendering it would drop pairings. To add or change an app on a running host, see [Changing apps on a running Wolf](#changing-apps-on-a-running-wolf).
- The seed contains the default Moonlight profile (Wolf UI, a synthetic "Test ball" stream useful to check the encoder) and a `User` profile with Pegasus, RetroArch (both with ROMs at `/ROMs`) and Steam, plus the upstream `[gstreamer]` encoder table. On Intel, Wolf picks the first working VA-API encoder.
- No memory limit is set on the Wolf container: the app containers are siblings, so a limit would only starve the compositor and encoder.
- Steam Input does not work inside the Steam container (known Wolf limitation, issues #81 and #403): it hides the Wolf pad from games and replaces it with a virtual gamepad created through uinput, whose device node never appears inside the container because no udev runs there. Do not pass `/dev/uinput` to the Steam app; that only makes Steam stop its keyboard/mouse fallback, which breaks menus and look. Disable Steam Input per game (Properties > Controller) and let the game read the "Wolf X-Box One (virtual) pad" directly. Symptom of Steam Input being on: look and jump work (emulated mouse/keys) but analog movement does not.
- Games never see the physical controller. Moonlight sends a controller type (Xbox, PS, Nintendo, Steam or unknown) plus capability flags, and Wolf creates a matching virtual pad on the VM: "Wolf X-Box One (virtual) pad" for Xbox and unknown, "Wolf DualSense (virtual) pad" for PS, "Wolf Nintendo (virtual) pad" for Nintendo. Wolf (revision `facb8e0`) does not know the Steam type that moonlight-qt sends for a Steam Controller since August 2026, so it falls into the unknown branch: a client that also advertises gyro or accelerometer gets a DualSense pad, otherwise an Xbox pad. The game-side binds (Half-Life `autoexec.cfg`) are verified against the Xbox pad only. To keep that pad for a motion-capable controller such as the Steam Controller (2026), pin it per client in `/var/lib/wolf/state/cfg/config.toml` and restart Wolf between sessions:
  ```toml
  [[paired_clients]]
  app_state_folder = '...'
  client_cert = '''...'''
  [paired_clients.settings]
  motion_controller_override = "XBOX"   # or controllers_override = ["XBOX"] to force slot 0 regardless of motion
  ```
  Precedence is `controllers_override` (per slot) over `motion_controller_override` over auto-detection. The Steam Controller's trackpads, gyro and grip buttons only reach a game through Steam Input, which cannot run inside the Wolf Steam container, so with the Xbox pad it behaves as a plain Xbox-layout pad. Without Steam running on the client the controller only acts as a gamepad where the client's SDL is new enough (moonlight-qt nightly/Flatpak with SDL 3.4.10 or later); on Android TV and Apple TV it appears as a keyboard and mouse (the d-pad types arrow keys, so Half-Life "moves on the d-pad" and Wolf never logs a joypad).

## Changing apps on a running Wolf

Wolf owns `config.toml` after the first seed, so editing `wolf-config.toml.j2` only affects future re-seeds. To apply an app change to the running host without re-pairing:

1. Render the template locally or deploy (the play never overwrites the live file) and copy the new `[[profiles.apps]]` block.
2. Append it to `/var/lib/wolf/state/cfg/config.toml` under the `[[profiles]]` it belongs to (the `user` profile is last in the file, so appending at the end adds to it). Check the result parses: `python3 -c 'import tomllib; tomllib.load(open("/var/lib/wolf/state/cfg/config.toml","rb"))'`.
3. `docker restart wolf` when no session is streaming. Wolf reads the file only at start-up; `paired_clients` are kept.

Wolf's API (unix socket `wolf.sock` inside the Wolf container's `/run/user/wolf` volume) is not a shortcut here: `POST /api/v1/apps/add` only adds to the Moonlight profile, apps added through the API cannot stream until the next restart anyway (upstream PR #506), and any API-driven profile write drops the Test ball `[profiles.apps.video]`/`[profiles.apps.audio]` overrides from the file.

## Network

Moonlight talks directly to the VM; it cannot go through Caddy. Ports: 47984/tcp, 47989/tcp, 47999/udp, 48010/tcp, 48100/udp, 48200/udp. `wolf.ldn.5am.cloud` is a plain A record for the VM. Pair a client by opening the PIN URL Wolf logs (`http://wolf.ldn.5am.cloud:47989/pin/#<secret>`).

RomM is proxied as `https://roms.ldn.5am.cloud` (container port 8080, host port 8085).

## ROM library

`romm_library_path` (`/srv/romm/library`) holds `roms/<platform>/<game>` and `bios/<platform>`, RomM's default layout. Pegasus and RetroArch mount `roms/` at `/ROMs`. The library is local to the VM; to use a NAS, add `nfs_mounts` in `ansible/environments/ldn/group_vars/app_gaming/nfs.yml` and point `romm_library_path` at the mount.

GameCube games go in `roms/gc/` and Wii games in `roms/wii/` (the play creates both). RomM maps `gc` to its `ngc` platform, and these are the folder names the Pegasus image scans; `roms/ngc/` would work for RomM but not Pegasus.

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
