/**
 * # Generic VM Module Variables
 */

variable "name" {
  description = "Name of the VM"
  type        = string
}

variable "description" {
  description = "Description of the VM"
  type        = string
  default     = "Virtual Machine"
}

variable "proxmox_node" {
  description = "Proxmox node to deploy to"
  type        = string
}

variable "vmid" {
  description = "VM ID"
  type        = number
}

variable "template_name" {
  description = "Name of the template to clone"
  type        = string
}

variable "tags" {
  description = "Proxmox tags (semicolon-separated)"
  type        = string
  default     = ""
}

variable "onboot" {
  description = "Start VM on boot"
  type        = bool
  default     = true
}

variable "cores" {
  description = "Number of CPU cores"
  type        = number
  default     = 2
}

variable "memory" {
  description = "Memory in MB"
  type        = number
  default     = 2048
}

variable "disk_size" {
  description = "Disk size"
  type        = string
  default     = "20G"
}

variable "storage_pool" {
  description = "Storage pool for VM disks"
  type        = string
}

variable "network_bridge" {
  description = "Network bridge"
  type        = string
  default     = "vmbr0"
}

variable "ip_address" {
  description = "IP address for the VM"
  type        = string
}

variable "gateway" {
  description = "Gateway IP"
  type        = string
}

variable "nameserver" {
  description = "DNS server"
  type        = string
}

variable "ssh_user" {
  description = "SSH username"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key"
  type        = string
}

# -- UEFI / Q35 / PCIe passthrough (optional, for GPU VMs)

variable "bios" {
  description = "BIOS type: seabios or ovmf"
  type        = string
  default     = "seabios"
}

variable "machine" {
  description = "Machine type: pc (default) or q35 (required for PCIe passthrough). Empty string leaves Proxmox default in place."
  type        = string
  default     = ""
}

variable "pci_mapping" {
  description = "Proxmox PCI resource mapping ID for GPU passthrough (e.g. 'b50-vf2'). Empty string disables passthrough."
  type        = string
  default     = ""
}
