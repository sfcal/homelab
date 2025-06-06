/**
 * # Development Environment
 *
 * This is the main configuration for the development environment.
 */

locals {
  env_name = "dev"
}

# K3s Cluster
module "k3s_cluster" {
  source = "../../modules/k3s-cluster"

  cluster_name = "k3s"
  
  # Deploy one master and one worker on each Proxmox node
  proxmox_nodes = ["nyc-pve-01", "nyc-pve-02", "nyc-pve-03"]
  
  template_name = "ubuntu-server-dev-base"

  # Storage settings
  storage_pool   = "vm-disks"
  network_bridge = "vmbr0"

  # Network configuration
  use_dhcp        = false
  network_prefix  = "10.1.20"
  master_ip_start = 51
  worker_ip_start = 41
  gateway         = "10.1.20.1"
  nameserver      = "10.1.20.1"

  # SSH configuration
  ssh_user       = "sfcal"
  ssh_public_key = var.ssh_public_key
}