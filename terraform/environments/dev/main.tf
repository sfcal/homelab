/**
 * # Development Environment
 *
 * This is the main configuration for the development environment.
 */

locals {
  env_name = "dev"
  vm_defaults = {
    target_node   = "nyc-pve-01"
    template_name = "ubuntu-server-dev-base"
    ssh_user      = "sfcal"
  }
}

# Control Plane VM
module "controlplane" {
  source = "../../modules/proxmox-vm"

  vm_name        = "controlplane"
  vm_description = "Kubernetes control plane node"
  target_node    = local.vm_defaults.target_node
  template_name  = local.vm_defaults.template_name
  vmid           = null

  cores     = 2
  memory    = 4096
  disk_size = "20G"

  # Network configuration
  use_dhcp = true # Using DHCP

  # Cloud-init settings
  ciuser         = local.vm_defaults.ssh_user
  nameserver     = "8.8.8.8"
  ssh_public_key = var.ssh_public_key

  # Provisioning settings
  enable_provisioning  = true
  ssh_private_key_path = var.ssh_private_key_path
  provision_ssh_keys   = true
  provision_git        = true
  provision_terraform  = true
  provision_git_repo   = true
  git_repo_url         = var.git_repo_url
  git_branch           = var.git_branch
}

# K3s Cluster
module "k3s_cluster" {
  source = "../../modules/k3s-cluster"

  cluster_name  = "k3s"
  master_count  = 3
  worker_count  = 2
  proxmox_node  = local.vm_defaults.target_node
  template_name = local.vm_defaults.template_name

  # Network configuration
  use_dhcp        = false # Using static IPs
  network_prefix  = "10.1.10"
  master_ip_start = 51
  worker_ip_start = 41
  gateway         = "10.1.20.1"
  nameserver      = "10.1.20.1"

  # SSH configuration
  ssh_user       = local.vm_defaults.ssh_user
  ssh_public_key = var.ssh_public_key

  # Provisioning is disabled for cluster nodes
  enable_provisioning = false
}