/**
 * # Generic VM Module
 *
 * Creates a single VM in Proxmox from a template
 */

resource "proxmox_vm_qemu" "vm" {
  # General settings
  name        = var.name
  description = var.description
  target_node = var.proxmox_node
  vmid        = var.vmid
  agent       = 1
  tags        = var.tags

  # Clone settings
  clone      = var.template_name
  full_clone = true

  # Boot settings
  start_at_node_boot = var.onboot
  automatic_reboot   = true

  # Hardware settings
  qemu_os = "other"
  bios    = var.bios
  machine = var.machine != "" ? var.machine : null
  memory  = var.memory

  cpu {
    cores   = var.cores
    sockets = 1
    type    = "host"
  }

  # EFI disk is inherited from the cloned template (which packer builds with
  # efi_config{}). Declaring it here causes telmate to create a fresh EFI disk
  # on clone and orphan the cloned one as "Unused Disk 0".

  # PCIe passthrough via Proxmox resource mapping -- only when mapping ID provided
  dynamic "pcis" {
    for_each = var.pci_mapping != "" ? [1] : []
    content {
      pci0 {
        mapping {
          mapping_id = var.pci_mapping
          pcie       = true
        }
      }
    }
  }

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
