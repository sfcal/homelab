# Terraform

<!-- TODO: expand with module details and variable reference -->

VM provisioning on Proxmox using HashiCorp Terraform.

## Overview

Terraform provisions VMs from Packer-built templates. VMs are defined as a map in `terraform.tfvars`, making it easy to add or remove machines.

## Module

The `modules/vm/` module handles generic VM provisioning with configurable:

- CPU, memory, and disk resources
- Network configuration
- Cloud-init settings
- SSH key injection

## Usage

```bash
task terraform:deploy    # Apply infrastructure changes
task terraform:destroy   # Tear down infrastructure
task terraform:clean     # Clean up state
```

## File Structure

```
terraform/
├── main.tf
├── variables.tf
├── outputs.tf
├── providers.tf
├── versions.tf
├── modules/vm/
└── environments/
    ├── wil/
    └── nyc/
```
