/**
 * # Generic VM Module Outputs
 */

output "vm_id" {
  description = "The VM ID"
  value       = proxmox_vm_qemu.vm.vmid
}

output "vm_name" {
  description = "The VM name"
  value       = proxmox_vm_qemu.vm.name
}

output "ip_address" {
  description = "The IP address of the VM"
  value       = var.ip_address
}

output "proxmox_node" {
  description = "The Proxmox node hosting the VM"
  value       = proxmox_vm_qemu.vm.target_node
}
