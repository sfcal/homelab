# Gaming (Steam Headless, RomM)

One playbook, `ansible/playbooks/apps/gaming/deploy.yml`, deploys every game stack on an environment's `app_gaming` host. A stack runs only where that environment's `group_vars/site_<env>/app_gaming/vars.yml` defines its image (`romm_image`, `steam_headless_image`). Both run at ldn:

| Environment | VM | Stacks |
|-------------|----|--------|
| ldn | `gaming` (`10.3.20.55`, VM 3005) | [Steam Headless](#steam-headless), [RomM](#romm) |

```bash
task ansible:deploy-gaming ENV=ldn   # RomM and Steam Headless
```

To run a stack in another environment, copy its vars into that environment's `group_vars/site_<env>/app_gaming/vars.yml`, along with its secrets.

Wolf (Games on Whales) streamed from this VM until 2026-11-13, when Steam Headless replaced it; its containers, images and data were removed that day.

## Files

| Path | Purpose |
|------|---------|
| `ansible/playbooks/apps/gaming/deploy.yml` | Playbook (group `app_gaming`) |
| `ansible/playbooks/apps/gaming/templates/steam-headless-compose.yaml.j2` | Steam Headless container (upstream's host-networking example) |
| `ansible/playbooks/apps/gaming/templates/romm-compose.yaml.j2` | RomM and MariaDB |
| `ansible/playbooks/apps/gaming/templates/romm-config.yml.j2` | RomM library layout |
| `ansible/inventory/group_vars/site_ldn/app_gaming/vars.yml` | Steam Headless and RomM images, RomM paths |
| `ansible/inventory/group_vars/site_ldn/secrets.sops.yml` | RomM database, auth and IGDB secrets (section `app_gaming`) |

## Steam Headless

[Steam Headless](https://steamheadless.com/docs/) streams games and a desktop from the `gaming` VM using an Intel Arc Pro B50 SR-IOV virtual function. One container runs systemd, a KDE Plasma desktop on Wayland, Steam, Sunshine and a web interface; it is played in a browser, from Moonlight or through Steam Remote Play.

Prerequisite: the VF must be visible in the guest (`/dev/dri/renderD128`), which depends on the [Proxmox host play](proxmox.md).

The image is upstream's version 2 (`josh5/steam-headless:2`, Fedora). The README and compose files in the GitHub repository still describe version 1; the version 2 documentation is on steamheadless.com, and the compose template is its host-networking example with host paths.

- **Address**: the VM's own, `10.3.20.55`, with the name `steam.ldn.5am.cloud` (a plain A record in `site_ldn/proxy/ldn.5am.cloud.yml`). The container uses the VM's network (`network_mode: host`). Sunshine's Moonlight ports and the web interface's port are fixed, so only one streaming host can run on the VM.
- **Web interface**: `https://steam.ldn.5am.cloud:8483`, with a certificate the container signs itself, so the browser warns once. On a new state folder the first sign-in is user `steamheadless` with a temporary password, and the page then asks for a permanent one of at least 12 characters:
  ```bash
  ssh sfcal@10.3.20.55 docker exec steam-headless cat /var/lib/steam-headless/auth/bootstrap-password
  ```
  Sunshine stays off until that is done. A forgotten password is reset by deleting `/var/lib/steam-headless/state/auth/state.json` on the VM and restarting the container.
- **Moonlight**: add the host as `steam.ldn.5am.cloud` and pair it on the web interface's Sunshine page.
- **GPU**: only the render node (`/dev/dri/renderD128`) is passed in. The desktop, Vulkan and the VA-API encoders all use the B50 virtual function, checked on 2026-11-12.
- **Browser stream colours**: the compose file sets `SHUI_MEDIA_CONVERSION: vaapi`, so frames are converted and scaled on the GPU. With upstream's default (`system`, on the CPU) a 720p stream from the B50 showed its colours 32 rows too high with a green strip along the bottom; 1080p was not affected (2026-11-13, reproduced with `gst-launch-1.0` and a test pattern inside the container).
- **Input**: the container has a private `/dev/input` and makes its own virtual keyboards, mice and gamepads; nothing of the VM's `/dev/input` or `/run/udev` is mounted.
- **Kernel settings**: the play loads the `uinput` and `uhid` modules (`/etc/modules-load.d/`) and raises `fs.inotify.max_user_instances` to 1024 (`/etc/sysctl.d/90-steam-headless.conf`).
- **Size of the VM**: upstream asks for 4 cores, 16 GB of memory and swap for one stream. The VM has 2 cores, 8 GB and no swap; the idle desktop with Steam open takes about 2 GB.

| Path on the VM | Purpose |
|----------------|---------|
| `/opt/steam-headless/compose.yaml` | Compose file |
| `/var/lib/steam-headless/home` | Home of the desktop user (uid 1000): Steam, Proton prefixes, saves, Sunshine pairings, RetroDECK |
| `/var/lib/steam-headless/games` | Game library, `/mnt/games` in the container; add it as a library folder in Steam |
| `/srv/romm/library` | RomM's library, read-only at `/mnt/romm` in the container (see [Emulators](#emulators-retrodeck)) |
| `/var/lib/steam-headless/state` | Sign-in and certificate state, owned by root |
| `/var/log/steam-headless` | The container's systemd journal |

```bash
ssh sfcal@10.3.20.55 docker exec steam-headless /usr/local/bin/steam-headless-healthcheck
```

The `2` tag moves with every upstream build and a deploy never pulls it again. To update: `docker compose --project-directory /opt/steam-headless pull` on the VM, then deploy (the container restarts, so close games first).

A deploy that changes the compose file recreates the container: streams drop, running games close and the session comes back in desktop mode.

### Emulators (RetroDECK)

[RetroDECK](https://retrodeck.net) runs the emulators inside Steam Headless since 2026-11-13: one Flatpak with the ES-DE front end, RetroArch, Dolphin, PCSX2 and others. It reads the same files RomM manages, so RomM stays the place where ROMs are added.

- **Shared library**: the compose file mounts RomM's library read-only at `/mnt/romm`. RetroDECK keeps its own data folder, `~/retrodeck` (`/var/lib/steam-headless/home/retrodeck` on the VM), with one folder per system under `roms/`. The folders of the platforms RomM has are replaced by links: `roms/gc` and `roms/wii` point at `/mnt/romm/roms/gc` and `/mnt/romm/roms/wii`. RetroDECK rebuilds its path settings from its data folder, so the links are used instead of pointing its ROM folder at the mount.
- **Another platform**: create its folder in RomM's library under the name ES-DE uses (RomM recognises those names; `ls ~/retrodeck/roms` in the container lists them), then link it (`rmdir` refuses if RetroDECK's folder already holds games):
  ```bash
  ssh sfcal@10.3.20.55 "docker exec -u 1000 steam-headless sh -c 'cd ~/retrodeck/roms && rm -f snes/systeminfo.txt snes/.directory && rmdir snes && ln -s /mnt/romm/roms/snes snes'"
  ```
- **Starting it**: from the desktop's application menu, from Steam as the non-Steam game "RetroDECK" (also in gaming mode), or from Moonlight as the app "RetroDECK", which Steam Headless adds to Sunshine by itself.
- **Saves and states** stay in `~/retrodeck/saves` and `~/retrodeck/states`; nothing is sent to RomM. RetroArch could sync to RomM (its Cloud Sync, with RomM as the WebDAV server, which the container reaches at `http://127.0.0.1:8085`); that is not set up.
- **BIOS files** go in `~/retrodeck/bios` in RetroDECK's own layout; RomM's `bios/` folder is at `/mnt/romm/bios` to copy from. GameCube and Wii need none.
- **Checked on 2026-11-13**: ES-DE, RetroArch and Dolphin start on the B50 (OpenGL and Vulkan). No game has been run: the library was empty.

RetroDECK lives in the home folder, not in Ansible. It was installed and set up like this, and the same steps restore it on a new home:

1. `docker exec -u 1000 -e HOME=/home/steamheadless -e XDG_RUNTIME_DIR=/run/user/1000 steam-headless flatpak install --user -y flathub net.retrodeck.retrodeck` (6.6 GB).
2. Start RetroDECK once from the desktop: choose **Home Directory**, answer **Yes** to adding it to Steam and **No** to the PS3 and Vita firmware.
3. Make the links above.

## RomM

[RomM](https://docs.romm.app) manages the ROM library and is proxied as `https://roms.ldn.5am.cloud` (container port 8080, host port 8085).

The play ends with `docker compose up -d` for both stacks. Compose recreates a container whenever its stored config hash differs from the current one, which restarts RomM or ends a Steam Headless session. Before deploying while someone is playing, compare the hashes on the VM; identical hashes mean no recreate (not a guarantee: on 2026-11-12 `romm` was recreated with matching hashes):

```bash
ssh sfcal@10.3.20.55 'for p in romm steam-headless; do docker compose --project-directory /opt/$p config --hash="*"; done; docker inspect romm romm-db steam-headless --format "{{.Name}} {{index .Config.Labels \"com.docker.compose.config-hash\"}}"'
```

Back up `/var/lib/romm/db` and `/var/lib/romm/assets` (saves and states); `resources` is a regenerable metadata cache.

## Network

Moonlight and the browser stream talk directly to the VM; they cannot go through Caddy. Sunshine listens on 47984/tcp, 47989/tcp, 47990/tcp, 48010/tcp and 47998-48000/udp; the web interface on 8483/tcp and 8483/udp. `steam.ldn.5am.cloud` is a plain A record for the VM, not a Caddy name.

## ROM library

`romm_library_path` (`/srv/romm/library`) holds `roms/<platform>/<game>` and `bios/<platform>`, RomM's default layout. The library is local to the VM; to use a NAS, set `gaming_nfs: true` in `ansible/inventory/group_vars/site_ldn/app_gaming/vars.yml`, put the mount in `nfs_mounts` in `ansible/inventory/group_vars/site_ldn/nfs.yml` and point `romm_library_path` at the mount.

GameCube games go in `roms/gc/` and Wii games in `roms/wii/` (the play creates both). RomM maps `gc` to its `ngc` platform, and these are the folder names ES-DE in RetroDECK scans; `roms/ngc/` would work for RomM but not RetroDECK.

## Verify in the guest

```bash
ssh sfcal@10.3.20.55
lspci -nn | grep -i display                      # Intel Battlemage G21 [8086:e212]
sudo dmesg | grep -iE 'xe .*SR-IOV|PRELOADED'    # Running in SR-IOV VF mode
ls -l /dev/dri                                   # renderD128
docker exec steam-headless vainfo --display drm --device /dev/dri/renderD128 | grep -c EncSlice
docker exec -u 1000 steam-headless vulkaninfo --summary | grep deviceName
```
