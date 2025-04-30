# Packer Configuration for Proxmox Templates

This directory contains Packer configuration files for creating VM templates in Proxmox. These templates serve as the foundation for deploying Kubernetes clusters and other infrastructure components.

## Table of Contents
- [Overview](#overview)
- [Directory Structure](#directory-structure)
- [Template Features](#template-features)
- [Build Process](#build-process)
- [Configuration Guide](#configuration-guide)
- [Usage Examples](#usage-examples)
- [Multi-Environment Considerations](#multi-environment-considerations)

## Overview

The Packer configuration automates the creation of Ubuntu Server Noble (24.04) VM templates with the following features:

1. Fully automated installation via cloud-init
2. Pre-installed Docker engine
3. Optimized for Proxmox virtualization
4. Cloud-init integration for dynamic VM provisioning
5. User account with sudo privileges

These templates provide a consistent base for infrastructure deployment across environments, reducing configuration drift and enabling infrastructure-as-code practices.

## Directory Structure

```
packer/
├── proxmox/
│   ├── .gitignore                       # Ignores credential files
│   ├── credentials.pkr.hcl.example      # Example credentials file (not provided in repo files)
│   └── ubuntu-server-noble/             # Ubuntu 24.04 (Noble) template configuration
│       ├── .gitignore                   # Ignores downloaded ISO files
│       ├── files/                       # Configuration files
│       │   └── 99-pve.cfg               # Cloud-init configuration for Proxmox
│       ├── http/                        # HTTP server content for automated installation
│       │   ├── meta-data                # Cloud-init metadata (empty)
│       │   └── user-data                # Cloud-init user data for automated setup
│       └── ubuntu-server-noble-docker.pkr.hcl # Main Packer template configuration
```

## Template Features

The Ubuntu Server Noble template includes:

### System Configuration
- Ubuntu 24.04 LTS base installation
- Minimal installation with only essential packages
- Configured for cloud-init compatibility with Proxmox
- American English locale with UTC timezone
- QEMU guest agent for improved VM management

### Container Support
- Docker Engine pre-installed
- containerd runtime configured
- User added to docker group for non-root usage

### Security Settings
- SSH server installed and configured
- Root login disabled
- Sudo access for the primary user
- SSH key authentication ready

### Storage Optimization
- Direct disk layout for improved performance
- No swap partition for container workloads
- Raw disk format for efficiency in Proxmox

## Build Process

The template build follows this sequence:

1. **Preparation**
   - Packer connects to Proxmox API
   - VM is created with specified configuration
   - Ubuntu Server ISO is attached

2. **Installation**
   - Automated installation via cloud-init
   - Basic system configuration applied
   - Packages installed

3. **Provisioning**
   - Cloud-init integration configured
   - Docker and dependencies installed
   - System optimized for template usage

4. **Finalization**
   - SSH host keys removed (will be regenerated on clone)
   - Machine ID cleared
   - System cleaned and prepared for templating

## Configuration Guide

### Credentials Setup

Create a `credentials.pkr.hcl` file based on the required variables:

```hcl
proxmox_api_url = "https://your-proxmox-server:8006/api2/json"
proxmox_api_token_id = "your-token-id"
proxmox_api_token_secret = "your-token-secret"
ssh_password = "temporary-ssh-password"
```

### Template Customization

Key parameters in `ubuntu-server-noble-docker.pkr.hcl`:

- `node`: Target Proxmox node (currently "pve-dev01")
- `vm_id`: VM ID in Proxmox (currently 9000)
- `vm_name`: Template name (currently "ubuntu-server-noble")
- `cores`, `memory`: VM resources
- `ssh_username`: Username for SSH access (currently "sfcal")

### User Data Configuration

The `user-data` file contains cloud-init configuration:

- User creation with sudo access
- Password and SSH key settings
- Package installation
- Storage configuration

## Usage Examples

### Building the Template

```bash
# Navigate to the template directory
cd packer/proxmox/ubuntu-server-noble

# Initialize Packer plugins
packer init ubuntu-server-noble-docker.pkr.hcl

# Validate the configuration
packer validate -var-file=../credentials.pkr.hcl ubuntu-server-noble-docker.pkr.hcl

# Build the template
packer build -var-file=../credentials.pkr.hcl ubuntu-server-noble-docker.pkr.hcl
```

### Customizing the Build

To customize the template for different requirements:

```bash
# Build with specific variables
packer build \
  -var="vm_name=ubuntu-server-noble-k8s" \
  -var="cores=2" \
  -var="memory=4096" \
  -var-file=../credentials.pkr.hcl \
  ubuntu-server-noble-docker.pkr.hcl
```

## Multi-Environment Considerations

For deploying across multiple environments (like WIL and NYC):

### Template Strategy

Consider these approaches for multi-environment templates:

1. **Shared Templates**
   - Build once, clone to multiple environments
   - Ensure templates are generic enough for all environments
   - Use cloud-init for environment-specific configuration

2. **Environment-Specific Templates**
   - Maintain separate template configurations for each environment
   - Use variables files to define environment differences:

```
packer/
├── proxmox/
│   ├── environments/
│   │   ├── wil/
│   │   │   └── variables.pkr.hcl  # WIL-specific variables
│   │   └── nyc/
│   │       └── variables.pkr.hcl  # NYC-specific variables
│   └── ubuntu-server-noble/
│       └── ubuntu-server-noble-docker.pkr.hcl
```

### Building for Specific Environments

```bash
# Build for WIL environment
packer build \
  -var-file=../credentials.pkr.hcl \
  -var-file=../environments/wil/variables.pkr.hcl \
  ubuntu-server-noble-docker.pkr.hcl

# Build for NYC environment
packer build \
  -var-file=../credentials.pkr.hcl \
  -var-file=../environments/nyc/variables.pkr.hcl \
  ubuntu-server-noble-docker.pkr.hcl
```

This approach allows for consistent template creation across different environments while accommodating environment-specific requirements.