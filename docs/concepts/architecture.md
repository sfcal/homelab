# Architecture

<!-- TODO: expand -->

An overview of how the homelab infrastructure layers connect.

## Pipeline

The deployment follows a four-stage pipeline:

```mermaid
graph LR
    A[Packer] -->|VM templates| B[Terraform]
    B -->|Provisioned VMs| C[Ansible]
    C -->|Configured hosts| D[Docker]
```

1. **Packer** builds base VM templates (Ubuntu/Debian) on Proxmox with cloud-init
2. **Terraform** provisions VMs from those templates across environments
3. **Ansible** configures the VMs, installs Docker, and deploys services
4. **Docker Compose** runs all application containers

## Environments

| Environment | Purpose | Location |
|-------------|---------|----------|
| WIL | Development and primary | Local |
| NYC | Production | Remote |

## Key Design Decisions

- Docker Compose over Kubernetes for simplicity
- Split-horizon DNS with BIND9 for internal resolution
- SOPS + Age for secrets encryption at rest
- Caddy for automatic HTTPS with minimal configuration
- Task runner for unified command interface
