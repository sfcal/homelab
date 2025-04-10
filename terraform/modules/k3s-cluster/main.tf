/**
 * # K3s Cluster Module
 *
 * Creates a K3s cluster with master and worker nodes
 */

locals {
  master_count = var.master_count
  worker_count = var.worker_count
  
  masters = {
    for i in range(local.master_count) :
    i => {
      name     = "${var.cluster_name}-master-${format("%02d", i + 1)}"
      ip       = var.use_dhcp ? null : "${var.network_prefix}.${var.master_ip_start + i}"
      disk_size = var.master_disk_size
      memory   = var.master_memory
      cores    = var.master_cores
    }
  }
  
  workers = {
    for i in range(local.worker_count) :
    i => {
      name     = "${var.cluster_name}-worker-${format("%02d", i + 1)}"
      ip       = var.use_dhcp ? null : "${var.network_prefix}.${var.worker_ip_start + i}"
      disk_size = var.worker_disk_size
      memory   = var.worker_memory
      cores    = var.worker_cores
    }
  }
}

# Create master nodes
module "master_nodes" {
  source = "../proxmox-vm"
  
  for_each = local.masters
  
  vm_name        = each.value.name
  vm_description = "K3s master node for ${var.cluster_name} cluster"
  target_node    = var.proxmox_node
  template_name  = var.template_name
  
  cores    = each.value.cores
  memory   = each.value.memory
  disk_size = each.value.disk_size
  
  use_dhcp   = var.use_dhcp
  static_ip  = each.value.ip
  gateway    = var.gateway
  nameserver = var.nameserver
  ciuser     = var.ssh_user
  
  ssh_public_key = var.ssh_public_key
  
  # Provision only if enabled
  enable_provisioning = var.enable_provisioning
  ssh_private_key_path = var.ssh_private_key_path
  provision_ssh_keys = var.provision_ssh_keys
  provision_git = var.provision_git
  
  # Other hardware settings kept at defaults
}

# Create worker nodes
module "worker_nodes" {
  source = "../proxmox-vm"
  
  for_each = local.workers
  
  vm_name        = each.value.name
  vm_description = "K3s worker node for ${var.cluster_name} cluster"
  target_node    = var.proxmox_node
  template_name  = var.template_name
  
  cores    = each.value.cores
  memory   = each.value.memory
  disk_size = each.value.disk_size
  
  use_dhcp   = var.use_dhcp
  static_ip  = each.value.ip
  gateway    = var.gateway
  nameserver = var.nameserver
  ciuser     = var.ssh_user
  
  ssh_public_key = var.ssh_public_key
  
  # Provision only if enabled
  enable_provisioning = var.enable_provisioning
  ssh_private_key_path = var.ssh_private_key_path
  provision_ssh_keys = var.provision_ssh_keys
  provision_git = var.provision_git
  
  # Other hardware settings kept at defaults
}