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

## Multi-Environment Support

This repository supports multiple environments with location-based naming:

- **WIL**: Development/testing environment
- **NYC**: Production environment

Each environment can have its own configuration while sharing common base components.

## Deployment - Zero to Hero

There are 4 steps to fully deploy this homelab from scratch.

### Step 0: Prerequisites
### Step 1: Machine Preparation
### Step 2: Packer Template Generation
### Step 3: Terraform VM Deployment
### Step 4: Ansible Kubernetes Installation

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
