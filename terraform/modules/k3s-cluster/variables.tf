/**
 * # K3s Cluster Module Variables
 *
 * All variables for the K3s cluster module
 */

# -- Cluster Configuration
variable "cluster_name" {
  description = "Name of the K3s cluster"
  type        = string
  default     = "k3s"
}

variable "master_count" {
  description = "Number of master nodes"
  type        = number
  default     = 1
}

variable "worker_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 1
}

# -- Node Settings
variable "proxmox_master_nodes" {
  description = "List of Proxmox nodes for deploying master nodes (should match or exceed master_count)"
  type        = list(string)
}

variable "proxmox_worker_node" {
  description = "Target Proxmox node for worker VMs"
  type        = string
}

variable "template_name" {
  description = "Name of the VM template to clone"
  type        = string
}

# -- Master Node Resources
variable "master_memory" {
  description = "Memory in MB for master nodes"
  type        = number
  default     = 4096
}

variable "master_cores" {
  description = "CPU cores for master nodes"
  type        = number
  default     = 2
}

variable "master_disk_size" {
  description = "Disk size for master nodes"
  type        = string
  default     = "50G"
}

# -- Worker Node Resources
variable "worker_memory" {
  description = "Memory in MB for worker nodes"
  type        = number
  default     = 4096
}

variable "worker_cores" {
  description = "CPU cores for worker nodes"
  type        = number
  default     = 2
}

variable "worker_disk_size" {
  description = "Disk size for worker nodes"
  type        = string
  default     = "50G"
}

# -- Network Configuration
variable "use_dhcp" {
  description = "Use DHCP for IP addressing"
  type        = bool
  default     = false
}

variable "network_prefix" {
  description = "Network prefix for static IPs (e.g., 10.1.10)"
  type        = string
  default     = "10.1.20"
}

variable "master_ip_start" {
  description = "Starting IP address offset for master nodes"
  type        = number
  default     = 51
}

variable "worker_ip_start" {
  description = "Starting IP address offset for worker nodes"
  type        = number
  default     = 41
}

variable "gateway" {
  description = "Network gateway"
  type        = string
  default     = "10.1.20.1"
}

variable "nameserver" {
  description = "DNS server"
  type        = string
  default     = "8.8.8.8"
}

# -- SSH Access
variable "ssh_user" {
  description = "SSH username for cloud-init"
  type        = string
  default     = "ubuntu"
}

variable "ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
}

# -- Additional VM Settings
variable "storage_pool" {
  description = "Storage pool for VM disks"
  type        = string
  default     = "local-lvm"
}

variable "network_bridge" {
  description = "Network bridge for VMs"
  type        = string
  default     = "vmbr0"
}