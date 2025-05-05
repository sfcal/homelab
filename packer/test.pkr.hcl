packer {
  required_plugins {
    proxmox = {
      version = ">= 1.1.2"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

// Variable declarations with defaults
variable "proxmox_api_url" {
  type = string
}

variable "proxmox_api_token_id" {
  type = string
}

variable "proxmox_api_token_secret" {
  type = string
  sensitive = true
}

variable "proxmox_node" {
  type = string
}

variable "ssh_username" {
  type = string
  default = "sfcal"
}

variable "ssh_password" {
  type = string
  sensitive = true
}

variable "iso_url" {
  type = string
}

variable "iso_checksum" {
  type = string
}

variable "iso_storage_pool" {
  type = string
}

source "proxmox-iso" "test" {
  // Connection
  proxmox_url = var.proxmox_api_url
  username = var.proxmox_api_token_id
  token = var.proxmox_api_token_secret
  insecure_skip_tls_verify = true

  // VM settings
  node = var.proxmox_node
  vm_name = "test-template"
  
  // Use direct ISO parameters instead of boot_iso block
  iso_url = var.iso_url
  iso_checksum = var.iso_checksum
  iso_storage_pool = var.iso_storage_pool
  unmount_iso = true
  
  // Minimal required settings
  cores = "1"
  memory = "1024"
  
  disks {
    disk_size = "10G"
    storage_pool = "local-lvm"
    type = "virtio"
  }
  
  network_adapters {
    model = "virtio"
    bridge = "vmbr0"
  }
  
  // Skip cloud-init and boot command for now
  cloud_init = false
  boot_wait = "5s"
  boot_command = []
  
  // SSH settings
  ssh_username = var.ssh_username
  ssh_password = var.ssh_password
  ssh_timeout = "15m"
}

build {
  sources = ["source.proxmox-iso.test"]
}