/**
 * # Proxmox VM Module Outputs
 *
 * All outputs from the Proxmox VM module
 */

output "vm_id" {
  description = "The ID of the VM"
  value       = proxmox_vm_qemu.vm.id
}

output "vm_name" {
  description = "The name of the VM"
  value       = proxmox_vm_qemu.vm.name
}

output "ipv4_address" {
  description = "The IPv4 address of the VM"
  value       = proxmox_vm_qemu.vm.default_ipv4_address
}

output "target_node" {
  description = "The Proxmox node where the VM is running"
  value       = proxmox_vm_qemu.vm.target_node
}