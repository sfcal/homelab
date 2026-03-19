# Task Commands

All operations run through [Task](https://taskfile.dev/). Pattern: `task <namespace>:<command> ENV=<environment>`.

```bash
# Discover all available tasks
task --list-all
```

## Ansible

| Command | Description |
|---------|-------------|
| `task ansible:deploy-all ENV=wil` | Deploy entire infrastructure (runs `site.yml`) |
| `task ansible:deploy-networking ENV=wil` | DNS, reverse proxy, Tailscale |
| `task ansible:deploy-ca ENV=wil` | Step-CA certificate authority |
| `task ansible:deploy-ntp ENV=wil` | Chrony NTP server |
| `task ansible:deploy-monitoring ENV=wil` | Prometheus, Grafana, Homepage |
| `task ansible:deploy-external-monitoring ENV=wil` | External Uptime Kuma |
| `task ansible:deploy-media ENV=wil` | Plex and *arr stack |
| `task ansible:deploy-homeassistant ENV=wil` | Home Assistant |
| `task ansible:deploy-app ENV=wil APP=<name>` | Deploy a single data-driven app |
| `task ansible:ping ENV=wil` | Test connectivity to all hosts |
| `task ansible:backup-media ENV=wil` | Backup media stack configs |
| `task ansible:restore-media ENV=wil` | Restore media stack from backup |

## Terraform

| Command | Description |
|---------|-------------|
| `task terraform:deploy ENV=wil` | Provision all VMs |
| `task terraform:deploy-vm ENV=wil VM=<key>` | Provision a specific VM |
| `task terraform:destroy ENV=wil` | Destroy all VMs |
| `task terraform:destroy-vm ENV=wil VM=<key>` | Destroy a specific VM |
| `task terraform:clean ENV=wil` | Clean `.terraform`, state, and lock files |

## Packer

| Command | Description |
|---------|-------------|
| `task packer:build-ubuntu ENV=wil` | Build Ubuntu Server template |
| `task packer:build-debian ENV=wil` | Build Debian Bookworm template |
| `task packer:build-netboot ENV=wil` | Build Netboot VM template |
| `task packer:clean` | Clean packer logs and downloaded ISOs |

## CA

| Command | Description |
|---------|-------------|
| `task ca:health ENV=wil` | Check Step-CA health endpoint |
| `task ca:root ENV=wil` | Fetch root CA certificate |
| `task ca:sign ENV=wil CSR=<path>` | Sign a CSR (optional: `DURATION=8760h`) |

## Docker

| Command | Description |
|---------|-------------|
| `task docker:exe` | Build the homelab execution environment container |

## Other

| Command | Description |
|---------|-------------|
| `task tui` | Launch the homelab management TUI |
| `task --list-all` | List all available tasks |

## Variables

| Variable | Used By | Default | Description |
|----------|---------|---------|-------------|
| `ENV` | All | `dev` | Target environment (e.g., `wil`, `ldn`) |
| `VM` | Terraform | — | VM key from `vms.auto.tfvars` |
| `APP` | Ansible | — | App name from `apps.yml` |
| `CSR` | CA | — | Path to certificate signing request |
| `DURATION` | CA | `8760h` | Certificate validity duration |

## Troubleshooting

**"task: Task not found"** — Check the exact task name with `task --list-all`. Namespace and command are separated by `:`.

**Wrong environment** — `ENV` defaults to `dev`. Always pass `ENV=wil` (or your environment) explicitly.

**Ansible timeout** — Add `-vvv` for verbose output: edit the task in `.taskfiles/ansible/Taskfile.yaml` and add `-vvv` to `EXTRA_ARGS`.
