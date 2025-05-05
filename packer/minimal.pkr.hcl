packer {
  required_plugins {
    proxmox = {
      version = ">= 1.1.2"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

// Basic variables with defaults
variable "proxmox_api_url" {
  type = string
  default = "https://10.2.20.11:8006/api2/json"
}

variable "proxmox_api_token_id" {
  type = string
  default = "root@pam!packer"  // Replace with your actual token ID
}

variable "proxmox_api_token_secret" {
  type = string
  sensitive = true
  default = "d04b70b8-c355-485d-ab4e-ab484dea954d"  // Replace with your actual token
}

variable "proxmox_node" {
  type = string
  default = "wil-pve-01"  // Use your actual node name
}

// Simplest possible source
source "proxmox-iso" "minimal" {
  // Connection settings
  proxmox_url = var.proxmox_api_url
  username = var.proxmox_api_token_id
  token = var.proxmox_api_token_secret
  insecure_skip_tls_verify = true

  // Node settings
  node = var.proxmox_node
  
  // Minimal VM settings
  vm_name = "test-minimal"
  
  // Basic hardware
  cores = "1"
  memory = "512"
  
  // Minimal disk
  disks {
    disk_size = "5G"
    storage_pool = "local-lvm"
    type = "scsi"
  }
  
  // Network
  network_adapters {
    model = "virtio"
    bridge = "vmbr0"
  }
  
  // Simple image URL and temp SSH for Packer
  iso_url = "https://releases.ubuntu.com/24.04/ubuntu-24.04.2-live-server-amd64.iso"
  iso_checksum = "sha256:d6dab0c3a657988501b4bd76f1297c053df710e06e0c3aece60dead24f270b4d"
  iso_storage_pool = "local"
  
  // SSH settings (won't actually connect but needed for config)
  ssh_username = "root"
  ssh_password = "packer"
  ssh_timeout = "15m"
}

build {
  sources = ["source.proxmox-iso.minimal"]
}