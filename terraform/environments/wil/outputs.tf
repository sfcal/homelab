/**
 * # Production Environment Outputs
 *
 * Output values for the production environment
 */

output "dns_servers" {
  description = "DNS server information"
  value = {
    vm_id       = module.dns_server.vm_id
    vm_name     = module.dns_server.vm_name
    ip_address  = module.dns_server.ip_address
    proxmox_node = module.dns_server.proxmox_node
  }
}

output "dns_server_ips" {
  description = "DNS server IP addresses"
  value = {
    primary   = module.dns_server.ip_address
    secondary = null
    all       = [module.dns_server.ip_address]
  }
}

output "infrastructure_summary" {
  description = "Summary of all infrastructure nodes"
  value = {
    dns_servers = {
      vm_id       = module.dns_server.vm_id
      vm_name     = module.dns_server.vm_name
      ip_address  = module.dns_server.ip_address
      proxmox_node = module.dns_server.proxmox_node
    }
  }
}