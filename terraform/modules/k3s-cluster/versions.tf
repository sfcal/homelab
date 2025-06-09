terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.1-rc8"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}