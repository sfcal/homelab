# Docker Services

<!-- TODO: expand with per-service configuration details -->

All homelab services run as Docker Compose stacks deployed by Ansible.

## Media Stack

The media stack provides automated media management and streaming:

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

## Infrastructure Services

| Service | Purpose |
|---------|---------|
| Caddy | Reverse proxy with auto-HTTPS |
| BIND9 | Internal DNS server |
| Prometheus | Metrics collection |
| Grafana | Metrics visualization |
| Homepage | Dashboard |
| Tailscale | VPN/subnet routing |

## How It Works

Ansible uses Jinja2 templates to generate `docker-compose.yml` files from group variables, then deploys them using the `docker_service` role. This allows environment-specific configuration while keeping the compose structure consistent.
