/**
 * # Terraform and Provider Versions
 */

terraform {
  required_version = ">= 1.0.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.120.0"
    }
  }
}
