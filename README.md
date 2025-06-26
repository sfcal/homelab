<div align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/assets/banner.png">
    <source media="(prefers-color-scheme: light)" srcset="docs/assets/banner.png">
    <img alt="Homelab Infrastructure as Code: Complete automation for your home Kubernetes cluster"
         src="docs/assets/banner.png"
         width="50%">
  </picture>

[Deployment] | [Documentation] | [Contributing]
</div>

[Deployment]: #get-started
[Documentation]: https://homelab.samuel.computer
[Contributing]: CONTRIBUTING.md

# Homelab Infrastructure as Code



A complete infrastructure-as-code solution for managing a home Kubernetes cluster running on Proxmox VMs. This repository contains automation for the entire lifecycle - from VM template creation to Kubernetes application deployment.

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

## Deployment - Zero to Hero

There are 6 steps to fully deploy this homelab from scratch.

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
cp credentials.prod.pkrvars.hcl.example credentials.dev.pkrvars.hcl
```

2. **Review environment variables:**
```bash
# Check dev environment settings
cat environments/dev/variables.pkrvars.hcl
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
```
</details>

<details>
<summary>🏗️ Step 3: Provision VMs with Terraform</summary>

Deploy your K3s cluster infrastructure:

#### Configure Terraform Variables

1. **Create terraform variables:**
```bash
cd terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars
```

2. **Edit main.tf**
These are the network and storage settings for your cluster
```hcl
  # Network configuration
  use_dhcp        = false
  network_prefix  = "10.1.20"
  master_ip_start = 51
  worker_ip_start = 41
  gateway         = "10.1.20.1"
  nameserver      = "10.1.20.1"

  # Storage settings
  storage_pool   = "vm-disks"
  network_bridge = "vmbr0"

  # Nodes for each master worker deployment pair
  proxmox_nodes = ["nyc-pve-01", "nyc-pve-02", "nyc-pve-03"]
```

3. **Single Node**
```
proxmox_nodes = ["nyc-pve-01"]
```
If you are only using a single node with local storage, you will need to modify `modules/k3s-cluster/main.tf`

```hlc
for idx, node in var.proxmox_nodes :
    idx => {
      proxmox_node = node
```

Becomes:

```hlc
  for idx in range(3) :
  idx => {
    proxmox_node = var.proxmox_nodes[0]
```


#### Deploy Infrastructure

```bash
# Deploy the entire infrastructure
hl task terraform:deploy ENV=dev

# Or deploy specific components
# hl task terraform:deploy-k3s ENV=dev
# hl task terraform:deploy-dns ENV=dev
```

This will create:
- **3 Master nodes**: 10.1.20.51, 10.1.20.52, 10.1.20.53
- **3 Worker nodes**: 10.1.20.41, 10.1.20.42, 10.1.20.43

</details>

<details>
<summary>⚙️ Step 4: Deploy K3s with Ansible</summary>

Install and configure your Kubernetes cluster:

#### Configure Ansible Variables

1. **Review inventory:**
```bash
cd ansible
cat environments/dev/hosts.ini
```

2. **Configure cluster settings:**
```bash
# Review cluster configuration
cat environments/dev/group_vars/all.yml

# Key settings to verify:
- apiserver_endpoint: 10.1.20.222
- k3s_token: #(change the default)
- metal_lb_ip_range: 10.1.20.140-10.1.20.150
```

#### Deploy K3s Cluster

```bash
# Deploy the K3s cluster
hl task ansible:deploy-k3s ENV=dev

# Other useful Ansible tasks:
# hl task ansible:ping ENV=dev          # Test connectivity
# hl task ansible:reset-k3s ENV=dev     # Reset cluster
# hl task ansible:deploy-dns ENV=dev    # Deploy DNS servers
```

#### Verify K3s Installation

```bash
# Copy kubeconfig (automatically generated)
cp kubeconfig ~/.kube/config

# Test cluster connectivity
hl kubectl get nodes
```

Expected output:
```
NAME           STATUS   ROLES                       AGE   VERSION
k3s-master-01  Ready    control-plane,etcd,master   5m    v1.30.2+k3s2
k3s-master-02  Ready    control-plane,etcd,master   4m    v1.30.2+k3s2
k3s-master-03  Ready    control-plane,etcd,master   3m    v1.30.2+k3s2
k3s-worker-01  Ready    <none>                      2m    v1.30.2+k3s2
k3s-worker-02  Ready    <none>                      1m    v1.30.2+k3s2
k3s-worker-03  Ready    <none>                      1m    v1.30.2+k3s2
```

# needed for ceph-csi, will add to ansible eventually
```
kubectl label node k3s-master-01 failure-domain/region=homelab failure-domain/zone=zone1
kubectl label node k3s-worker-01 failure-domain/region=homelab failure-domain/zone=zone1

kubectl label node k3s-master-02 failure-domain/region=homelab failure-domain/zone=zone2
kubectl label node k3s-worker-02 failure-domain/region=homelab failure-domain/zone=zone2

kubectl label node k3s-master-03 failure-domain/region=homelab failure-domain/zone=zone3
kubectl label node k3s-worker-03 failure-domain/region=homelab failure-domain/zone=zone3
```

</details>

<details>
<summary>☸️ Step 5: Bootstrap Kubernetes Infrastructure</summary>

Deploy core cluster components using GitOps:

#### Install Flux

```bash
# Bootstrap using Taskfile (recommended)
hl task kubernetes:bootstrap ENV=dev

# Or manually:
flux bootstrap github \
  --owner=sfcal \
  --repository=homelab \
  --branch=main \
  --path=./kubernetes/clusters/dev \
  --personal

# Wait for Flux
kubectl wait --for=condition=ready --timeout=5m -n flux-system pods --all

# Add SOPS secret
kubectl create secret generic sops-age \
  --namespace=flux-system \
  --from-file=age.agekey=$HOME/.config/sops/age/keys.txt

# Trigger reconciliation
flux reconcile source git flux-system
flux reconcile kustomization infrastructure-controllers
```

#### Verify Infrastructure Deployment

Wait for core components to deploy:

```bash
# Watch namespace creation
watch kubectl get namespaces

# Monitor infrastructure deployment
kubectl get kustomizations -n flux-system

# Check core services
kubectl get pods -n traefik
kubectl get pods -n cert-manager
kubectl get pods -n longhorn-system
kubectl get pods -n monitoring
```

#### Access Web Interfaces

Once deployed, access your services:

- **Traefik Dashboard**: https://traefik.local.samuelcalvert.com
- **Grafana**: https://grafana.local.samuelcalvert.com
- **Longhorn**: https://longhorn.local.samuelcalvert.com

</details>

<details>
<summary>🚀 Step 6: Deploy Applications</summary>

Your cluster is now ready for applications:

#### Example: Deploy nginx

```bash
# Applications are managed via GitOps
# Check the nginx example
kubectl get pods -n default
kubectl get ingress

# Access nginx
curl http://nginx.local.samuelcalvert.com
```

#### Add Your Own Applications

1. Create application manifests in `kubernetes/apps/dev/`
2. Add to kustomization.yaml
3. Commit and push - Flux will automatically deploy

</details>
## Troubleshooting  

When external-secrets will not automatically update plex-claim token when updated in 1password. 
Force this change:
```
kubectl delete externalsecret plex-claim-token -n media
kubectl apply -f /home/sfcal/homelab/kubernetes/apps/base/media/plex/externalsecret.yaml
```
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