# Quick Start Guide

This guide will help you deploy the homelab infrastructure from scratch. Follow these steps in order to set up your complete Kubernetes cluster.

## Overview

The deployment process consists of 6 main steps:

1. **Prerequisites** - Set up your environment
2. **Build Execution Environment** - Create the tools container
3. **Create VM Templates** - Build base images with Packer
4. **Provision VMs** - Deploy infrastructure with Terraform
5. **Deploy K3s** - Install Kubernetes with Ansible
6. **Bootstrap GitOps** - Set up Flux for application management

## Step 0: Prerequisites

Before starting, ensure you have:

- A Proxmox server (or cluster) running
- Docker and Docker Compose installed locally
- Git installed
- SSH key pair generated
- At least 16GB RAM and 200GB storage available

### Clone the Repository

```bash
git clone https://github.com/sfcal/homelab.git
cd homelab
```

### Generate SSH Keys (if needed)

```bash
ssh-keygen -t ed25519 -C "your-email@example.com"
```

## Step 1: Build Execution Environment

Create a containerized environment with all necessary tools:

```bash
# Build the container
cd docker/exe
docker build -t homelab-exe .

# Create an alias for convenience
alias homelab='docker run -it --rm \
  -v "$HOME/.ssh:/home/devops/.ssh" \
  -v "$HOME/.kube:/home/devops/.kube" \
  -v "$PWD:/workspace" \
  -e ENV=dev \
  homelab-exe'

# Test the environment
homelab terraform version
homelab ansible --version
```

## Step 2: Create VM Templates with Packer

### Configure Packer Variables

```bash
cd packer/environments/dev
cp credentials.prod.pkrvars.hcl.example credentials.dev.pkrvars.hcl

# Edit with your Proxmox details
vim credentials.dev.pkrvars.hcl
```

Example configuration:
```hcl
proxmox_api_url = "https://your-proxmox:8006/api2/json"
proxmox_api_token_id = "root@pam!packer"
proxmox_api_token_secret = "your-secret-token"
ssh_password = "temporary-password"
```

### Build the Template

```bash
cd packer
make build TEMPLATE=base ENV=dev
```

## Step 3: Provision VMs with Terraform

### Configure Terraform Variables

```bash
cd terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars

# Edit with your configuration
vim terraform.tfvars
```

### Deploy Infrastructure

```bash
make deploy ENV=dev
```

This creates:
- 3 Master nodes: `10.1.20.51-53`
- 2 Worker nodes: `10.1.20.41-42`

## Step 4: Deploy K3s with Ansible

### Configure Ansible

Review the inventory and configuration:

```bash
cd ansible
cat environments/dev/hosts.ini
vim environments/dev/group_vars/all.yml
```

Key settings to verify:
- `apiserver_endpoint`: Virtual IP for the cluster
- `k3s_token`: Change from default!
- `metal_lb_ip_range`: LoadBalancer IP range

### Deploy K3s

```bash
make deploy-k3s ENV=dev
```

### Verify Installation

```bash
# Copy kubeconfig
cp kubeconfig ~/.kube/config

# Check cluster
kubectl get nodes
kubectl get pods -A
```

## Step 5: Bootstrap Flux GitOps

### Install Flux CLI

```bash
curl -s https://fluxcd.io/install.sh | sudo bash
```

### Bootstrap Flux

```bash
flux bootstrap github \
  --owner=sfcal \
  --repository=homelab \
  --branch=main \
  --path=./kubernetes/cluster/dev \
  --personal
```

### Monitor Deployment

```bash
# Watch Flux sync
flux get kustomizations

# Check core services
kubectl get pods -n traefik
kubectl get pods -n cert-manager
kubectl get pods -n longhorn-system
```

## Step 6: Access Services

Once deployed, access your services:

- **Traefik**: https://traefik.local.samuelcalvert.com
- **Grafana**: https://grafana.local.samuelcalvert.com
- **Longhorn**: https://longhorn.local.samuelcalvert.com

## Next Steps

- [Deploy applications](../how-to-guides/deploy-apps.md)
- [Configure monitoring](../how-to-guides/monitoring.md)
- [Set up backups](../how-to-guides/backups.md)

## Troubleshooting

### Common Issues

1. **Packer build fails**: Check Proxmox API credentials and network connectivity
2. **Terraform timeout**: Ensure Proxmox has sufficient resources
3. **K3s won't start**: Verify network configuration and firewall rules
4. **Flux sync errors**: Check GitHub token permissions

For more help, see the [FAQ](../reference/faq.md) or open an issue on GitHub.