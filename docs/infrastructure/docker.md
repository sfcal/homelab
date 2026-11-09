# Docker Services

All homelab services run as Docker Compose stacks deployed by Ansible. The `docker_service` role handles directory creation, compose template rendering, image pulling, and container lifecycle.

## Media Stack

The media stack provides automated media management and streaming on a dedicated host (`app_mediastack`):

| Service | Purpose |
|---------|---------|
| Plex | Media streaming server |
| Sonarr | TV show management |
| Radarr | Movie management |
| Prowlarr | Indexer management |
| Sabnzbd | Download client |
| Bazarr | Subtitle management |
| Tdarr | Media transcoding |
| Pulsarr | Request management |
| Frigate | Camera/NVR integration |

Deploy with `task ansible:deploy-media ENV=wil`.

## Gaming

Terraria (wil) and Wolf with RomM (ldn) share one playbook on the `app_gaming` host; each environment gets the stacks its group_vars define. Deploy with `task ansible:deploy-gaming ENV=<env>`; see [Gaming](gaming.md).

## Hermes Agent

Hermes Agent (ldn) has its own playbook, which also installs Claude Code and the Claude subscription plugin in the container. Deploy with `task ansible:deploy-hermes ENV=ldn`; see [Hermes Agent](hermes.md).

## Kasm

Kasm (ldn, on the `work` VM, `https://kasm.ldn.5am.cloud`) is the LinuxServer image, which runs Kasm's own Docker daemon inside the container. Its state is under `/var/lib/kasm/`. Deploy with `task ansible:deploy-kasm ENV=ldn`.

Custom workspace images live in `ansible/playbooks/apps/kasm/files/`, one folder per image with a `Dockerfile` (folder names lowercase: they become the image name). Each deploy copies them to `/opt/kasm/images/` and builds every folder inside Kasm's Docker as `localhost/<folder>:latest`, pulling newer base images first. To use one, add a workspace with that image name and restrict it to the work VM's agent (`85a6c3`): the VPS agent ([Kasm Agent](kasm-agent.md)) doesn't have it. The work VM's agent prunes images in Aggressive mode: within 30 s it deletes any image no workspace uses, so save the workspace first, then deploy.

### Deluge

The Deluge workspace runs `localhost/deluge:latest` (`files/deluge/`) on the work VM, with no volume mappings. When a torrent finishes, Deluge's Execute plugin runs `torrent-archive`, which writes it as one uncompressed `<torrent name>.zip` into `~/Downloads`, so Kasm's download panel can fetch it in one go (written as `.zip.part` first, then renamed; `zip -0`, since media doesn't compress). Torrents download to `~/torrents`. Both folders, and Deluge's settings, last only as long as the session: fetch the archives before ending it. The settings come from the image (`core.conf`, `execute.conf`), which Kasm copies into each new session's home; mapping `~/.config` to a host folder would overwrite what's saved there each time. The base stays on the Kasm server's version. Deluge 2.0.3 with libtorrent 2.0 logs a harmless `KeyError: 'disk.num_blocks_cache_hits'` every few seconds.

Workspace settings (Kasm's admin, not this repo): Docker Image `localhost/deluge:latest`, Docker Registry empty, Restrict Image to Kasm Agent `85a6c3`, Volume Mappings `{}`.

## Data-Driven Apps

Most applications use the shared `deploy-app.yml` playbook and are defined in the registry of the site that hosts them, `ansible/inventory/group_vars/site_<env>/apps.yml`. See [Deploy a Service](../guides/deploy-service.md) for the full workflow.

| App | Image | Port |
|-----|-------|------|
| Birdle | `ghcr.io/sfcal/new-birdle` | 8091 |
| Bookstack | `lscr.io/linuxserver/bookstack` | 8074 |
| Ignis (Obsidian) | `nobbe/ignis` | 8082 |
| iSponsorBlockTV | `ghcr.io/dmunozv04/isponsorblocktv` | — |
| KOReader Sync | `koreader/kosync` | 17200 |
| MicroBin | `danielszabo99/microbin` | 8081 |
| Restreamer | `datarhei/restreamer` | 8710 |
| Website | `ghcr.io/sfcal/samuel.computer` | 8090 |

### Ignis

[Ignis](https://github.com/Nystik-gh/ignis) (ldn, on the `work` VM) runs Obsidian in the browser at `https://ignis.ldn.5am.cloud`, behind the Kanidm login: it has no login of its own. Everything it keeps is on the VM's own disk under `/var/lib/work/ignis/`: `vaults/` (one folder per vault, plain Markdown), `data/` (Ignis settings and sync state) and `obsidian-app/` (the Obsidian download, fetched again when missing). A rebuilt VM starts with no vaults.

### iSponsorBlockTV

[iSponsorBlockTV](https://github.com/dmunozv04/iSponsorBlockTV) (ldn, on the `web` VM) skips SponsorBlock segments and ads on YouTube TV apps. It has no web UI and only needs to reach youtube.com, so it has no port or proxy entry. Paired TVs and settings are in `/var/lib/isponsorblocktv/data/config.json` on the VM, written by the setup wizard, not by Ansible; a rebuilt VM needs its TVs paired again. Until a TV is paired the container exits every 10 seconds and restarts.

To pair a TV (also to add another one or change settings), open YouTube on the TV, go to Settings → Link with TV code, then on the VM:

```bash
cd /opt/isponsorblocktv
docker compose run --rm isponsorblocktv setup      # setup-cli for plain prompts
docker compose restart
```

## Infrastructure Services

Infrastructure services have dedicated playbooks rather than using the data-driven pattern:

| Service | Docs |
|---------|------|
| BIND9, Caddy, oauth2-proxy, DDNS, Tailscale | [Networking](networking/index.md) |
| Prometheus, Grafana, Homepage | [Monitoring](monitoring/index.md) (Grafana and Homepage on the OVH VPS) |
| Step-CA | [Certificate Authority](ca/index.md) |

## How It Works

1. **Compose templates** — Jinja2 templates at `ansible/playbooks/apps/<service>/templates/compose.yaml.j2`
2. **Rendering** — Ansible renders templates with environment-specific variables from `group_vars/`
3. **Deployment** — The `docker_service` role creates the service directory, renders the compose file, pulls images, and starts containers
4. **Restart policy** — All containers use `unless-stopped`
5. **LinuxServer images** — Use `PUID`, `PGID`, `UMASK` environment variables for file permissions

## Troubleshooting

**Container not starting** — Check logs: `ssh <host> docker logs <container>`. Common issues: port conflicts, missing environment variables, image not found.

**Image pull failed** — Verify network connectivity on the host. For GHCR images, ensure no rate limiting. Retry with `ssh <host> docker pull <image>`.

**Compose file not updating** — Ansible only re-renders the template when variables change. Force a redeploy by modifying a variable or deleting the deployed compose file on the host.
