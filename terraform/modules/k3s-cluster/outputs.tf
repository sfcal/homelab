/**
 * # K3s Cluster Module Outputs
 *
 * All outputs from the K3s cluster module
 */

output "master_nodes" {
  description = "Information about the master nodes"
  value = {
    for idx, node in proxmox_vm_qemu.master_nodes : 
    idx => {
      name = node.name
      ip   = node.default_ipv4_address
      id   = node.id
    }
  }
}

output "worker_nodes" {
  description = "Information about the worker nodes"
  value = {
    for idx, node in proxmox_vm_qemu.worker_nodes : 
    idx => {
      name = node.name
      ip   = node.default_ipv4_address
      id   = node.id
    }
  }
}

output "master_ips" {
  description = "IP addresses of all master nodes"
  value = [for node in proxmox_vm_qemu.master_nodes : node.default_ipv4_address]
}

output "worker_ips" {
  description = "IP addresses of all worker nodes"
  value = [for node in proxmox_vm_qemu.worker_nodes : node.default_ipv4_address]
}

output "all_nodes" {
  description = "All nodes in the cluster"
  value = concat(
    [for node in proxmox_vm_qemu.master_nodes : {
      name = node.name
      ip   = node.default_ipv4_address
      role = "master"
    }],
    [for node in proxmox_vm_qemu.worker_nodes : {
      name = node.name
      ip   = node.default_ipv4_address
      role = "worker"
    }]
  )
}