# Infrastructure

Deep operational reference for each infrastructure service. Deploy in dependency order.

```bash
task ansible:deploy-proxmox ENV=ldn      # 0. Hypervisor (node-exporter; on pve-ldn the GPU's SR-IOV VFs); needs root SSH to the PVE host
task ansible:deploy-networking ENV=wil   # 1. Must be first
task ansible:deploy-ca ENV=wil           # 2. Certificate authority
task ansible:deploy-ntp ENV=wil          # 3. Time server
task ansible:deploy-monitoring ENV=wil   # 4. Metrics and dashboards
```

## Services

0. [**Proxmox Hosts**](proxmox.md) — node-exporter on both hypervisors; SR-IOV GPU virtual functions and PCI resource mappings on pve-ldn
1. [**Networking**](networking/index.md) — DNS (BIND9), reverse proxy (Caddy), dynamic DNS, VPN (Tailscale)
2. [**Certificate Authority**](ca/index.md) — Private CA (Step-CA) for internal TLS
3. [**Time Server**](ntp/index.md) — NTP synchronization (Chrony)
4. [**Monitoring**](monitoring/index.md) — Metrics (Prometheus), checks through the proxy (blackbox-exporter), dashboards and alerts (Grafana and Homepage, on the OVH VPS), uptime (Uptime Kuma)
5. [**Docker Services**](docker.md) — Container definitions and compose templates
6. [**Gaming**](gaming.md) — Wolf (Moonlight streaming) and RomM on the GPU VM (ldn)
7. [**Hermes Agent**](hermes.md) — AI agent on the Claude subscription (ldn)
