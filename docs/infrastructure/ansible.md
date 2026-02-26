# Ansible

<!-- TODO: expand with role details and variable reference -->

Configuration management and service deployment using Ansible.

## Overview

Ansible configures provisioned VMs and deploys all services. A master playbook (`site.yml`) orchestrates the full deployment in dependency order.

## Playbooks

| Playbook | Purpose |
|----------|---------|
| `infrastructure/dns` | BIND9 DNS with DDNS |
| `infrastructure/monitoring` | Prometheus + Grafana |
| `infrastructure/reverse_proxy` | Caddy reverse proxy |
| `infrastructure/tailscale` | Tailscale subnet router |
| `infrastructure/external-monitoring` | Uptime Kuma (VPS) |
| `apps/media` | Plex + *arr media stack |
| `apps/games-server` | Terraria server |
| `apps/website` | Personal website |
| `apps/birdle` | Birdle game |

## Roles

| Role | Purpose |
|------|---------|
| `common` | Base system configuration |
| `docker_service` | Docker Compose service deployment |
| `tailscale` | Tailscale client setup |

## Usage

```bash
task ansible:deploy-all       # Deploy everything
task ansible:deploy-media     # Deploy media stack only
task ansible:deploy-services  # Deploy DNS and reverse proxy
task ansible:ping             # Test connectivity
```
