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
  description = "Proxmox API URL"
}

variable "proxmox_api_token_id" {
  type = string
  description = "Proxmox API token ID"
}

variable "proxmox_api_token_secret" {
  type = string
  sensitive = true
  description = "Proxmox API token secret"
}

variable "proxmox_node" {
  type = string
  description = "Proxmox node to build on"
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

//variable "ssh_private_key_file" {
//  type = string
//  default = "~/.ssh/id_ed25519"
//  description = "SSH private key file"
//}

variable "iso_url" {
  type = string
  default = "https://releases.ubuntu.com/24.04/ubuntu-24.04.2-live-server-amd64.iso"
}

variable "iso_checksum" {
  type = string
  default = "sha256:d6dab0c3a657988501b4bd76f1297c053df710e06e0c3aece60dead24f270b4d"
}

variable "iso_storage_pool" {
  type = string
  default = "local"
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
  vm_id = "9000"
  vm_name = local.vm_name
  template_description = local.template_description

// ISO file settings
  boot_iso {
    iso_url = var.iso_url
    iso_checksum = var.iso_checksum
    iso_storage_pool = var.iso_storage_pool  // Correct parameter name
    unmount = true
  }

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
    "autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ ---<wait>",
    "<f10><wait>"
  ]

  boot = "c"
  boot_wait = "10s"
  communicator = "ssh"

  // PACKER Autoinstall Settings
  http_directory = "http"

  ssh_username = var.ssh_username
  ssh_password = var.ssh_password
  //ssh_private_key_file = var.ssh_private_key_file

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
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 1; done",
      "sudo rm /etc/ssh/ssh_host_*",
      "sudo truncate -s 0 /etc/machine-id",
      "sudo apt -y autoremove --purge",
      "sudo apt -y clean",
      "sudo apt -y autoclean",
      "sudo cloud-init clean",
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