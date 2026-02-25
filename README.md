<div align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/assets/banner.png">
    <source media="(prefers-color-scheme: light)" srcset="docs/assets/banner.png">
    <img alt="Homelab Infrastructure as Code: Complete automation for your home server infrastructure"
         src="docs/assets/banner.png"
         width="50%">
  </picture>

[Deployment] | [Documentation] | [Contributing]
</div>

[Deployment]: #get-started
[Documentation]: https://homelab.samuel.computer
[Contributing]: CONTRIBUTING.md

# Homelab Infrastructure as Code

A complete infrastructure-as-code solution for managing a home server environment running on Proxmox VMs. This repository contains automation for the entire lifecycle — from VM template creation with Packer, to VM provisioning with Terraform, to service deployment with Ansible and Docker Compose.

## Multi-Environment Support

This repository supports multiple environments with location-based naming:

- **WIL**: Development/testing environment
- **NYC**: Production environment

Each environment can have its own configuration while sharing common base components.

### Network Structure
```
🏗️ WIL Development Environment                      🏢 NYC Production Environment
UDM Pro WIL - 10.2.x.x Network                       UDM Pro NYC - 10.1.x.x Network
├── 🔵 VLAN 1 - Infrastructure (10.2.0.0/24)        ├── 🔵 VLAN 1 - Infrastructure (10.1.0.0/24)
├── 🟢 VLAN 10 - Storage (10.2.10.0/24)             ├── 🟢 VLAN 10 - Storage (10.1.10.0/24)
├── 🔴 VLAN 20 - Virtual Machines (10.2.20.0/24)    ├── 🔴 VLAN 20 - Virtual Machines (10.1.20.0/24)
├── 🟠 VLAN 30 - Servers Misc (10.2.30.0/24)        ├── 🟠 VLAN 30 - PTP Devices (10.1.50.0/24)
├── 🟣 VLAN 200 - Wired Devices (10.2.200.0/24)     ├── 🟣 VLAN 200 - Wired Devices (10.1.200.0/24)
├── 🟣 VLAN 230 - Wireless Devices (10.2.230.0/24)  └── 🟣 VLAN 230 - Wireless Devices (10.1.230.0/24)
└── 🟣 VLAN 245 - IoT Devices (10.2.245.0/24)
```
![Network](docs/assets/network.drawio.svg)

## Services

<details>
<summary>📺 Media</summary>

Plex, Sonarr, Radarr, Prowlarr, Sabnzbd, Bazarr, Tunarr, Pulsarr, Cleanuparr, Huntarr, Tdarr, Frigate

</details>

<details>
<summary>📊 Monitoring</summary>

Prometheus, Grafana, Homepage, Uptime Kuma (external VPS)

</details>

<details>
<summary>🔧 Infrastructure</summary>

DNS (BIND9 with DDNS), Reverse Proxy (Caddy), Tailscale subnet router

</details>

<details>
<summary>🌐 Applications</summary>

Personal website, Birdle (bird identification game), Terraria game server

</details>

### Domains

| Domain | Purpose |
|--------|---------|
| `5am.video` | Media services |
| `wil.5am.cloud` | Internal infrastructure (WIL) |
| `ext.5am.cloud` | External services |
| `sfc.al` | Personal projects |

DNS is split-horizon — internal clients resolve to local IPs via BIND9, external clients use Cloudflare.

## Deployment - Zero to Hero

There are 5 steps to fully deploy this homelab from scratch.

<details>
<summary>📋 Step 0: Prerequisites</summary>

Before starting, ensure you have the following:

