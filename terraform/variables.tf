/**
 * # Shared Variables
 *
 * Variable definitions for all environments
 */

# -- Provider Configuration
variable "proxmox_api_url" {
  description = "Proxmox API URL"
  type        = string
}

variable "proxmox_api_token_id" {
  description = "Proxmox API token ID"
  type        = string
  sensitive   = true
}

variable "proxmox_api_token_secret" {
  description = "Proxmox API token secret"
  type        = string
  sensitive   = true
}

# -- SSH Configuration
variable "ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
  sensitive   = true
}

# -- VM Configuration
variable "vms" {
  description = "Map of VMs to create"
  type = map(object({
    name           = string
    description    = optional(string, "Virtual Machine")
    proxmox_node   = string
    vmid           = number
    template_name  = string
    ip_address     = string
    gateway        = string
    nameserver     = string
    cores          = optional(number, 2)
    memory         = optional(number, 2048)
    disk_size      = optional(string, "20G")
    storage_pool   = string
    network_bridge = optional(string, "vmbr0")
    onboot         = optional(bool, true)
    ssh_user       = string
  }))
  default = {}
}
