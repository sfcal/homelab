/**
 * # Terraform and Provider Versions
 *
 * Terraform and provider version constraints
 */

terraform {
  required_version = ">= 1.0.0"

  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.1-rc8"
    }
  }
}