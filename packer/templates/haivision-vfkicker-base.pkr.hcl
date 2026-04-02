// Haivision VF Kicker iPXE Boot Template
// Builds a Proxmox template that boots into iPXE with an embedded boot script
// that automatically runs DHCP and chains the Haivision VF Kicker installer.
// Custom iPXE ISO built by: task docker:ipxe-builder
// No manual iPXE commands required.

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

// Unused but declared so shared credentials file does not cause errors
variable "ssh_password" {
  type        = string
  sensitive   = true
  default     = null
  description = "Unused - declared for credentials file compatibility"
}

// Environment Specific
variable "proxmox_node" {
  type        = string
  description = "Proxmox node to build on"
}

variable "environment" {
  type        = string
  description = "Environment identifier (e.g., ldn, wil)"
}

variable "template_prefix" {
  type        = string
  description = "Prefix for template names (e.g., haivision-vfkicker)"
}

// VM Configuration
variable "vm_id" {
  type        = number
  default     = null
  description = "Optional: Specific VM ID for the build VM (null for auto)"
}

variable "cores" {
  type        = number
  description = "Number of CPU cores for the VM"
}

variable "memory" {
  type        = number
  description = "Memory in MB for the VM"
}

variable "disk_size" {
  type        = string
  description = "Disk size for the primary VM disk (e.g., 50G)"
}

variable "storage_pool" {
  type        = string
  description = "Storage pool for the VM disk"
}

variable "storage_pool_type" {
  type        = string
  description = "Type of the storage pool (e.g., lvm, dir, zfspool, rbd)"
}

variable "network_bridge" {
  type        = string
  description = "Network bridge for the VM (e.g., vmbr0)"
}

variable "qemu_agent" {
  type        = bool
  description = "Enable QEMU Guest Agent"
}

variable "scsi_controller" {
  type        = string
  description = "SCSI controller type (e.g., virtio-scsi-pci)"
}

variable "cpu_type" {
  type        = string
  description = "CPU type for the VM (e.g., host, kvm64)"
}

variable "network_model" {
  type        = string
  description = "Network adapter model (e.g., e1000, virtio)"
}

// ISO Configuration
variable "iso_file" {
  type        = string
  description = "Path to the iPXE ISO on Proxmox storage (e.g., local:iso/ipxe.iso)"
  default     = null
}

variable "iso_url" {
  type        = string
  description = "URL to download the iPXE ISO if not present locally"
  default     = null
}

variable "iso_checksum" {
  type        = string
  description = "Checksum for the ISO file"
  default     = null
}

variable "iso_storage_pool" {
  type        = string
  description = "Storage pool for the ISO file on Proxmox"
}

// --- Local Variables ---
locals {
  vm_name              = "${var.template_prefix}-${var.environment}-base"
  template_description = "Haivision VF Kicker iPXE Boot (${var.environment}) - Built by Packer on ${timestamp()}"
  use_iso_file         = var.iso_file != null && var.iso_file != ""
}

// --- Source Definition ---
source "proxmox-iso" "haivision-vfkicker-base" {
  // Proxmox Connection
  proxmox_url              = var.proxmox_api_url
  username                 = var.proxmox_api_token_id
  token                    = var.proxmox_api_token_secret
  insecure_skip_tls_verify = true

  // VM General Settings
  node                 = var.proxmox_node
  vm_id                = var.vm_id
  vm_name              = local.vm_name
  template_description = local.template_description

  // ISO Configuration - standard iPXE ISO for manual chainloading
  iso_file         = local.use_iso_file ? var.iso_file : null
  iso_url          = !local.use_iso_file ? var.iso_url : null
  iso_checksum     = !local.use_iso_file ? var.iso_checksum : null
  iso_storage_pool = var.iso_storage_pool
  unmount_iso      = false // Keep ISO attached so clones boot into iPXE

  // VM System Settings
  qemu_agent = var.qemu_agent
  cpu_type   = var.cpu_type

  // VM Hard Disk Settings
  scsi_controller = var.scsi_controller
  disks {
    type         = "scsi"
    disk_size    = var.disk_size
    storage_pool = var.storage_pool
    format       = "raw"
  }

  // VM CPU/RAM
  cores  = var.cores
  memory = var.memory

  // VM Network Settings
  network_adapters {
    model    = var.network_model
    bridge   = var.network_bridge
    firewall = false
  }

  // Boot from CD-ROM (iPXE ISO)
  boot      = "c"
  boot_wait = "5s"

  // No SSH - this template has no OS to connect to
  communicator = "none"
}

// --- Build Definition ---
build {
  name    = "haivision-vfkicker-${var.environment}"
  sources = ["source.proxmox-iso.haivision-vfkicker-base"]

  // No provisioners - the template is just a VM shell with iPXE ISO attached
}
