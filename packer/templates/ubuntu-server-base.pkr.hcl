// Ubuntu Server Base Template

packer {
  required_plugins {
    proxmox = {
      version = ">= 1.1.2"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

// Variable declarations
variable "proxmox_api_url" {
  type = string
  default = "https://10.2.20.11:8006/api2/json"
}

variable "proxmox_api_token_id" {
  type = string
  default = "root@pam!packer"
}

variable "proxmox_api_token_secret" {
  type = string
  sensitive = true
}

variable "proxmox_node" {
  type = string
  default = "wil-pve-01"
}

variable "environment" {
  type = string
  default = "dev"
  description = "Environment (dev or prod)"
}

variable "template_prefix" {
  type = string
  default = "ubuntu-server"
  description = "Prefix for template names"
}

variable "ssh_username" {
  type = string
  default = "sfcal"
  description = "SSH username"
}

variable "ssh_password" {
  type = string
  sensitive = true
  description = "SSH password"
}

// Local variables
locals {
  vm_name = "${var.template_prefix}-${var.environment}-base"
  template_description = "Ubuntu Server Base - Built for ${var.environment}"
}

source "proxmox-iso" "ubuntu-server-base" {
  // Proxmox connection settings
  proxmox_url = var.proxmox_api_url
  username = var.proxmox_api_token_id
  token = var.proxmox_api_token_secret
  insecure_skip_tls_verify = true

  // VM General Settings
  node = var.proxmox_node
  vm_name = local.vm_name
  template_description = local.template_description

  // ISO file settings - using direct parameters
  //iso_url = "https://releases.ubuntu.com/24.04/ubuntu-24.04.2-live-server-amd64.iso"
  iso_file = "local:iso/ubuntu-22.04.3-live-server-amd64.iso"
  //iso_checksum = "sha256:d6dab0c3a657988501b4bd76f1297c053df710e06e0c3aece60dead24f270b4d"
  iso_storage_pool = "local"
  unmount_iso = true

  // VM System Settings
  qemu_agent = true

  // VM Hard Disk Settings
  scsi_controller = "virtio-scsi-pci"

  disks {
    disk_size = "20G"
    format = "raw"
    storage_pool = "local-lvm"
    type = "virtio"
  }

  // VM CPU/RAM
  cores = "2"
  memory = "2048"

  // VM Network Settings
  network_adapters {
    model = "virtio"
    bridge = "vmbr0"
    firewall = "false"
  }

  // VM Cloud-Init Settings
  cloud_init = true
  cloud_init_storage_pool = "local-lvm"

  // PACKER Boot Commands
  boot_command = [
    "<esc><wait>",
    "e<wait>",
    "<down><down><down><end>",
    "<bs><bs><bs><bs><wait>",
    "autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ ---<wait>", // Note the escaped semicolon
    "<f10><wait>"
  ]
  //boot_command = [ "c<wait>linux /casper/vmlinuz --- autoinstall ds=nocloud<enter><wait>initrd /casper/initrd<enter><wait>boot<enter>" ]

  boot = "c"
  boot_wait = "10s"
  communicator = "ssh"

  // PACKER Autoinstall Settings
  http_directory = "http"

  ssh_username = var.ssh_username
  ssh_password = var.ssh_password
  ssh_timeout = "10m"
  ssh_pty = true
}

// Build Definition to create the VM Template
build {
  name = "ubuntu-base"
  sources = ["source.proxmox-iso.ubuntu-server-base"]

  // Provisioning the VM Template for Cloud-Init Integration in Proxmox #1
provisioner "shell" {
  inline = [
    "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 1; done", // Loop
    "echo 'Cloud-init finished. Starting cleanup...' ", // Add this for visibility
    "sudo rm /etc/ssh/ssh_host_*",
    "sudo truncate -s 0 /etc/machine-id",
    "sudo apt -y autoremove --purge", // << Potential for hanging
    "sudo apt -y clean",
    "sudo apt -y autoclean",
    "sudo cloud-init clean", // This will remove /var/lib/cloud/instance and boot-finished
    "sudo rm -f /etc/cloud/cloud.cfg.d/subiquity-disable-cloudinit-networking.cfg",
    "sudo rm -f /etc/netplan/00-installer-config.yaml",
    "sudo sync"
  ]
}

  // Provisioning the VM Template for Cloud-Init Integration in Proxmox #2
  provisioner "file" {
    source = "files/99-pve.cfg"
    destination = "/tmp/99-pve.cfg"
  }

  // Provisioning the VM Template for Cloud-Init Integration in Proxmox #3
  provisioner "shell" {
    inline = [ "sudo cp /tmp/99-pve.cfg /etc/cloud/cloud.cfg.d/99-pve.cfg" ]
  }
}