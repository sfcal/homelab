# Ansible

Configuration management and service deployment using Ansible.

## Overview

Ansible configures provisioned VMs and deploys all services. A master playbook (`site.yml`) orchestrates the full deployment in dependency order.

## Playbooks

### Infrastructure

| Playbook | Purpose | Docs |
|----------|---------|------|
| `infrastructure/networking` | DNS (BIND9), reverse proxy (Caddy), DDNS, Tailscale | [Networking](networking/index.md) |
| `infrastructure/ca` | Private certificate authority (Step-CA) | [Certificate Authority](ca/index.md) |
| `infrastructure/ntp` | NTP time server (Chrony) | [Time Server](ntp/index.md) |
| `infrastructure/monitoring` | Prometheus, Grafana, Homepage | [Monitoring](monitoring/index.md) |
| `infrastructure/external-monitoring` | Uptime Kuma on external VPS | [Monitoring](monitoring/index.md#external-monitoring-uptime-kuma) |

### Applications

| Playbook | Purpose |
|----------|---------|
| `apps/media` | Plex + *arr media stack |
| `apps/games-server` | Terraria server |
| `apps/website` | Personal website |
| `apps/birdle` | Birdle game |

## Roles

| Role | Purpose |
|------|---------|
| `common` | Base system configuration (timezone, apt cache) |
| `docker_service` | Generic Docker Compose service deployment |
| `tailscale` | Tailscale VPN client/subnet router setup |

## Usage

```bash
task ansible:deploy-all              # Deploy everything
task ansible:deploy-networking       # Networking stack
task ansible:deploy-ca               # Certificate authority
task ansible:deploy-ntp              # NTP time server
task ansible:deploy-monitoring       # Monitoring stack
task ansible:deploy-external-monitoring  # External uptime monitoring
task ansible:deploy-media            # Media stack
task ansible:ping                    # Test connectivity
```
