# Ansible Configuration for K3s Cluster Deployment

This directory contains Ansible playbooks and roles for automated deployment and management of a K3s Kubernetes cluster. The automation is designed to be flexible, idempotent, and supports both single-node and high-availability configurations.

## Table of Contents
- [Architecture Overview](#architecture-overview)
- [Directory Structure](#directory-structure)
- [Key Components](#key-components)
- [Deployment Flow](#deployment-flow)
- [Configuration Guide](#configuration-guide)
- [Usage Examples](#usage-examples)
- [Multi-Environment Deployment](#multi-environment-deployment)

## Architecture Overview

This Ansible configuration automates the deployment of a K3s Kubernetes cluster with the following features:

1. High-availability control plane with multiple master nodes
2. Worker node support for distributed workloads
3. Virtual IP (kube-vip) for reliable API server access
4. MetalLB for service load balancing
5. Flannel for container networking
6. Secure token-based cluster authentication
7. Proper systemd service configuration

The automation follows infrastructure-as-code best practices and is designed to be idempotent (can be run multiple times safely).

## Directory Structure

```
ansible/
├── .gitignore                 # Ignores kubeconfig file
├── ansible.cfg                # Ansible configuration
├── group_vars/                # Group variables
│   └── all.yml                # Variables applied to all hosts
├── hosts.ini                  # Inventory file defining host groups
├── reset.yml                  # Playbook to reset/remove K3s
├── roles/                     # Role definitions
│   ├── download/              # Downloads K3s binaries
│   ├── k3s_agent/             # Configures K3s agent nodes
│   ├── k3s_server/            # Configures K3s server nodes
│   ├── k3s_server_post/       # Post-installation configuration
│   ├── prereq/                # Sets up system prerequisites
│   └── reset/                 # Handles cluster reset tasks
└── site.yml                   # Main playbook for deployment
```

## Key Components

### Playbooks

1. **site.yml**
   - The main playbook that orchestrates the entire K3s deployment
   - Applies roles in the correct sequence to build the cluster
   - Handles both initial deployment and updates

2. **reset.yml**
   - Removes K3s components and cleans up the system
   - Useful for redeploying or decommissioning the cluster

### Roles

1. **prereq**
   - Sets system timezone
   - Enables IPv4/IPv6 forwarding
   - Configures system settings required for Kubernetes

2. **download**
   - Downloads the correct K3s binary for the target architecture
   - Verifies checksums for security

3. **k3s_server**
   - Installs and configures K3s server (master) nodes
   - Sets up high-availability with kube-vip
   - Configures token authentication
   - Creates kubeconfig for cluster access

4. **k3s_agent**
   - Installs and configures K3s agent (worker) nodes
   - Joins nodes to the cluster using the secure token

5. **k3s_server_post**
   - Configures MetalLB for service load balancing
   - Applies post-installation settings

6. **reset**
   - Stops K3s services
   - Unmounts filesystems
   - Removes binaries, configuration, and data

## Deployment Flow

The deployment follows this sequence:

1. **Preparation**
   - System prerequisites are configured
   - K3s binaries are downloaded

2. **Server Deployment**
   - First master initializes the cluster
   - Additional masters join the cluster
   - kube-vip is deployed for high-availability
   - MetalLB manifests are prepared

3. **Agent Deployment**
   - Worker nodes are configured
   - Workers join the cluster using the secure token

4. **Post-Configuration**
   - MetalLB is fully configured
   - Load balancer IP ranges are set
   - Kubeconfig is exported for cluster access

## Configuration Guide

### Inventory Setup

The `hosts.ini` file defines the cluster nodes:

```ini
[master]
10.1.10.51    # Master node 1
10.1.10.52    # Master node 2
10.1.10.53    # Master node 3

[node]
10.1.10.41    # Worker node 1
10.1.10.42    # Worker node 2

[k3s_cluster:children]
master
node
```

### Key Variables

The `group_vars/all.yml` file contains important configuration options:

```yaml
# K3s version
k3s_version: v1.30.2+k3s2

# User for SSH access
ansible_user: sfcal

# API server virtual IP address
apiserver_endpoint: 10.1.10.222

# Network interface for flannel
flannel_iface: eth0

# Cluster authentication token
k3s_token: some-SUPER-DEDEUPER-secret-password

# MetalLB configuration
metal_lb_mode: layer2
metal_lb_ip_range: 10.1.10.140-10.1.10.150
```

### Security Considerations

- The `k3s_token` should be changed to a secure random value
- SSH keys should be properly configured for `ansible_user`
- Consider using Ansible Vault for sensitive variables

## Usage Examples

### Standard Deployment

To deploy the K3s cluster:

```bash
# Verify the inventory
ansible-inventory --graph

# Check connectivity
ansible all -m ping

# Deploy the cluster
ansible-playbook site.yml
```

### Adding Nodes

To add more nodes:

1. Add the node IP addresses to `hosts.ini` under the appropriate group
2. Run the playbook again:
   ```bash
   ansible-playbook site.yml
   ```

### Reset/Remove Cluster

To completely remove K3s from all nodes:

```bash
ansible-playbook reset.yml
```

## Multi-Environment Deployment

This configuration can be extended to support multiple environments, such as WIL and NYC locations, by creating environment-specific inventory and variable files.

### Directory Structure for Multi-Environment

```
ansible/
├── environments/
│   ├── wil/
│   │   ├── hosts.ini          # WIL-specific inventory
│   │   └── group_vars/        # WIL-specific variables
│   │       └── all.yml
│   └── nyc/
│       ├── hosts.ini          # NYC-specific inventory
│       └── group_vars/        # NYC-specific variables
│           └── all.yml
├── roles/                     # Shared roles
└── site.yml                   # Main playbook
```

### Environment-Specific Configuration

Each environment would have customized variables:

**WIL Environment (environments/wil/group_vars/all.yml)**
```yaml
apiserver_endpoint: 10.1.10.222
metal_lb_ip_range: 10.1.10.140-10.1.10.150
```

**NYC Environment (environments/nyc/group_vars/all.yml)**
```yaml
apiserver_endpoint: 10.1.20.222
metal_lb_ip_range: 10.1.20.140-10.1.20.150
```

### Deploying to a Specific Environment

```bash
# Deploy to WIL environment
ansible-playbook -i environments/wil/hosts.ini site.yml

# Deploy to NYC environment
ansible-playbook -i environments/nyc/hosts.ini site.yml
```

This approach allows for consistent automation across multiple environments while maintaining environment-specific configurations.