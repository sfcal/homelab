/**
 * # WIL Environment Outputs
 */

output "vms" {
  description = "All VMs in WIL environment"
  value       = module.infrastructure.vms
}

output "vm_summary" {
  description = "VM summary for WIL environment"
  value       = module.infrastructure.vm_summary
}
