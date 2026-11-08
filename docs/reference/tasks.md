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
| `task ansible:deploy-monitoring ENV=wil` | Prometheus |
| `task ansible:deploy-dashboard ENV=ovh` | Grafana, Homepage, Uptime Kuma and Kanidm on the OVH VPS |
| `task ansible:deploy-kasm-agent ENV=ovh` | Kasm agent for Deluge on the OVH VPS |
| `task ansible:deploy-netboot ENV=wil` | netboot.xyz PXE re-imaging |
| `task ansible:deploy-proxmox ENV=ldn` | Proxmox hosts: SR-IOV GPU VFs, PCI resource mappings |
| `task ansible:deploy-media ENV=wil` | Plex and *arr stack |
| `task ansible:deploy-homeassistant ENV=wil` | Home Assistant |
| `task ansible:deploy-frigate ENV=wil` | Frigate NVR |
| `task ansible:deploy-gaming ENV=ldn` | Gaming stacks defined for the environment: Terraria (wil), Wolf and RomM (ldn) |
| `task ansible:deploy-hermes ENV=ldn` | Hermes Agent, Claude Code and the Claude subscription plugin |
| `task ansible:deploy-app ENV=wil APP=<name>` | Deploy a single data-driven app |
| `task ansible:deploy-ci-access ENV=wil` | Create the CI deploy user on hosts the deploy workflow targets |
| `task ansible:ping ENV=wil` | Test connectivity to all hosts of the site |

## Terraform

| Command | Description |
|---------|-------------|
| `task terraform:deploy ENV=wil` | Provision all VMs |
| `task terraform:deploy-vm ENV=wil VM=<key>` | Provision a specific VM |
| `task terraform:plan ENV=wil` | Show the plan without applying |
| `task terraform:plan-vm ENV=wil VM=<key>` | Show the plan for a specific VM |
| `task terraform:destroy ENV=wil` | Destroy all VMs |
| `task terraform:destroy-vm ENV=wil VM=<key>` | Destroy a specific VM |
| `task terraform:clean ENV=wil` | Clean `.terraform`, state, and lock files |

## Packer

| Command | Description |
|---------|-------------|
| `task packer:build-ubuntu ENV=wil` | Build Ubuntu Server template |
| `task packer:build-ubuntu-desktop ENV=wil` | Build Ubuntu Desktop template (Ubuntu Server install plus GNOME and KasmVNC) |
| `task packer:build-debian ENV=wil` | Build Debian Bookworm template |
| `task packer:build-netboot ENV=wil` | Build Netboot VM template |
| `task packer:build-windows ENV=ldn` | Build Windows template (UEFI/TPM, unattended install) |
| `task packer:clean` | Clean packer logs and downloaded ISOs |

## CA

| Command | Description |
|---------|-------------|
| `task ca:health ENV=wil` | Check Step-CA health endpoint |
| `task ca:root ENV=wil` | Fetch root CA certificate |
| `task ca:sign ENV=wil CSR=<path>` | Sign a CSR (optional: `DURATION=8760h`) |

## CI

Bootstrap for the GitHub Actions deploy workflow — see [GitOps Deploys](../guides/gitops.md).

| Command | Description |
|---------|-------------|
| `task ci:keys ENV=wil` | Generate the environment's CI SSH + age keys, wire them into `ci.yml` / `.sops.yaml`, re-encrypt its secrets |
| `task ci:known-hosts ENV=wil` | Record host keys of the hosts CI deploys to into `inventory/known_hosts/<env>` |
| `task ci:secrets ENV=wil` | Create the GitHub environment and upload `SSH_DEPLOY_KEY` / `SOPS_AGE_KEY` with `gh` |

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
| `ENV` | All | `ldn` | Target environment (e.g., `wil`, `ldn`) |
| `VM` | Terraform | — | VM key from `vms.auto.tfvars` |
| `APP` | Ansible | — | App name from `apps.yml` |
| `CSR` | CA | — | Path to certificate signing request |
| `DURATION` | CA | `8760h` | Certificate validity duration |

## Troubleshooting

**"task: Task not found"** — Check the exact task name with `task --list-all`. Namespace and command are separated by `:`.

**Wrong environment** — `ENV` defaults to `ldn` (production). Always pass `ENV=wil` (or your environment) explicitly.

**Ansible timeout** — Add `-vvv` for verbose output: edit the task in `.taskfiles/ansible/Taskfile.yaml` and add `-vvv` to `EXTRA_ARGS`.
