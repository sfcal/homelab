/**
 * # DNS Server Module Variables
 *
 * Variables for the DNS server module
 */

# -- VM Configuration
variable "name" {
  description = "Name of the DNS server VM"
  type        = string
}

variable "description" {
  description = "Description for the VM"
  type        = string
  default     = "DNS Server - BIND9"
}

variable "proxmox_node" {
  description = "Proxmox node to deploy the VM on"
  type        = string
}

variable "vmid" {
  description = "VM ID"
  type        = number
}

variable "template_name" {
  description = "Name of the VM template to clone"
  type        = string
}

# -- VM Resources
variable "memory" {
  description = "Memory in MB"
  type        = number
  default     = 2048
}

variable "cores" {
  description = "CPU cores"
  type        = number
  default     = 2
}

variable "disk_size" {
  description = "Disk size"
  type        = string
  default     = "20G"
}

# -- Network Configuration
variable "ip_address" {
  description = "IP address for the DNS server"
  type        = string
}

variable "gateway" {
  description = "Network gateway"
  type        = string
}

variable "nameserver" {
  description = "DNS server for the VM to use"
  type        = string
  default     = "1.1.1.1"
}

variable "network_bridge" {
  description = "Network bridge"
  type        = string
  default     = "vmbr0"
}

# -- Storage Configuration
variable "storage_pool" {
  description = "Storage pool for VM disk"
  type        = string
  default     = "vm-disks"
}

# -- SSH Configuration
variable "ssh_user" {
  description = "SSH username"
  type        = string
  default     = "ubuntu"
}

variable "ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
  sensitive   = true
}

# -- Boot Configuration
variable "onboot" {
  description = "Start VM on boot"
  type        = bool
  default     = true
}