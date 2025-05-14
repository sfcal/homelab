/**
 * # Development Environment Variables
 *
 * Variable definitions for the development environment
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
