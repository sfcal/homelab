/**
 * # Docker VM Module Outputs
 */

output "vm_id" {
  description = "ID of the created VM"
  value       = proxmox_vm_qemu.docker_vm.id
}

output "vm_name" {
  description = "Name of the created VM"
  value       = proxmox_vm_qemu.docker_vm.name
}

output "ip_address" {
  description = "IP address of the VM"
  value       = var.ip_address
}

output "proxmox_node" {
  description = "Proxmox node where VM is deployed"
  value       = proxmox_vm_qemu.docker_vm.target_node
}