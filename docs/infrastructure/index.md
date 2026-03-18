# Infrastructure

Reference documentation for each layer of the infrastructure pipeline.

## Pipeline

- [**Packer**](packer.md) — VM template creation for Proxmox
- [**Terraform**](terraform.md) — VM provisioning and lifecycle management
- [**Ansible**](ansible.md) — Configuration management and service deployment
- [**Docker Services**](docker.md) — Container definitions and compose templates

## Infrastructure Services

Deployed by Ansible in dependency order:

1. [**Networking**](networking/index.md) — DNS (BIND9), reverse proxy (Caddy), dynamic DNS, VPN (Tailscale)
2. [**Certificate Authority**](ca/index.md) — Private CA (Step-CA) for internal TLS certificates
3. [**Time Server**](ntp/index.md) — NTP synchronization (Chrony)
4. [**Monitoring**](monitoring/index.md) — Metrics (Prometheus), dashboards (Grafana, Homepage), uptime (Uptime Kuma)
