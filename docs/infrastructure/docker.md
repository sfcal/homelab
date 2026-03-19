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

Deploy with `task ansible:deploy-media ENV=wil`. Supports backup and restore:

```bash
task ansible:backup-media ENV=wil
task ansible:restore-media ENV=wil
```

## Data-Driven Apps

Most applications use the shared `deploy-app.yml` playbook and are defined in `ansible/environments/<env>/group_vars/all/apps.yml`. See [Deploy a Service](../guides/deploy-service.md) for the full workflow.

| App | Image | Port |
|-----|-------|------|
| Birdle | `ghcr.io/sfcal/new-birdle` | 8091 |
| Bookstack | `lscr.io/linuxserver/bookstack` | 8074 |
| ConvertX | `ghcr.io/c4illin/convertx` | 3100 |
| CyberChef | `ghcr.io/gchq/cyberchef` | 8071 |
| Games Server | Terraria | 7777 |
| IT-Tools | `corentinth/it-tools` | 8070 |
| Kasm | `lscr.io/linuxserver/kasm` | 4443 |
| MicroBin | `danielszabo99/microbin` | 8081 |
| OpenBooks | `evanbuss/openbooks` | 8072 |
| Restreamer | `datarhei/restreamer` | 8710 |
| RomM | `rommapp/romm` | 8085 |
| Seafile | `seafileltd/seafile-mc` | 8080 |
| Stirling PDF | `stirlingtools/stirling-pdf` | 8073 |
| Website | `ghcr.io/sfcal/samuel.computer` | 8090 |

## Infrastructure Services

Infrastructure services have dedicated playbooks rather than using the data-driven pattern:

| Service | Docs |
|---------|------|
| BIND9, Caddy, DDNS, Tailscale | [Networking](networking/index.md) |
| Prometheus, Grafana, Homepage | [Monitoring](monitoring/index.md) |
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
