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

output "infrastructure_summary" {
  description = "Summary of all infrastructure nodes"
  value = {
    k3s_nodes = module.k3s_cluster.all_nodes
  }
}