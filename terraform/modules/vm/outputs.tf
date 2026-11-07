/**
 * # Generic VM Module Outputs
 */

output "vm_id" {
  description = "The VM ID"
  value       = proxmox_virtual_environment_vm.vm.vm_id
}

output "vm_name" {
  description = "The VM name"
  value       = proxmox_virtual_environment_vm.vm.name
}

output "ip_address" {
  description = "The IP address of the VM"
  value       = var.ip_address
}

output "proxmox_node" {
  description = "The Proxmox node hosting the VM"
  value       = proxmox_virtual_environment_vm.vm.node_name
}
