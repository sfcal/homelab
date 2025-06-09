/**
 * # K3s Cluster Module Variables
 *
 * All variables for the K3s cluster module
 */
variable "ssh_private_key_path" {
  description = "Path to SSH private key for configuring VMs"
  type        = string
  default     = "~/.ssh/id_ed25519"
}

# -- Ceph Network Configuration
variable "enable_ceph_network" {
  description = "Enable Ceph network access for nodes"
  type        = bool
  default     = false
}

variable "ceph_network_bridge" {
  description = "Network bridge for Ceph access"
  type        = string
  default     = "vmbr100"
}

variable "ceph_network_prefix" {
  description = "Network prefix for Ceph access IPs (will be suffixed with node number)"
  type        = string
  default     = "10.0.8"  # Will create 10.0.81.x, 10.0.82.x, 10.0.83.x
}

variable "ceph_master_ip_start" {
  description = "Starting IP offset for master nodes on Ceph network"
  type        = number
  default     = 11
}

variable "ceph_worker_ip_start" {
  description = "Starting IP offset for worker nodes on Ceph network"
  type        = number
  default     = 21
}

variable "ceph_target_network" {
  description = "Ceph cluster network to route to"
  type        = string
  default     = "10.0.0.0/24"
}

variable "ceph_mtu" {
  description = "MTU for Ceph network interface"
  type        = number
  default     = 9000
}

# -- Cluster Configuration
variable "cluster_name" {
  description = "Name of the K3s cluster"
  type        = string
  default     = "k3s"
}

variable "proxmox_nodes" {
  description = "List of Proxmox nodes to deploy K3s on (one master and one worker per node)"
  type        = list(string)
  validation {
    condition     = length(var.proxmox_nodes) > 0
    error_message = "At least one Proxmox node must be specified."
  }
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