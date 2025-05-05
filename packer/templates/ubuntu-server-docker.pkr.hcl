// Ubuntu Server with Docker Template

packer {
  required_plugins {
    proxmox = {
      version = ">= 1.1.2"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

// Include common variables
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

variable "ssh_password" {
  type = string
  sensitive = true
}

variable "environment" {
  type = string
}

variable "template_prefix" {
  type = string
}

// Local variables
locals {
  vm_name = "${var.template_prefix}-${var.environment}-docker"
  template_description = "Ubuntu Server with Docker - Built for ${var.environment}"
}

source "proxmox-iso" "ubuntu-server-docker" {
  // Proxmox connection settings
  proxmox_url = var.proxmox_api_url
  username = var.proxmox_api_token_id
  token = var.proxmox_api_token_secret
  insecure_skip_tls_verify = true

  // VM General Settings
  node = var.proxmox_node
  vm_id = "9001"
  vm_name = local.vm_name
  template_description = local.template_description

  // ISO file settings
  iso_url = var.iso_url
  iso_checksum = var.iso_checksum
  iso_storage_pool = var.iso_storage_pool
  unmount_iso = true

  // VM System Settings
  qemu_agent = true

  // VM Hard Disk Settings
  scsi_controller = "virtio-scsi-pci"

  disks {
    disk_size = "20G"
    format = "raw"
    storage_pool = "local-lvm"
    storage_pool_type = "lvm"
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

  ssh_username = "sfcal"
  ssh_password = var.ssh_password
  ssh_private_key_file = "~/.ssh/id_ed25519"

  ssh_timeout = "10m"
  ssh_pty = true
}

// Build Definition to create the VM Template
build {
  name = "ubuntu-${var.environment}-docker"
  sources = ["source.proxmox-iso.ubuntu-server-docker"]

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

  // Installing Docker
  provisioner "shell" {
    inline = [
      "sudo apt-get install -y ca-certificates curl gnupg lsb-release",
      "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg",
      "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null",
      "sudo apt-get -y update",
      "sudo apt-get install -y docker-ce docker-ce-cli containerd.io"
    ]
  }

  // Docker without sudo
  provisioner "shell" {
    inline = [ 
      "sudo usermod -aG docker sfcal"
    ]
  }
}