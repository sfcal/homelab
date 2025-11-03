// Netboot VM Template
// This template creates a VM configured for network/PXE booting
// Designed to work with Netboot.xyz or similar network boot solutions

packer {
  required_plugins {
    proxmox = {
      version = ">= 1.1.2"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

// --- Variable Declarations ---

// Proxmox Connection (Expected from credentials.pkrvars.hcl)
variable "proxmox_api_url" {
  type        = string
  description = "The Proxmox API URL (e.g., https://pve.example.com:8006/api2/json)"
}

variable "proxmox_api_token_id" {
  type        = string
  description = "Proxmox API token ID (e.g., user@realm!tokenid)"
}

variable "proxmox_api_token_secret" {
  type        = string
  sensitive   = true
  description = "Proxmox API token secret"
}

// Environment Specific
variable "proxmox_node" {
  type        = string
  description = "Proxmox node to build on"
}

variable "environment" {
  type        = string
  description = "Environment identifier (e.g., dev, prod, nyc, wil)"
}

variable "template_prefix" {
  type        = string
  default     = "netboot-vm"
  description = "Prefix for template names"
}

// VM Configuration
variable "vm_id" {
  type        = number
  default     = null
  description = "Optional: Specific VM ID for the template (null for auto)"
}

variable "cores" {
  type        = number
  default     = 2
  description = "Number of CPU cores for the VM"
}

variable "memory" {
  type        = number
  default     = 2048
  description = "Memory in MB for the VM"
}

variable "disk_size" {
  type        = string
  default     = "32G"
  description = "Disk size for the primary VM disk (e.g., 32G)"
}

variable "storage_pool" {
  type        = string
  description = "Storage pool for the VM disk"
}

variable "storage_pool_type" {
  type        = string
  description = "Type of the storage pool (e.g., lvm-thin, rbd, dir)"
}

variable "network_bridge" {
  type        = string
  default     = "vmbr0"
  description = "Network bridge for the VM (e.g., vmbr0)"
}

variable "scsi_controller" {
  type        = string
  default     = "virtio-scsi-pci"
  description = "SCSI controller type"
}

variable "bios_type" {
  type        = string
  default     = "ovmf"
  description = "BIOS type: 'seabios' for legacy BIOS or 'ovmf' for UEFI"
}

variable "efi_storage_pool" {
  type        = string
  default     = null
  description = "Storage pool for EFI disk (required if bios_type is 'ovmf')"
}

variable "machine_type" {
  type        = string
  default     = "q35"
  description = "Machine type (q35 for modern, pc for legacy)"
}

// ISO Configuration (Expected from environment var file)
variable "iso_file" {
  type        = string
  description = "Path to the ISO file on Proxmox storage (e.g., local:iso/ubuntu.iso)"
  default     = null // Default to null if iso_url is used
}

variable "iso_url" {
  type        = string
  description = "URL to download the ISO if not present locally"
  default     = null // Default to null if iso_file is used
}

variable "iso_checksum" {
  type        = string
  description = "Checksum for the ISO file (e.g., sha256:xxxx)"
  default     = null // Default to null if iso_file is used
}

variable "iso_storage_pool" {
  type        = string
  description = "Storage pool for the ISO file"
}


// --- Local Variables ---
locals {
  vm_name              = "${var.template_prefix}-${var.environment}"
  template_description = "Netboot-ready VM (${var.environment}) - Built by Packer on ${timestamp()}"
  use_uefi            = var.bios_type == "ovmf"
  use_iso_file = var.iso_file != null && var.iso_file != ""
}

// --- Source Definition ---
source "proxmox-iso" "netboot-vm" {
  // Proxmox Connection Settings
  proxmox_url              = var.proxmox_api_url
  username                 = var.proxmox_api_token_id
  token                    = var.proxmox_api_token_secret
  insecure_skip_tls_verify = true

  // VM General Settings
  node                 = var.proxmox_node
  vm_id                = var.vm_id
  vm_name              = local.vm_name
  template_description = local.template_description

  // Minimal ISO configuration - required by proxmox-iso builder
  // We use Alpine Linux (small ~50MB) but boot order prioritizes network first
  // so this ISO won't actually be used for netbooting
  // ISO Configuration (Conditional logic)
  iso_file           = local.use_iso_file ? var.iso_file : null
  iso_url            = !local.use_iso_file ? var.iso_url : null
  iso_checksum       = !local.use_iso_file ? var.iso_checksum : null
  iso_storage_pool   = var.iso_storage_pool
  unmount_iso        = true


  // VM System Settings
  qemu_agent = false  // No OS installed yet, so no agent
  bios       = var.bios_type
  machine    = var.machine_type

  // EFI Settings (if using UEFI)
  efi_config {
    efi_storage_pool  = local.use_uefi ? (var.efi_storage_pool != null ? var.efi_storage_pool : var.storage_pool) : null
    efi_type          = local.use_uefi ? "4m" : null
    pre_enrolled_keys = local.use_uefi ? false : null
  }

  // VM Hard Disk Settings
  scsi_controller = var.scsi_controller
  disks {
    type         = "virtio"
    disk_size    = var.disk_size
    storage_pool = var.storage_pool
    format       = "raw"
  }

  // VM CPU/RAM
  cores  = var.cores
  memory = var.memory

  // VM Network Settings - Enable PXE boot
  network_adapters {
    model    = "virtio"
    bridge   = var.network_bridge
    firewall = false
  }

  // Boot Configuration - Network boot first
  boot = "order=net0;scsi0;ide2"  // Try network first, disk second, CD last
  
  // Minimal boot commands - just wait briefly
  // The VM will attempt netboot, timeout, then Packer will stop it
  communicator = "none"

  //boot_wait = "30s"
  boot_command = [
    "<wait20>",
    "<enter>",
    "<wait20>",
    "root<enter><wait2>",
    "poweroff<enter>"
  ]
}

// --- Build Definition ---
build {
  name    = "netboot-vm-${var.environment}"
  sources = ["source.proxmox-iso.netboot-vm"]

  // No provisioning needed - VM will netboot
  // Template is ready to clone and boot from network
}
