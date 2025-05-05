// Main variables declaration file for Packer

// Environment settings
variable "environment" {
  type        = string
  description = "Environment (dev or prod)"
  default     = "dev"
}

variable "proxmox_node" {
  type        = string
  description = "Proxmox node to build on"
}

variable "template_prefix" {
  type        = string
  description = "Prefix for template names"
  default     = "ubuntu-server"
}

// Proxmox connection settings
variable "proxmox_api_url" {
  type        = string
  description = "The Proxmox API URL"
}

variable "proxmox_api_token_id" {
  type        = string
  description = "Proxmox API token ID"
}

variable "proxmox_api_token_secret" {
  type        = string
  sensitive   = true
  description = "Proxmox API token secret"
}

// VM Settings
variable "vm_id" {
  type        = string
  default     = null
  description = "The VM ID to use for the template (null for auto-assign)"
}

variable "vm_name" {
  type        = string
  description = "The name of the VM template"
  default     = ""
}

variable "template_description" {
  type        = string
  default     = "Built with Packer"
  description = "Template description"
}

variable "cores" {
  type        = string
  default     = "2"
  description = "Number of CPU cores"
}

variable "memory" {
  type        = string
  default     = "2048"
  description = "Memory in MB"
}

variable "disk_size" {
  type        = string
  default     = "20G"
  description = "Disk size"
}

variable "storage_pool" {
  type        = string
  default     = "local-lvm"
  description = "Storage pool for VM disk"
}

variable "storage_pool_type" {
  type        = string
  default     = "lvm"
  description = "Storage pool type"
}

// ISO Settings
variable "iso_file" {
  type        = string
  default     = null
  description = "Path to ISO file on Proxmox (e.g., local:iso/ubuntu-24.04.2-live-server-amd64.iso)"
}

variable "iso_url" {
  type        = string
  default     = "https://releases.ubuntu.com/24.04/ubuntu-24.04.2-live-server-amd64.iso"
  description = "URL to download ISO"
}

variable "iso_checksum" {
  type        = string
  default     = "sha256:d6dab0c3a657988501b4bd76f1297c053df710e06e0c3aece60dead24f270b4d"
  description = "Checksum of the ISO"
}

variable "iso_storage_pool" {
  type        = string
  default     = "local"
  description = "Storage pool for ISO file"
}

// SSH Settings
variable "ssh_username" {
  type        = string
  default     = "sfcal"
  description = "SSH username"
}

variable "ssh_password" {
  type        = string
  sensitive   = true
  description = "SSH password"
}

variable "ssh_private_key_file" {
  type        = string
  default     = "~/.ssh/id_ed25519"
  description = "SSH private key file"
}

// Network Settings
variable "network_bridge" {
  type        = string
  default     = "vmbr0"
  description = "Network bridge to use"
}

// Cloud-Init Settings
variable "cloud_init_storage_pool" {
  type        = string
  default     = "local-lvm"
  description = "Storage pool for cloud-init drive"
}