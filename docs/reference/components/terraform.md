# Terraform Infrastructure for Homelab

This directory contains the Terraform configuration files for deploying a K3s Kubernetes cluster on Proxmox VMs. The infrastructure is designed to be modular, reusable, and easily configurable.

## Table of Contents

- [Directory Structure](#directory-structure)
- [Modules](#modules)
  - [proxmox-vm](#proxmox-vm)
  - [k3s-cluster](#k3s-cluster)
- [Environments](#environments)
  - [Development (dev)](#development-dev)
- [Getting Started](#getting-started)
- [Key Configuration Variables](#key-configuration-variables)
- [Cluster Architecture](#cluster-architecture)
- [Outputs](#outputs)
- [Customization](#customization)
- [Notes](#notes)

## Directory Structure

```
terraform/
├── .gitignore                # Ignores state files, credentials, and other sensitive data
├── environments/             # Environment-specific configurations
│   ├── dev/                  # Development environment configuration
│   │   ├── .gitignore        # Environment-specific files to ignore
│   │   ├── backend.tf        # Local state backend configuration
│   │   ├── main.tf           # Main configuration for deploying infrastructure
│   │   ├── outputs.tf        # Output definitions (IP addresses, summaries)
│   │   ├── providers.tf      # Proxmox provider configuration
│   │   ├── terraform.tfvars.example # Example variables template
│   │   ├── variables.tf      # Variable definitions for the environment
│   │   └── versions.tf       # Terraform and provider version constraints
│   └── prod/                 # Production environment (placeholder for future use)
└── modules/                  # Reusable infrastructure components
    ├── k3s-cluster/          # Kubernetes cluster deployment module
    │   ├── main.tf           # Creates master and worker node sets
    │   ├── outputs.tf        # Exposes cluster node information
    │   ├── variables.tf      # Configurable cluster parameters
    │   └── versions.tf       # Required provider versions
    └── proxmox-vm/           # Proxmox virtual machine module
        ├── main.tf           # VM creation and provisioning logic
        ├── outputs.tf        # Exposes VM details
        ├── variables.tf      # Configurable VM parameters
        └── versions.tf       # Required provider versions
```

## Modules

### proxmox-vm

A reusable module for creating and provisioning Proxmox VMs with consistent configuration.

**Features:**
- Full and linked cloning from templates
- Configurable resources (CPU, memory, disk)
- Static IP or DHCP networking
- Cloud-init integration
- Optional provisioning for:
  - SSH key setup
  - Git installation
  - Terraform installation
  - Git repository cloning

### k3s-cluster

Creates a complete K3s cluster with configurable master and worker nodes.

**Features:**
- Configurable number of master and worker nodes
- Separate resource configurations for masters and workers
- Static IP addressing with configurable ranges
- Uses the proxmox-vm module for VM creation

## Module Hierarchy and Relationships

The configuration follows a hierarchical pattern:

1. **Environment Layer**: The `dev` environment in `environments/dev/main.tf` defines the specific infrastructure needs
2. **Orchestration Layer**: The `k3s-cluster` module in `modules/k3s-cluster/main.tf` manages the cluster composition
3. **Implementation Layer**: The `proxmox-vm` module in `modules/proxmox-vm/main.tf` handles the actual VM creation

This architecture follows infrastructure-as-code best practices by:
- Separating environments (dev/prod)
- Creating reusable components (modules)
- Maintaining a clean separation of concerns
- Providing flexible configuration options
- Abstracting implementation details

## Environments

### Development (dev)

The development environment is fully configured and ready to deploy:

- Defines one control plane VM (for cluster management)
- Creates a 3-node K3s master cluster (for control plane redundancy)
- Deploys 2 K3s worker nodes (for workload execution)
- Configures the network (DHCP for control plane, static IPs for cluster nodes)
- Sets up SSH access with provided keys

## Getting Started

1. **Setup credentials**:
   ```bash
   cd terraform/environments/dev
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your Proxmox credentials and SSH keys
   ```

2. **Initialize Terraform**:
   ```bash
   terraform init
   ```

3. **Plan deployment**:
   ```bash
   terraform plan
   ```

4. **Apply deployment**:
   ```bash
   terraform apply
   ```

## Key Configuration Variables

These are the essential variables you'll need to configure before deploying:

### Required Variables

| Variable | Description | Location |
|----------|-------------|----------|
| `proxmox_api_url` | Proxmox API URL (e.g., "https://proxmox.example.com:8006/api2/json") | terraform.tfvars |
| `proxmox_api_token_id` | Proxmox API token ID (e.g., "terraform@pam!token") | terraform.tfvars |
| `proxmox_api_token_secret` | Proxmox API token secret | terraform.tfvars |
| `ssh_public_key` | SSH public key for VM access | terraform.tfvars |
| `ssh_private_key_path` | Path to SSH private key for provisioning | terraform.tfvars |

### Commonly Adjusted Settings

| Setting | Description | Default | File Location |
|---------|-------------|---------|--------------|
| Master node count | Number of K3s master nodes | 3 | environments/dev/main.tf |
| Worker node count | Number of K3s worker nodes | 2 | environments/dev/main.tf |
| VM resources | CPU, memory, and disk settings | Various | environments/dev/main.tf |
| Network settings | IP addressing scheme | 10.1.10.x | environments/dev/main.tf |

A full list of all configuration variables is available in the respective module directories:
- [Proxmox VM Module Variables](modules/proxmox-vm/variables.tf)
- [K3s Cluster Module Variables](modules/k3s-cluster/variables.tf)

## Cluster Architecture

The default deployment creates:
- **Control Plane**: 1 VM with 2 cores, 4GB RAM
- **K3s Masters**: 3 VMs with 2 cores, 4GB RAM each
- **K3s Workers**: 2 VMs with 2 cores, 4GB RAM each

Network configuration:
- Masters: 10.1.10.51-53
- Workers: 10.1.10.41-42
- Control Plane: DHCP

## Prerequisites

- Proxmox VE server
- Proxmox API token with appropriate permissions
- Ubuntu Server Noble (24.04) VM template named "ubuntu-server-noble"
- SSH keypair for VM access and provisioning

## Outputs

After deployment, Terraform will output:
- IP addresses of the control plane VM
- IP addresses of all K3s master nodes
- IP addresses of all K3s worker nodes
- Complete infrastructure summary

## Customization

The most common customizations can be made by editing just a few files:

1. **Basic Settings**: Edit `terraform.tfvars` in your environment directory
2. **Cluster Configuration**: Modify `main.tf` in your environment directory
3. **Advanced Settings**: Update module parameters in `main.tf`

### Examples

**Adjusting Cluster Size**

In `environments/dev/main.tf`:
```hcl
module "k3s_cluster" {
  source = "../../modules/k3s-cluster"
  
  master_count = 5    # Increase from 3 to 5 masters
  worker_count = 10   # Increase from 2 to 10 workers
}
```

**Customizing VM Resources**

In `environments/dev/main.tf`:
```hcl
module "k3s_cluster" {
  source = "../../modules/k3s-cluster"
  
  master_memory = 8192  # 8GB RAM for masters
  worker_memory = 16384 # 16GB RAM for workers
  master_cores  = 4     # 4 CPU cores for masters
  worker_cores  = 8     # 8 CPU cores for workers
}
```

## Notes

- The Terraform configuration uses the telmate/proxmox provider
- VM provisioning is optional and can be enabled/disabled as needed
- The template assumes Ubuntu-based VMs with cloud-init support
- For HA K3s clusters, a minimum of 3 master nodes is recommended
- The configuration can be extended to support multiple environments (dev, staging, prod)
- The modules can be reused across different projects