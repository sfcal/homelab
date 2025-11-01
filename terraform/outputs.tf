/**
 * # Shared Outputs
 *
 * Output values for all VMs
 */

output "vms" {
  description = "Map of all created VMs with their details"
  value = {
    for key, vm in module.vms : key => {
      vm_id        = vm.vm_id
      vm_name      = vm.vm_name
      ip_address   = vm.ip_address
      proxmox_node = vm.proxmox_node
    }
  }
}

output "vm_summary" {
  description = "Summary of all VMs grouped by name"
  value = {
    for key, vm in module.vms : vm.vm_name => vm.ip_address
  }
}