#### Software Requirements
- **Docker** and **Docker Compose**
- **Git**
- **SSH key pair** for VM access
- **Task** (Taskfile runner) - [Installation instructions](https://taskfile.dev/installation/)

#### Initial Setup
```bash
# Clone the repository
git clone https://github.com/sfcal/homelab.git
cd homelab

# Verify Taskfile is installed
task --version

# View available tasks
task --list
```

</details>

<details>
<summary>🐳 Step 1: Build Execution Environment</summary>

Create a containerized environment with all necessary tools:

```bash
# Build the homelab execution container
task docker:exe

# Create a convenient alias for running commands
# Add to .bashrc
alias hl='docker run -it --rm \
  -v "$HOME/.ssh:/home/devops/.ssh" \
  -v "$HOME/.kube:/home/devops/.kube" \
  -v "$PWD:/workspace" \
  -v "$HOME/.home:/home/devops/.home" \
  -v "$HOME/.gitconfig:/home/devops/.gitconfig" \
  -e ENV=dev \
  homelab-exe'
```

</details>

<details>
<summary>📦 Step 2: Create VM Templates with Packer</summary>

Generate Ubuntu VM templates for your infrastructure:

#### Configure Packer Variables

1. **Create credentials file:**
```bash
cd packer/environments/dev
cp credentials.dev.pkrvars.hcl.example credentials.dev.pkrvars.hcl
```

2. **Review environment variables:**
```bash
# Check dev environment settings
cat environments/dev/ubuntu-variables.pkrvars.hcl
```

Important variables:
These need to reflect if you are using local storage, ceph, or nfs

```hcl
iso_file             = "local:iso/ubuntu-24.04.2-live-server-amd64.iso"
iso_storage_pool     = "ISOs-Templates"

storage_pool         = "vm-disks"
storage_pool_type    = "rbm"
cloud_init_storage_pool = "vm-disks"
```

#### Build Templates

Choose your template and environment

```bash
# Build base Ubuntu template
hl task packer:build TEMPLATE=base ENV=dev

# Build other templates as needed
# hl task packer:build-ubuntu ENV=dev
# hl task packer:build-debian ENV=dev
# hl task packer:build-netboot ENV=dev
```
</details>

<details>
<summary>🏗️ Step 3: Provision VMs with Terraform</summary>

Deploy your VM infrastructure on Proxmox:

#### Configure Terraform Variables

1. **Create terraform variables:**
```bash
cd terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars
```

2. **Edit terraform.tfvars:**

VMs are defined as a map — each entry specifies the VM name, Proxmox node, resources, and network config:

```hcl
proxmox_api_url          = "https://pve-01.home.example.com:8006/api2/json"
proxmox_api_token_id     = "root@pam!terraform"
proxmox_api_token_secret = "your-secret-here"

ssh_public_key = "ssh-ed25519 AAAA..."

vms = {
  "dns-server" = {
    name          = "dns-server"
    proxmox_node  = "pve-01"
    vmid          = 201
    template_name = "ubuntu-server-base"
    ip_address    = "10.2.20.53/24"
    gateway       = "10.2.20.1"
    nameserver    = "10.2.20.1"
    cores         = 2
    memory        = 2048
    disk_size     = "20G"
    storage_pool  = "vm-disks"
    ssh_user      = "devops"
  }
  # Add more VMs: media-stack, monitoring, reverse-proxy, etc.
}
```

#### Deploy Infrastructure

```bash
# Deploy all VMs
hl task terraform:deploy ENV=dev

# Or deploy a specific VM
# hl task terraform:deploy-vm ENV=dev VM=dns-server
```

</details>

<details>
<summary>⚙️ Step 4: Deploy Services with Ansible</summary>

Install Docker and deploy services to your VMs:

#### Configure Ansible Variables

1. **Review inventory:**
```bash
cd ansible
cat environments/dev/hosts.ini
```

2. **Configure environment settings:**
```bash
# Global settings (domains, timezone, deploy path)
cat environments/dev/group_vars/all.yml

# Unified services list (shared between DNS and reverse proxy)
cat environments/dev/group_vars/services.yml
```

The `services.yml` file is the single source of truth — it defines every service's subdomain, backend host/port, and whether it's proxied through Caddy.

#### Deploy Everything

```bash
# Deploy entire infrastructure in order
hl task ansible:deploy-all ENV=dev
```

#### Or Deploy Individual Stacks

```bash
# Infrastructure
hl task ansible:deploy-services ENV=dev     # DNS + reverse proxy
hl task ansible:deploy-monitoring ENV=dev   # Prometheus, Grafana, Homepage
hl task ansible:deploy-tailscale ENV=dev    # Tailscale subnet router
hl task ansible:deploy-external-monitoring ENV=dev  # Uptime Kuma (external VPS)

# Applications
hl task ansible:deploy-media ENV=dev        # Full media stack
hl task ansible:deploy-website ENV=dev      # Personal website
hl task ansible:deploy-birdle ENV=dev       # Birdle game
hl task ansible:deploy-games ENV=dev        # Terraria server

# Utilities
hl task ansible:ping ENV=dev               # Test connectivity
hl task ansible:backup-media ENV=dev       # Backup media configs
hl task ansible:restore-media ENV=dev      # Restore from backup
```

#### Verify Deployment

```bash
# Test connectivity to all hosts
hl task ansible:ping ENV=dev
```

</details>

## Troubleshooting

Adding a new service? Update `ansible/environments/<env>/group_vars/services.yml` then run:
```bash
hl task ansible:deploy-services ENV=dev
```
This regenerates both DNS records (BIND9) and reverse proxy config (Caddy) from the unified services list.

## Related Projects

These projects have been an inspiration to my homelab

- [onedr0p/cluster-template](https://github.com/onedr0p/cluster-template) - _ template for deploying a Talos Kubernetes cluster including Flux for GitOps_
- [ChristianLempa/homelab](https://github.com/ChristianLempa/homelab) - _This is my entire homelab documentation files. Here you'll find notes, setups, and configurations for infrastructure, applications, networking, and more._
- [khuedoan/homelab](https://github.com/khuedoan/homelab) - _Fully automated homelab from empty disk to running services with a single command._
- [ricsanfre/pi-cluster](https://github.com/ricsanfre/pi-cluster) - _Pi Kubernetes Cluster. Homelab kubernetes cluster automated with Ansible and FluxCD_
- [techno-tim/k3s-ansible](https://github.com/techno-tim/k3s-ansible) - _The easiest way to bootstrap a self-hosted High Availability Kubernetes cluster. A fully automated HA k3s etcd install with kube-vip, MetalLB, and more. Build. Destroy. Repeat._

## Other Resources

- [Dotfiles](https://github.com/sfcal/.home) - My personal configuration files

## License

This project is licensed under the GPLv3 License - see the LICENSE file for details.
