/**
 * # Development Environment Outputs
 *
 * Output values for the development environment
 */

output "controlplane_ip" {
  description = "IP address of the control plane VM"
  value       = module.controlplane.ipv4_address
}

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
    controlplane = {
      name = module.controlplane.vm_name
      ip   = module.controlplane.ipv4_address
      role = "controlplane"
    }
    k3s_nodes = module.k3s_cluster.all_nodes
  }
}