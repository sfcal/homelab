# Packer

<!-- TODO: expand with template details and build instructions -->

VM template creation for Proxmox using HashiCorp Packer.

## Overview

Packer builds base VM images that Terraform uses to provision VMs. Templates include cloud-init for automated first-boot configuration.

## Templates

| Template | Base OS | Purpose |
|----------|---------|---------|
| `ubuntu-server-base` | Ubuntu Server | Primary VM template |
| `debian-bookworm-base` | Debian 12 | Alternative base template |

## Configuration

Templates are defined in HCL files under `packer/templates/` with environment-specific variables in `packer/environments/`.

## Usage

```bash
task packer:build
```
