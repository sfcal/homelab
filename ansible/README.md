# Homelab Ansible Infrastructure

This repository contains Ansible playbooks and roles for managing a homelab infrastructure including:

- K3s Kubernetes Cluster
- DNS Servers
- Proxmox virtualization
- NTP Services
- Metal as a Service (MaaS)

## Directory Structure

- `inventories/`: Contains environment-specific inventories and variables
  - `dev/`: Development environment
  - `prod/`: Production environment
- `playbooks/`: Top-level playbooks for various infrastructure components
- `roles/`: Ansible roles organized by function
- `collections/`: Custom Ansible collections (if any)

## Usage

Use the Makefile to run common tasks:

```bash
# Deploy K3s cluster in dev environment
make deploy ENV=dev

# Deploy DNS servers in prod environment
make deploy-dns ENV=prod
```

## Requirements

- Ansible 2.11 or higher
- SSH access to target servers
