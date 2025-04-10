/**
 * # K3s Cluster Module Outputs
 *
 * All outputs from the K3s cluster module
 */

output "master_nodes" {
  description = "Information about the master nodes"
  value = {
    for idx, node in module.master_nodes : 
    idx => {
      name = node.vm_name
      ip   = node.ipv4_address
      id   = node.vm_id
    }
  }
}

output "worker_nodes" {
  description = "Information about the worker nodes"
  value = {
    for idx, node in module.worker_nodes : 
    idx => {
      name = node.vm_name
      ip   = node.ipv4_address
      id   = node.vm_id
    }
  }
}

output "master_ips" {
  description = "IP addresses of all master nodes"
  value = [for node in module.master_nodes : node.ipv4_address]
}

output "worker_ips" {
  description = "IP addresses of all worker nodes"
  value = [for node in module.worker_nodes : node.ipv4_address]
}

output "all_nodes" {
  description = "All nodes in the cluster"
  value = concat(
    [for node in module.master_nodes : {
      name = node.vm_name
      ip   = node.ipv4_address
      role = "master"
    }],
    [for node in module.worker_nodes : {
      name = node.vm_name
      ip   = node.ipv4_address
      role = "worker"
    }]
  )
}