terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.2-rc05"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}