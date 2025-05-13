/**
 * # K3s Cluster Module
 *
 * Creates a K3s cluster with master and worker nodes directly on Proxmox
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

# Create master nodes directly with Proxmox
resource "proxmox_vm_qemu" "master_nodes" {
  for_each = local.masters
  
  # General settings
  name        = each.value.name
  desc        = "K3s master node for ${var.cluster_name} cluster"
  target_node = var.proxmox_node
  vmid        = null  # Let Proxmox assign automatically
  agent       = 1     # Enable QEMU Guest Agent
  
  # Clone settings
  clone      = var.template_name
  full_clone = false
  
  # Boot settings
  onboot          = true
  automatic_reboot = true
  
  # Hardware settings
  qemu_os  = "other"
  bios     = "seabios"
  cores    = each.value.cores
  sockets  = 1
  cpu_type = "host"
  memory   = each.value.memory
  
  # Network settings
  network {
    id     = 0
    bridge = var.network_bridge
    model  = "virtio"
  }
  
  # Storage settings
  scsihw = "virtio-scsi-single"
  
  disk {
    storage = var.storage_pool
    size    = each.value.disk_size
    type    = "disk"
    slot    = "virtio0"
  }
  
  # Cloud-init settings
  os_type    = "cloud-init"
  ipconfig0  = var.use_dhcp ? "ip=dhcp" : "ip=${each.value.ip}/24,gw=${var.gateway}"
  nameserver = var.nameserver
  ciuser     = var.ssh_user
  sshkeys    = var.ssh_public_key
  
  # Ensure VMs get unique IDs
  lifecycle {
    ignore_changes = [
      network,
    ]
  }
}

# Create worker nodes directly with Proxmox
resource "proxmox_vm_qemu" "worker_nodes" {
  for_each = local.workers
  
  # General settings
  name        = each.value.name
  desc        = "K3s worker node for ${var.cluster_name} cluster"
  target_node = var.proxmox_node
  vmid        = null  # Let Proxmox assign automatically
  agent       = 1     # Enable QEMU Guest Agent
  
  # Clone settings
  clone      = var.template_name
  full_clone = true
  
  # Boot settings
  onboot          = true
  automatic_reboot = true
  
  # Hardware settings
  qemu_os  = "other"
  bios     = "seabios"
  cores    = each.value.cores
  sockets  = 1
  cpu_type = "host"
  memory   = each.value.memory
  
  # Network settings
  network {
    id     = 0
    bridge = var.network_bridge
    model  = "virtio"
  }
  
  # Storage settings
  scsihw = "virtio-scsi-single"
  
  disk {
    storage = var.storage_pool
    size    = each.value.disk_size
    type    = "disk"
    slot    = "scsi0"
  }
  
  # Cloud-init settings
  os_type    = "cloud-init"
  ipconfig0  = var.use_dhcp ? "ip=dhcp" : "ip=${each.value.ip}/24,gw=${var.gateway}"
  nameserver = var.nameserver
  ciuser     = var.ssh_user
  sshkeys    = var.ssh_public_key
  
  # Ensure VMs get unique IDs
  lifecycle {
    ignore_changes = [
      network,
    ]
  }
}