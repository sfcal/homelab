# Ansible

Ansible configures VMs and deploys services via Docker Compose.

## Quick Start

```bash
# Deploy everything
task ansible:deploy-all ENV=wil

# Deploy a specific service
task ansible:deploy-networking ENV=wil

# Deploy a data-driven app
task ansible:deploy-app ENV=wil APP=birdle

# Test connectivity
task ansible:ping ENV=wil
```

## Commands

| Command | Description |
|---------|-------------|
| `deploy-all` | Full infrastructure deployment (runs `site.yml`; on ldn the final Proxmox play needs root SSH to the PVE host) |
| `deploy-networking` | BIND9, Caddy, oauth2-proxy, DDNS, Tailscale |
| `deploy-ca` | Step-CA certificate authority |
| `deploy-ntp` | Chrony NTP server |
| `deploy-monitoring` | Prometheus |
| `deploy-dashboard` | Grafana, Homepage, Uptime Kuma and Kanidm on the OVH VPS |
| `deploy-netboot` | netboot.xyz PXE re-imaging |
| `deploy-proxmox` | Proxmox hosts: SR-IOV GPU VFs, PCI resource mappings |
| `deploy-media` | Plex and *arr stack |
| `deploy-homeassistant` | Home Assistant |
| `deploy-frigate` | Frigate NVR |
| `deploy-gaming` | Gaming stacks defined for the environment: Terraria (wil), Wolf and RomM (ldn) |
| `deploy-hermes` | Hermes Agent, Claude Code and the Claude subscription plugin |
| `deploy-app APP=<name>` | Single data-driven app |
| `ping` | Test connectivity to all hosts of the site |

All commands require `ENV=<env>` and are prefixed with `task ansible:`.

## Playbook Pattern

Every playbook follows the same structure:

```yaml
---
- name: Deploy <Service>
  hosts: <host_group>
  become: true

  handlers:
    - name: Include handlers
      ansible.builtin.import_tasks: handlers/main.yml

  pre_tasks:
    - name: Include common prerequisites
      ansible.builtin.include_role:
        name: common

  tasks:
    - name: Deploy service
      ansible.builtin.include_tasks: tasks/<taskname>.yml
```

The `common` role runs on every host first — it updates the apt cache and sets the timezone.

## Deployment Modes

### Infrastructure Playbooks

Infrastructure services have dedicated playbooks in `ansible/playbooks/infrastructure/`:

| Playbook | Hosts | Services |
|----------|-------|----------|
| `networking/deploy.yml` | `infra_networking` | BIND9, Caddy, oauth2-proxy, DDNS, Tailscale |
| `ca/deploy.yml` | `infra_ca` | Step-CA |
| `ntp/deploy.yml` | `infra_ntp` | Chrony |
| `monitoring/deploy.yml` | `infra_monitoring` | Prometheus |
| `dashboard/deploy.yml` | `infra_dashboard` | Tailscale, Grafana, Homepage, Uptime Kuma (OVH VPS) |
| `apps/kasm/deploy.yml` | `app_kasm` | Kasm on the work VM (ldn), workspace images from `files/` |
| `apps/kasm-agent/deploy.yml` | `app_kasm_agent` | Second Kasm agent for Deluge (OVH VPS) |
| `netboot/deploy.yml` | `infra_netboot` | netboot.xyz |
| `proxmox/deploy.yml` | `infra_proxmox` | SR-IOV GPU VFs and PCI mappings on the hypervisor (no `common` role: it is not an Ubuntu VM) |

### Data-Driven Apps

Most applications use the shared `deploy-app.yml` playbook. Apps are defined in the registry of the site that hosts them, `ansible/inventory/group_vars/site_<env>/apps.yml`:

```yaml
birdle:
  host_group: app_birdle
  # renovate: datasource=docker
  image: "ghcr.io/sfcal/new-birdle:latest"
  port: 8091
  proxy:
    name: birdle
    domain: sfc.al
    proxied: true
```

The `deploy-app.yml` playbook reads the app config, includes the `docker_service` role, and deploys the Docker Compose template from `ansible/playbooks/apps/<name>/templates/compose.yaml.j2`. The image pre-pull list is derived from every registry key ending in `image` (top level and one nesting level down) — there is no manual `images:` list. See [Config Reference — App Registry](config.md#app-registry) for the full schema.

### Custom App Playbooks

Apps that need more than Docker Compose (e.g., media stack with NFS mounts) have custom playbooks at `ansible/playbooks/apps/<name>/deploy.yml`.

| App | Reason for Custom Playbook |
|-----|---------------------------|
| Media stack | NFS mount, complex multi-container setup |
| Home Assistant | Custom configuration management |
| Frigate | NFS mount, dedicated compose/config tasks |
| Gaming | Stacks selected per environment (Terraria; Wolf and RomM), kernel modules and udev rules, GPU render-node check, Wolf config seeded once, optional NFS |
| Hermes Agent | Installs Claude Code, the Claude subscription plugin and the `plex-fix` skill inside the running container |

## Roles

| Role | Purpose |
|------|---------|
| `common` | Apt cache update, timezone configuration |
| `docker_service` | Deploy Docker Compose service (create dir, template compose, pull images, start) |
| `tailscale` | Install and configure Tailscale (client or subnet_router mode) |
| `nfs_mount` | Mount NFS shares (used by apps with `nfs: true`) |

### `docker_service` Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `service_name` | required | Service name |
| `service_compose_template` | required | Path to `compose.yaml.j2` |
| `service_user` | `root` | File ownership user |
| `service_group` | `root` | File ownership group |
| `service_images` | `[]` | Images to pre-pull |

## File Structure

```
ansible/
├── playbooks/
│   ├── site.yml                     # Master playbook
│   ├── deploy-app.yml               # Data-driven app deployer
│   ├── infrastructure/
│   │   ├── networking/deploy.yml
│   │   ├── ca/deploy.yml
│   │   ├── ntp/deploy.yml
│   │   ├── monitoring/deploy.yml
│   │   ├── netboot/deploy.yml
│   │   └── proxmox/deploy.yml       # Hypervisor: SR-IOV GPU VFs, PCI mappings
│   └── apps/
│       ├── birdle/templates/compose.yaml.j2
│       ├── media/deploy.yml
│       └── ... (one directory per app)
├── roles/
│   ├── common/
│   ├── docker_service/
│   ├── tailscale/
│   └── nfs_mount/
└── inventory/
    ├── hosts.ini                    # Both sites
    └── group_vars/
```

## Troubleshooting

**Connection refused** — Verify the VM is running and the IP in `hosts.ini` is correct. Test with `ssh sfcal@<ip>`.

**"No hosts matched"** — The host group in the playbook doesn't match any group in `hosts.ini`, or none of its hosts are in the site group `ENV=` picks (`site_<env>`). Check group names match (e.g., `infra_networking`, `app_birdle`).

**Handler not triggered** — Handlers only run when a task reports `changed`. If you need to force a restart, use `--force-handlers` or run the service command directly.

**Secrets decryption failure** — Ensure the Age key is at `~/.config/sops/age/keys.txt` and `community.sops` is installed.
