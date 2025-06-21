/**
 * # Production Environment Outputs
 *
 * Output values for the production environment
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
  value       = module.dns_servers.dns_servers
}

output "dns_server_ips" {
  description = "DNS server IP addresses"
  value = {
    primary   = module.dns_servers.primary_dns_ip
    secondary = module.dns_servers.secondary_dns_ip
    all       = module.dns_servers.dns_server_ips
  }
}

output "infrastructure_summary" {
  description = "Summary of all infrastructure nodes"
  value = {
    k3s_nodes   = module.k3s_cluster.all_nodes
    dns_servers = module.dns_servers.dns_servers
  }
}