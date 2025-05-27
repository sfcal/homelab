/**
 * # K3s Cluster Module
 *
 * Creates a K3s cluster with one master and one worker node per Proxmox node
 */

locals {
  # Create a base VMID starting point to avoid conflicts
  vmid_base = 3000
  
  # Create pairs of master and worker nodes for each Proxmox node
  node_pairs = {
    for idx, node in var.proxmox_nodes :
    idx => {
      proxmox_node = node
      master = {
        name      = "${var.cluster_name}-master-${format("%02d", idx + 1)}"
        vmid      = local.vmid_base + (idx * 2) + 1
        ip        = var.use_dhcp ? null : "${var.network_prefix}.${var.master_ip_start + idx}"
        disk_size = var.master_disk_size
        memory    = var.master_memory
        cores     = var.master_cores
      }
      worker = {
        name      = "${var.cluster_name}-worker-${format("%02d", idx + 1)}"
        vmid      = local.vmid_base + (idx * 2) + 2
        ip        = var.use_dhcp ? null : "${var.network_prefix}.${var.worker_ip_start + idx}"
        disk_size = var.worker_disk_size
        memory    = var.worker_memory
        cores     = var.worker_cores
      }
    }
  }
}

# Create master nodes - one per Proxmox node
resource "proxmox_vm_qemu" "master_nodes" {
  for_each = local.node_pairs
  
  # General settings
  name        = each.value.master.name
  desc        = "K3s master node for ${var.cluster_name} cluster on ${each.value.proxmox_node}"
  target_node = each.value.proxmox_node
  vmid        = each.value.master.vmid
  agent       = 1
  
  # Clone settings
  clone      = var.template_name
  full_clone = true
  
  # Boot settings
  onboot           = true
  automatic_reboot = true
  
  # Hardware settings
  qemu_os  = "other"
  bios     = "seabios"
  cores    = each.value.master.cores
  sockets  = 1
  cpu_type = "host"
  memory   = each.value.master.memory
  
  # Network settings
  network {
    id     = 0
    bridge = var.network_bridge
    model  = "virtio"
  }
  
  # Storage settings
  scsihw = "virtio-scsi-single"
  
  disks {
    ide {
      ide0 {
        cloudinit {
          storage = var.storage_pool
        }
      }
    }
    virtio {
      virtio0 {
        disk {
          storage   = var.storage_pool
          size      = each.value.master.disk_size
          iothread  = true
          replicate = false
        }
      }
    }
  }
  
  # Cloud-init settings
  os_type    = "cloud-init"
  ipconfig0  = var.use_dhcp ? "ip=dhcp" : "ip=${each.value.master.ip}/24,gw=${var.gateway}"
  nameserver = var.nameserver
  ciuser     = var.ssh_user
  sshkeys    = var.ssh_public_key
  
  lifecycle {
    ignore_changes = [
      network,
    ]
  }
}

# Create worker nodes - one per Proxmox node
resource "proxmox_vm_qemu" "worker_nodes" {
  for_each = local.node_pairs
  
  # General settings
  name        = each.value.worker.name
  desc        = "K3s worker node for ${var.cluster_name} cluster on ${each.value.proxmox_node}"
  target_node = each.value.proxmox_node
  vmid        = each.value.worker.vmid
  agent       = 1
  
  # Clone settings
  clone      = var.template_name
  full_clone = true
  
  # Boot settings
  onboot           = true
  automatic_reboot = true
  
  # Hardware settings
  qemu_os  = "other"
  bios     = "seabios"
  cores    = each.value.worker.cores
  sockets  = 1
  cpu_type = "host"
  memory   = each.value.worker.memory
  
  # Network settings
  network {
    id     = 0
    bridge = var.network_bridge
    model  = "virtio"
  }
  
  # Storage settings
  scsihw = "virtio-scsi-single"
  
  disks {
    ide {
      ide0 {
        cloudinit {
          storage = var.storage_pool
        }
      }
    }
    virtio {
      virtio0 {
        disk {
          storage   = var.storage_pool
          size      = each.value.worker.disk_size
          iothread  = true
          replicate = false
        }
      }
    }
  }
  
  # Cloud-init settings
  os_type    = "cloud-init"
  ipconfig0  = var.use_dhcp ? "ip=dhcp" : "ip=${each.value.worker.ip}/24,gw=${var.gateway}"
  nameserver = var.nameserver
  ciuser     = var.ssh_user
  sshkeys    = var.ssh_public_key
  
  lifecycle {
    ignore_changes = [
      network,
    ]
  }
}