/**
 * # NYC Environment Outputs
 */

output "vms" {
  description = "All VMs in NYC environment"
  value       = module.infrastructure.vms
}

output "vm_summary" {
  description = "VM summary for NYC environment"
  value       = module.infrastructure.vm_summary
}
