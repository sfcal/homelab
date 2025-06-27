/**
 * # Docker VM Module Provider Requirements
 */

terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = ">= 3.0.0"
    }
  }
}