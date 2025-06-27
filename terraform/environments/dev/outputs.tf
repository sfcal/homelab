/**
 * # Development Environment Outputs
 *
 * Output values for the development environment
 */

output "k3s_master_ips" {
  description = "IP addresses of the K3s master nodes"
  value       = module.k3s_cluster.master_ips
}

output "k3s_worker_ips" {
  description = "IP addresses of the K3s worker nodes"
  value       = module.k3s_cluster.worker_ips
}

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

output "docker_vm" {
  description = "Docker VM information"
  value = {
    vm_id       = module.docker_vm.vm_id
    vm_name     = module.docker_vm.vm_name
    ip_address  = module.docker_vm.ip_address
    proxmox_node = module.docker_vm.proxmox_node
  }
}

output "infrastructure_summary" {
  description = "Summary of all infrastructure nodes"
  value = {
    k3s_nodes = module.k3s_cluster.all_nodes
    dns_servers = {
      primary = {
        name = module.dns_server.vm_name
        ip   = module.dns_server.ip_address
        node = module.dns_server.proxmox_node
      }
    }
    docker_hosts = {
      primary = {
        name = module.docker_vm.vm_name
        ip   = module.docker_vm.ip_address
        node = module.docker_vm.proxmox_node
      }
    }
  }
}