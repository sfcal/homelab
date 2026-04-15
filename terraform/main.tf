/**
 * # Main Configuration
 *
 * Data-driven VM creation using the generic VM module
 */

module "vms" {
  source   = "./modules/vm"
  for_each = var.vms

  # VM Identity
  name        = each.value.name
  description = each.value.description
  vmid        = each.value.vmid

  # Proxmox Configuration
  proxmox_node  = each.value.proxmox_node
  template_name = each.value.template_name
  tags          = each.value.tags

  # Network Configuration
  ip_address     = each.value.ip_address
  gateway        = each.value.gateway
  nameserver     = each.value.nameserver
  network_bridge = each.value.network_bridge

  # Resource Configuration
  cores     = each.value.cores
  memory    = each.value.memory
  disk_size = each.value.disk_size

  # Storage Configuration
  storage_pool = each.value.storage_pool

  # Boot Configuration
  onboot = each.value.onboot

  # SSH Configuration
  ssh_user       = each.value.ssh_user
  ssh_public_key = var.ssh_public_key

  # UEFI / Q35 / PCIe passthrough (all optional; defaults preserve SeaBIOS behavior)
  bios        = lookup(each.value, "bios", "seabios")
  machine     = lookup(each.value, "machine", "")
  pci_mapping = lookup(each.value, "pci_mapping", "")
}
