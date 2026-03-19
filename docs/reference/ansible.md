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
| `deploy-all` | Full infrastructure deployment (runs `site.yml`) |
| `deploy-networking` | BIND9, Caddy, DDNS, Tailscale |
| `deploy-ca` | Step-CA certificate authority |
| `deploy-ntp` | Chrony NTP server |
| `deploy-monitoring` | Prometheus, Grafana, Homepage |
| `deploy-external-monitoring` | External Uptime Kuma |
| `deploy-media` | Plex and *arr stack |
| `deploy-homeassistant` | Home Assistant |
| `deploy-app APP=<name>` | Single data-driven app |
| `ping` | Test connectivity to all hosts |
| `backup-media` | Backup media stack configs |
| `restore-media` | Restore media stack from backup |

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
| `networking/deploy.yml` | `infra_networking` | BIND9, Caddy, DDNS, Tailscale |
| `ca/deploy.yml` | `infra_ca` | Step-CA |
| `ntp/deploy.yml` | `infra_ntp` | Chrony |
| `monitoring/deploy.yml` | `infra_monitoring` | Prometheus, Grafana, Homepage |

### Data-Driven Apps

Most applications use the shared `deploy-app.yml` playbook. Apps are defined in `ansible/environments/<env>/group_vars/all/apps.yml`:

```yaml
birdle:
  host_group: app_birdle
  images:
    - ghcr.io/sfcal/new-birdle:latest
  port: 8091
```

The `deploy-app.yml` playbook reads the app config, includes the `docker_service` role, and deploys the Docker Compose template from `ansible/playbooks/apps/<name>/templates/compose.yaml.j2`.

### Custom App Playbooks

Apps that need more than Docker Compose (e.g., media stack with backup/restore) have custom playbooks at `ansible/playbooks/apps/<name>/deploy.yml`.

| App | Reason for Custom Playbook |
|-----|---------------------------|
| Media stack | Backup/restore tasks, complex multi-container setup |
| Home Assistant | Custom configuration management |

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
| `deploy_path` | required | Base deployment path |
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
│   │   └── monitoring/deploy.yml
│   └── apps/
│       ├── birdle/templates/compose.yaml.j2
│       ├── media/deploy.yml
│       └── ... (16 app directories)
├── roles/
│   ├── common/
│   ├── docker_service/
│   ├── tailscale/
│   └── nfs_mount/
└── environments/
    └── <env>/
        ├── hosts.ini
        └── group_vars/
```

## Troubleshooting

**Connection refused** — Verify the VM is running and the IP in `hosts.ini` is correct. Test with `ssh sfcal@<ip>`.

**"No hosts matched"** — The host group in the playbook doesn't match any group in `hosts.ini`. Check group names match (e.g., `infra_networking`, `app_birdle`).

**Handler not triggered** — Handlers only run when a task reports `changed`. If you need to force a restart, use `--force-handlers` or run the service command directly.

**Secrets decryption failure** — Ensure the Age key is at `~/.config/sops/age/keys.txt` and `community.sops` is installed.
