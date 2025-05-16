<div align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/assets/banner.png">
    <source media="(prefers-color-scheme: light)" srcset="docs/assets/banner.png">
    <img alt="Homelab Infrastructure as Code: Complete automation for your home Kubernetes cluster"
         src="docs/assets/banner.png"
         width="50%">
  </picture>

[Getting started] | [Documentation] | [Contributing]
</div>

[Getting Started]: #get-started
[Documentation]: https://homelab.samuel.computer
[Contributing]: CONTRIBUTING.md

# Homelab Infrastructure as Code

A complete infrastructure-as-code solution for managing a home Kubernetes cluster running on Proxmox VMs. This repository contains automation for the entire lifecycle - from VM template creation to Kubernetes application deployment.

## Quick Start

Deploy a complete homelab environment with a single command:

```bash
apt update && apt install -y curl && bash -c "$(curl -fsSL https://raw.githubusercontent.com/sfcal/homelab/refs/heads/main/deploy/controlplane.sh)"
```

## Repository Structure

```
homelab/
├── ansible/           # Ansible playbooks for K3s deployment
├── ansible-runner/    # Docker container for running Ansible
├── deploy/            # Deployment scripts
├── docker-compose/    # Docker Compose stacks for standalone services
├── kubernetes/        # Kubernetes configurations (GitOps with FluxCD)
├── packer/            # Packer templates for Proxmox VMs
└── terraform/         # Terraform modules for infrastructure provisioning
```

## Network Structure
![Network](docs/assets/network.drawio.svg)

## Components

### [Packer](./packer/README.md)

Automates the creation of VM templates in Proxmox with:
- Ubuntu Server 24.04 (Noble)
- Docker pre-installed
- Cloud-init integration for dynamic provisioning
- Optimized for Proxmox virtualization

### [Terraform](./terraform/README.md)

Deploys infrastructure on Proxmox using the templates created by Packer:
- Control plane VM
- K3s master nodes cluster
- K3s worker nodes
- Modular approach for different environments (WIL, NYC)

### [Ansible](./ansible/README.md)

Automates the deployment of K3s Kubernetes clusters:
- High-availability control plane
- Worker nodes
- Load balancer configuration (MetalLB)
- Network setup with kube-vip
- Secure token-based authentication

### [Kubernetes](./kubernetes/README.md)

GitOps-based Kubernetes configuration using FluxCD:
- Core infrastructure services (cert-manager, Traefik, Longhorn)
- Monitoring stack with Prometheus and Grafana
- Application deployments with kustomize
- Multi-environment support (WIL, NYC)

### Docker Compose Stacks

Standalone service stacks for specific use cases:

**Media Stack** ([docker-compose/media-stack](./docker-compose/media-stack/))
- Plex Media Server
- Sonarr, Radarr for media management
- SABnzbd, NZBHydra2 for downloading
- Tdarr for transcoding
- Ombi for media requests

**Monitoring Stack** ([docker-compose/monitoring-stack](./docker-compose/monitoring-stack/))
- Prometheus for metrics collection
- Grafana for visualization
- InfluxDB and Telegraf for time-series data
- Various exporters for specialized metrics

## Deployment Flow

1. **Template Creation**: Packer builds Ubuntu VM templates in Proxmox
2. **Infrastructure Deployment**: Terraform provisions VMs from templates
3. **Kubernetes Setup**: Ansible configures K3s cluster on VMs
4. **Application Deployment**: FluxCD deploys applications to Kubernetes

## Multi-Environment Support

This repository supports multiple environments with location-based naming:

- **WIL**: Development/testing environment
- **NYC**: Production environment

Each environment can have its own configuration while sharing common base components.

## Running with Ansible Runner

For consistent execution of Ansible playbooks, you can use the included Ansible Runner container:

```bash
# Build the container
cd ansible-runner
docker-compose build

# Run the container
docker-compose up -d

# Execute Ansible inside the container
docker exec -it ansible-runner ansible-playbook /runner/site.yml
```

## Prerequisites

- Proxmox VE server (tested with 8.0+)
- SSH access to Proxmox
- Proxmox API token for automation
- Network with DHCP (or static IP configuration)
- Git for version control
- Internet access for downloading packages

## Maintenance and Updates

- **Templates**: Rebuild Packer templates when OS updates are needed
- **Infrastructure**: Use Terraform to scale or modify VM resources
- **Kubernetes**: Update through GitOps with FluxCD
- **Applications**: Manage through Kubernetes manifests or Docker Compose for standalone services

## Other Resources

- [Dotfiles](https://github.com/sfcal/.home) - My personal configuration files

## Related Projects

These projects have been an inspiration to my homelab

- [onedr0p/cluster-template](https://github.com/onedr0p/cluster-template) - _ template for deploying a Talos Kubernetes cluster including Flux for GitOps_
- [ChristianLempa/homelab](https://github.com/ChristianLempa/homelab) - _This is my entire homelab documentation files. Here you'll find notes, setups, and configurations for infrastructure, applications, networking, and more._
- [khuedoan/homelab](https://github.com/khuedoan/homelab) - _Fully automated homelab from empty disk to running services with a single command._
- [ricsanfre/pi-cluster](https://github.com/ricsanfre/pi-cluster) - _Pi Kubernetes Cluster. Homelab kubernetes cluster automated with Ansible and FluxCD_
- [techno-tim/k3s-ansible](https://github.com/techno-tim/k3s-ansible) - _The easiest way to bootstrap a self-hosted High Availability Kubernetes cluster. A fully automated HA k3s etcd install with kube-vip, MetalLB, and more. Build. Destroy. Repeat._

## License

This project is licensed under the GPLv3 License - see the LICENSE file for details.
