/**
 * # DNS Server Module Outputs
 *
 * Outputs from the DNS server module
 */

output "vm_id" {
  description = "VM ID"
  value       = proxmox_vm_qemu.dns_server.id
}

output "vm_name" {
  description = "VM name"
  value       = proxmox_vm_qemu.dns_server.name
}

output "ip_address" {
  description = "IP address of the DNS server"
  value       = var.ip_address
}

output "proxmox_node" {
  description = "Proxmox node where the VM is deployed"
  value       = proxmox_vm_qemu.dns_server.target_node
}