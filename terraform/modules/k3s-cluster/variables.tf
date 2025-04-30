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
variable "proxmox_node" {
  description = "Target Proxmox node for all VMs"
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
  default     = "10.1.10"
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
  default     = "10.1.10.1"
}

variable "nameserver" {
  description = "DNS server"
  type        = string
  default     = "10.1.0.1"
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
  sensitive   = true
}

# -- Provisioning
variable "enable_provisioning" {
  description = "Enable VM provisioning"
  type        = bool
  default     = false
}

variable "ssh_private_key_path" {
  description = "Path to SSH private key for provisioning"
  type        = string
  default     = "~/.ssh/id_ed25519"
  sensitive   = true
}

variable "provision_ssh_keys" {
  description = "Provision SSH keys"
  type        = bool
  default     = false
}

variable "provision_git" {
  description = "Install git on nodes"
  type        = bool
  default     = false
}