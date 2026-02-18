// Ubuntu Server Base Template
// This template expects variables to be passed via -var or -var-file.

packer {
  required_plugins {
    proxmox = {
      version = ">= 1.1.2"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

// --- Variable Declarations ---
// These variables MUST be provided via -var or -var-file (e.g., from environment files or credentials.pkrvars.hcl)

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

// Environment Specific (Expected from environment var file or -var)
variable "proxmox_node" {
  type        = string
  description = "Proxmox node to build on"
}

variable "environment" {
  type        = string
  description = "Environment identifier (e.g., dev, prod)"
}

variable "template_prefix" {
  type        = string
  description = "Prefix for template names (e.g., ubuntu-server)"
}

// VM Configuration (Expected from environment var file)
variable "vm_id" {
  type        = number // Changed to number as Proxmox expects integer ID
  default     = null   // Allow null for auto-assignment
  description = "Optional: Specific VM ID for the build VM (null for auto)"
}

variable "cores" {
  type        = number // Changed to number
  description = "Number of CPU cores for the VM"
}

variable "memory" {
  type        = number // Changed to number
  description = "Memory in MB for the VM"
}

variable "disk_size" {
  type        = string
  description = "Disk size for the primary VM disk (e.g., 20G)"
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

// SSH Configuration (Expected from environment var file and credentials.pkrvars.hcl)
variable "ssh_username" {
  type        = string
  description = "SSH username for Packer to connect to the VM"
}

variable "ssh_password" {
  type        = string
  sensitive   = true
  description = "SSH password for Packer to connect to the VM"
}

variable "ssh_private_key_file" {
  type        = string
  default     = null // Make optional if password auth is primary
  description = "Path to SSH private key file for Packer connection"
}

// Cloud-Init Configuration (Expected from environment var file)
variable "cloud_init_storage_pool" {
  type        = string
  description = "Storage pool for the Cloud-Init drive"
}

// --- Local Variables ---
locals {
  // Generate VM name and description dynamically
  vm_name              = "${var.template_prefix}-${var.environment}-base"
  template_description = "Ubuntu Server Base (${var.environment}) - Built by Packer on ${timestamp()}"
  // Determine if using iso_file or iso_url
  use_iso_file = var.iso_file != null && var.iso_file != ""
}

// --- Source Definition ---
source "proxmox-iso" "ubuntu-server-base" {
  // Proxmox Connection Settings (uses declared variables)
  proxmox_url              = var.proxmox_api_url
  username                 = var.proxmox_api_token_id
  token                    = var.proxmox_api_token_secret
  insecure_skip_tls_verify = true // Set to false if using valid certs

  // VM General Settings
  node                 = var.proxmox_node
  vm_id                = var.vm_id // Use the variable, allowing null
  vm_name              = local.vm_name
  template_description = local.template_description

  // ISO Configuration (Conditional logic)
  iso_file           = local.use_iso_file ? var.iso_file : null
  iso_url            = !local.use_iso_file ? var.iso_url : null
  iso_checksum       = !local.use_iso_file ? var.iso_checksum : null
  iso_storage_pool   = var.iso_storage_pool
  unmount_iso        = true

  // VM System Settings
  qemu_agent = var.qemu_agent

  // VM Hard Disk Settings
  scsi_controller = var.scsi_controller
  disks {
    type         = "virtio" // Or scsi, ide, sata
    disk_size    = var.disk_size
    storage_pool = var.storage_pool
    format       = "raw" // Or qcow2, vmdk
    # storage_pool_type = var.storage_pool_type # Often inferred, but can be set
  }

  // VM CPU/RAM
  cores  = var.cores
  memory = var.memory

  // VM Network Settings
  network_adapters {
    model    = "virtio"
    bridge   = var.network_bridge
    firewall = false // Set to true if using Proxmox firewall
  }

  // VM Cloud-Init Settings
  cloud_init              = true
  cloud_init_storage_pool = var.cloud_init_storage_pool

  // Packer Boot Commands for Ubuntu AutoInstall
  boot_command = [
    "<esc><wait>",                                                            // Wait for boot menu
    "e<wait>",                                                                // Edit GRUB options
    "<down><down><down><end>",                                                 // Go to the end of the linux line
    "<bs><bs><bs><bs><wait>",                                                  // Delete "quiet ---"
    "autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ ---<wait>", // Add autoinstall parameter
    "<f10><wait>"                                                             // Boot with modified options
  ]
  boot        = "c"   // Boot from CD-ROM first
  boot_wait   = "10s" // Wait for boot process to start

  // Packer Communication Settings
  communicator           = "ssh"
  ssh_username           = var.ssh_username
  ssh_password           = var.ssh_password
  ssh_private_key_file = var.ssh_private_key_file
  ssh_timeout            = "20m" // Increase timeout for installation and provisioning
  ssh_pty                = true  // Needed for sudo commands often

  // Packer HTTP Server for AutoInstall files
  http_directory = "http" // Relative path to user-data, meta-data
}

// --- Build Definition ---
build {
  name    = "ubuntu-base-${var.environment}" // Build name includes environment
  sources = ["source.proxmox-iso.ubuntu-server-base"]

  // Provisioning Steps (Run after OS install, before template creation)

  // Wait for cloud-init to complete
  provisioner "shell" {
    inline = [
      "echo 'Waiting for cloud-init to finish first boot setup...'",
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting...'; sleep 2; done",
      "echo 'Cloud-init finished.'"
    ]
  }

  // Install Docker
  provisioner "shell" {
    inline = [
      "echo 'Installing Docker...'",
      "sudo apt-get update",
      "sudo apt-get install -y ca-certificates curl gnupg lsb-release",
      "sudo mkdir -p /etc/apt/keyrings",
      "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg",
      "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null",
      "sudo apt-get update",
      "sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin",
      "sudo systemctl enable docker",
      "sudo systemctl start docker",
      "sudo usermod -aG docker ${var.ssh_username}",
      "sudo docker version",
      "echo 'Docker installation complete!'",
      "echo 'Installing Lazydocker...'",
      "curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash",
      "echo 'Lazydocker installation complete!'"
    ]
  }

  // Cleanup
  provisioner "shell" {
    expect_disconnect = true // Cloud-init clean might restart network or SSH
    inline = [
      "echo 'Running cleanup script.'",
      "sudo rm -f /etc/ssh/ssh_host_*",                                             // Remove host keys
      "sudo truncate -s 0 /etc/machine-id",                                         // Clear machine ID
      "sudo rm -f /var/lib/dbus/machine-id",                                        // Remove dbus machine ID if present
      "sudo ln -s /etc/machine-id /var/lib/dbus/machine-id",                        // Relink dbus machine ID
      "sudo apt-get autoremove -y --purge",                                         // Remove unused packages
      "sudo apt-get clean -y",                                                      // Clean apt cache
      "sudo apt-get autoclean -y",                                                  // Clean old packages
      "echo 'Cleaning cloud-init logs and artifacts...'",
      "sudo cloud-init clean --logs --seed",                                        // Clean cloud-init logs and seed data
      "sudo rm -f /etc/cloud/cloud.cfg.d/subiquity-disable-cloudinit-networking.cfg", // Remove Subiquity network config
      "sudo rm -f /etc/netplan/00-installer-config.yaml",                           // Remove installer Netplan config
      "echo 'Clearing bash history...'",
      "unset HISTFILE",                                                             // Disable history writing for current session
      "sudo rm -f /root/.bash_history",                                             // Clear root history
      "rm -f /home/${var.ssh_username}/.bash_history",                              // Clear user history
      "echo 'Syncing filesystem...'",
      "sudo sync",
      "echo 'Cleanup complete. VM will disconnect.'",
    ]
  }

  // Add Proxmox-specific cloud-init datasource config
  provisioner "file" {
    source      = "files/99-pve.cfg"
    destination = "/tmp/99-pve.cfg"
  }

  provisioner "shell" {
    inline = ["sudo cp /tmp/99-pve.cfg /etc/cloud/cloud.cfg.d/99-pve.cfg"]
  }
}

