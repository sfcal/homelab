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

variable "ssh_private_key_path" {
  description = "Path to SSH private key for provisioning"
  type        = string
  default     = "~/.ssh/id_ed25519"
  sensitive   = true
}

# -- Git Repository Settings
variable "git_repo_url" {
  description = "URL of the Git repository containing configuration"
  type        = string
  default     = "git@github.com:sfcal/homelab.git"
}

variable "git_branch" {
  description = "Git branch to use"
  type        = string
  default     = "main"
}