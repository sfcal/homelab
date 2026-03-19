# Time Server (Chrony)

Chrony provides NTP time synchronization for all infrastructure nodes. It runs as a native systemd service on a dedicated VM in each environment, synchronizing from upstream NTP servers and serving time to the local network.

!!! note "Deployment order"
    NTP deploys after [Networking](../networking/index.md) and [Step-CA](../ca/index.md), and before monitoring and applications.

## Architecture

```mermaid
graph TD
    Upstream["Upstream NTP Servers\n(NIST, Cloudflare, etc.)"]
    Chrony["Chrony Server\n(.123)"]
    VM1[Infrastructure VMs]
    VM2[Application VMs]

    Upstream -->|sync| Chrony
    Chrony -->|serve time| VM1
    Chrony -->|serve time| VM2
```

The Chrony server synchronizes with multiple upstream NTP sources and acts as a stratum 10 local clock for the network. All VMs in the environment point to the local Chrony server instead of querying public NTP servers directly.

## File Locations

| File | Purpose |
|------|---------|
| `playbooks/infrastructure/ntp/deploy.yml` | Main playbook |
| `playbooks/infrastructure/ntp/tasks/chrony.yml` | Installation and configuration task |
| `playbooks/infrastructure/ntp/templates/servers.conf.j2` | Upstream NTP server list |
| `playbooks/infrastructure/ntp/templates/allow.conf.j2` | Client access allow list |
| `playbooks/infrastructure/ntp/templates/server.conf.j2` | Server mode settings |
| `playbooks/infrastructure/ntp/handlers/main.yml` | Service restart handler |
| `environments/<env>/group_vars/infra_ntp/chrony.yml` | Per-environment NTP variables |

## Hosts

| Environment | IP | FQDN |
|-------------|----|------|
| WIL | `10.2.20.123` | `time.wil.5am.cloud` |
| LDN | `10.3.20.123` | `time.ldn.5am.cloud` |

## Deployment

```bash
task ansible:deploy-ntp ENV=wil
```

The task file:

1. Installs `chrony` via apt
2. Deploys upstream server configuration to `/etc/chrony/conf.d/servers.conf`
3. Deploys client allow list to `/etc/chrony/conf.d/allow.conf`
4. Deploys server mode config to `/etc/chrony/conf.d/server.conf`
5. Enables and starts the `chrony` service
6. Verifies synchronization with `chronyc tracking`
7. Displays status output

### Server Mode Configuration

The `server.conf.j2` template configures Chrony to operate as a local time source:

```
local stratum 10
rtcsync
hwtimestamp *
```

- `local stratum 10` — acts as a time source even if upstream servers are unreachable
- `rtcsync` — synchronizes the system clock with the hardware clock
- `hwtimestamp *` — enables hardware timestamping on all interfaces for precision

<small>**Sources:** [`ansible/playbooks/infrastructure/ntp/tasks/chrony.yml`](https://github.com/sfcal/homelab/blob/main/ansible/playbooks/infrastructure/ntp/tasks/chrony.yml) · [`ansible/playbooks/infrastructure/ntp/templates/server.conf.j2`](https://github.com/sfcal/homelab/blob/main/ansible/playbooks/infrastructure/ntp/templates/server.conf.j2)</small>

## Configuration Reference

All variables are set in `ansible/environments/<env>/group_vars/infra_ntp/chrony.yml`.

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `chrony_ntp_servers` | `list[string]` | Upstream NTP servers (uses geographically local servers per-env) | (per-env) |
| `chrony_allow` | `list[string]` | Networks allowed to query this NTP server | (per-env) |

<small>**Sources:** [`ansible/environments/wil/group_vars/infra_ntp/chrony.yml`](https://github.com/sfcal/homelab/blob/main/ansible/environments/wil/group_vars/infra_ntp/chrony.yml) · [`ansible/playbooks/infrastructure/ntp/templates/servers.conf.j2`](https://github.com/sfcal/homelab/blob/main/ansible/playbooks/infrastructure/ntp/templates/servers.conf.j2) · [`ansible/playbooks/infrastructure/ntp/templates/allow.conf.j2`](https://github.com/sfcal/homelab/blob/main/ansible/playbooks/infrastructure/ntp/templates/allow.conf.j2)</small>

## Common Tasks

### Verify time synchronization

SSH to the NTP server and check the tracking status:

```bash
chronyc tracking
```

Key fields to check:

- **Reference ID** — upstream server currently in use
- **Stratum** — should be 2-3 (one hop from the upstream stratum 1 server)
- **System time** — offset from NTP time (should be sub-millisecond)

### Check connected clients

```bash
chronyc clients
```

### Add a new upstream NTP server

1. Edit `ansible/environments/<env>/group_vars/infra_ntp/chrony.yml`:

    ```yaml
    chrony_ntp_servers:
      # ... existing servers
      - time.google.com
    ```

2. Deploy:

    ```bash
    task ansible:deploy-ntp ENV=wil
    ```

### Allow a new network

1. Add the network CIDR to `chrony_allow`:

    ```yaml
    chrony_allow:
      - 10.2.0.0/16
      - 10.4.0.0/16    # new network
    ```

2. Deploy:

    ```bash
    task ansible:deploy-ntp ENV=wil
    ```
