/**
 * # Generic VM Module
 *
 * Creates a single VM in Proxmox from a template
 */

# The clone block takes the template's VMID; look it up by name.
data "proxmox_virtual_environment_vms" "template" {
  node_name = var.proxmox_node

  filter {
    name   = "template"
    values = [true]
  }

  filter {
    name   = "name"
    values = [var.template_name]
  }
}

resource "proxmox_virtual_environment_vm" "vm" {
  # General settings
  name        = var.name
  description = var.description
  node_name   = var.proxmox_node
  vm_id       = var.vmid
  tags        = compact(split(";", var.tags))

  agent {
    enabled = true
  }

  # Clone settings
  clone {
    vm_id = one(data.proxmox_virtual_environment_vms.template.vms).vm_id
    full  = true
  }

  # Boot settings
  on_boot = var.onboot

  # Hardware settings
  bios    = var.bios
  machine = var.machine != "" ? var.machine : null

  cpu {
    cores   = var.cores
    sockets = 1
    type    = "host"
  }

  memory {
    dedicated = var.memory
  }

  # The cloned template's EFI disk is kept: bpg only checks its type, so
  # declaring it here does not add a second one.
  dynamic "efi_disk" {
    for_each = var.bios == "ovmf" ? [1] : []
    content {
      datastore_id = var.storage_pool
      type         = "4m"
    }
  }

  # PCIe passthrough via Proxmox resource mapping -- only when mapping ID provided
  dynamic "hostpci" {
    for_each = var.pci_mapping != "" ? [1] : []
    content {
      device  = "hostpci0"
      mapping = var.pci_mapping
      pcie    = true
      rombar  = true # bpg sends rombar=0 when unset
    }
  }

  # Network settings
  network_device {
    bridge = var.network_bridge
    model  = "virtio"
  }

  # Storage settings
  scsi_hardware = "virtio-scsi-single"

  disk {
    interface    = "virtio0"
    datastore_id = var.storage_pool
    size         = tonumber(trimsuffix(var.disk_size, "G"))
    iothread     = true
    replicate    = false
  }

  # Cloud-init settings
  initialization {
    interface    = "ide0"
    datastore_id = var.storage_pool
    upgrade      = false

    ip_config {
      ipv4 {
        address = "${var.ip_address}/24"
        gateway = var.gateway
      }
    }

    dns {
      servers = [var.nameserver]
    }

    user_account {
      username = var.ssh_user
      keys     = compact(split("\n", var.ssh_public_key))
    }
  }

  lifecycle {
    ignore_changes = [
      network_device,
      # The template only matters at creation. clone is never read back, so
      # without this an imported VM (or a renamed template) plans as
      # destroy + recreate.
      clone,
    ]
  }
}
