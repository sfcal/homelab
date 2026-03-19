# Packer

Packer builds cloud-init-enabled VM templates on Proxmox.

## Quick Start

```bash
# Build Ubuntu Server template
task packer:build-ubuntu ENV=wil

# Build Debian Bookworm template
task packer:build-debian ENV=wil

# Build Netboot VM template
task packer:build-netboot ENV=wil

# Clean up logs and ISOs
task packer:clean
```

## Templates

| Template | File | Description |
|----------|------|-------------|
| Ubuntu Server | `ubuntu-server-base.pkr.hcl` | Ubuntu Server with Docker, Node Exporter, Lazydocker |
| Debian Bookworm | `debian-bookworm-base.pkr.hcl` | Debian base with Docker |
| Netboot | — | PXE boot template |

Templates produce images named `<template>-<env>-base` (e.g., `ubuntu-server-wil-base`).

## What Templates Include

The Ubuntu Server template (primary) installs:

1. Cloud-init configuration for Proxmox
2. Docker and Docker Compose
3. Lazydocker (terminal UI for Docker)
4. Node Exporter v1.9.1 (Prometheus metrics)
5. Cleanup (remove SSH keys, machine ID, apt cache)

## File Structure

```
packer/
├── templates/
│   ├── ubuntu-server-base.pkr.hcl      # Ubuntu template definition
│   └── debian-bookworm-base.pkr.hcl    # Debian template definition
└── environments/
    ├── wil/
    │   ├── ubuntu-variables.pkrvars.hcl     # Ubuntu build variables
    │   ├── debian-variables.pkrvars.hcl     # Debian build variables
    │   └── credentials.wil.pkrvars.hcl      # Proxmox API tokens (encrypted)
    └── ldn/
```

## Key Variables

| Variable | Description |
|----------|-------------|
| `proxmox_api_url` | Proxmox API endpoint (e.g., `https://proxmox:8006/api2/json`) |
| `proxmox_api_token_id` | API token ID (e.g., `packer@pve!packer`) |
| `proxmox_api_token_secret` | API token secret (encrypted) |
| `proxmox_node` | Target Proxmox node |
| `environment` | Environment name (used in template naming) |
| `template_prefix` | Template name prefix (e.g., `ubuntu-server`) |
| `cores` | CPU cores for build VM |
| `memory` | RAM for build VM |
| `disk_size` | Disk size for template |
| `iso_file` | ISO path on Proxmox storage |

## Credentials

Proxmox API credentials are stored in SOPS-encrypted files:

```bash
# Edit credentials
sops packer/environments/wil/credentials.wil.pkrvars.hcl
```

## Troubleshooting

**401 Unauthorized** — The Proxmox API token is invalid or lacks permissions. Verify the token in `credentials.<env>.pkrvars.hcl` (decrypt with `sops`). The token needs `VM.Allocate`, `VM.Clone`, `Datastore.AllocateSpace`, and related permissions.

**Template name conflict** — A template with the same name already exists. Delete the old template from Proxmox first: `qm destroy <vmid>`.

**ISO not found** — The `iso_file` path must match an ISO uploaded to Proxmox storage. Check with `pvesm list <storage>` on the Proxmox host.

**Build hangs at SSH** — The VM can't reach the internet for package installation, or cloud-init hasn't configured networking. Check Proxmox network bridge and VLAN settings.
