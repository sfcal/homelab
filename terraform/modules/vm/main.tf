/**
 * # Generic VM Module
 *
 * Creates a single VM in Proxmox from a template
 */

resource "proxmox_vm_qemu" "vm" {
  # General settings
  name        = var.name
  desc        = var.description
  target_node = var.proxmox_node
  vmid        = var.vmid
  agent       = 1

  # Clone settings
  clone      = var.template_name
  full_clone = true

  # Boot settings
  onboot           = var.onboot
  automatic_reboot = true

  # Hardware settings
  qemu_os  = "other"
  bios     = "seabios"
  cores    = var.cores
  sockets  = 1
  cpu_type = "host"
  memory   = var.memory

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
          size      = var.disk_size
          iothread  = true
          replicate = false
        }
      }
    }
  }

  # Cloud-init settings
  os_type    = "cloud-init"
  ipconfig0  = "ip=${var.ip_address}/24,gw=${var.gateway}"
  nameserver = var.nameserver
  ciuser     = var.ssh_user
  sshkeys    = var.ssh_public_key

  lifecycle {
    ignore_changes = [
      network,
    ]
  }
}
