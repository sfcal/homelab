# Proxmox Provider
# ---
# Initial Provider Configuration for Proxmox

terraform {
  required_version = ">= 0.13.0"

  required_providers {
    proxmox = {
      source = "telmate/proxmox"
      version = "3.0.1-rc6"
    }
  }
}

variable "proxmox_api_url" {
  type = string
}

variable "proxmox_api_token_id" {
  type = string
}

variable "proxmox_api_token_secret" {
  type = string
}

variable "ssh_public_key" {
  
  # -- Public SSH Key, you want to upload to VMs and LXC containers.
  type = string
  sensitive = true
}

variable "ssh_private_key" {
  type = string
  description = "Path to SSH private key for GitHub authentication"
  default = "~/.ssh/id_ed25519"
  sensitive = true
}

variable "git_repo_url" {
  type = string
  description = "URL of the Git repository containing Docker configuration"
  default = "git@github.com:sfcal/homelab.git"
}

variable "git_branch" {
  type = string
  description = "Git branch to use"
  default = "main"
}

provider "proxmox" {
  pm_api_url = var.proxmox_api_url
  pm_api_token_id = var.proxmox_api_token_id
  pm_api_token_secret = var.proxmox_api_token_secret
  pm_tls_insecure = true
}
