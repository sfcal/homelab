// Ubuntu Server for Kubernetes Template

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
  vm_name = "${var.template_prefix}-${var.environment}-k8s"
  template_description = "Ubuntu Server for Kubernetes - Built for ${var.environment}"
}

source "proxmox-iso" "ubuntu-server-k8s" {
  // Proxmox connection settings
  proxmox_url = var.proxmox_api_url
  username = var.proxmox_api_token_id
  token = var.proxmox_api_token_secret
  insecure_skip_tls_verify = true

  // VM General Settings
  node = var.proxmox_node
  vm_id = "9002"
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
    disk_size = "40G"  // Larger disk for Kubernetes
    format = "raw"
    storage_pool = "local-lvm"
    storage_pool_type = "lvm"
    type = "virtio"
  }

  // VM CPU/RAM
  cores = "2"
  memory = "4096"  // More memory for Kubernetes

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
  name = "ubuntu-${var.environment}-k8s"
  sources = ["source.proxmox-iso.ubuntu-server-k8s"]

  // Provisioning the VM Template for Cloud-Init Integration in Proxmox
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

  provisioner "file" {
    source = "files/99-pve.cfg"
    destination = "/tmp/99-pve.cfg"
  }

  provisioner "shell" {
    inline = [ "sudo cp /tmp/99-pve.cfg /etc/cloud/cloud.cfg.d/99-pve.cfg" ]
  }

  // Kubernetes prerequisites
  provisioner "shell" {
    inline = [
      "echo 'Installing Kubernetes prerequisites'",
      "sudo apt-get update",
      "sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release",
      
      "# Disable swap",
      "sudo swapoff -a",
      "sudo sed -i '/ swap / s/^\\(.*\\)$/#\\1/g' /etc/fstab",
      
      "# Load required modules",
      "sudo tee /etc/modules-load.d/containerd.conf << EOF",
      "overlay",
      "br_netfilter",
      "EOF",
      
      "sudo modprobe overlay",
      "sudo modprobe br_netfilter",
      
      "# Setup networking requirements",
      "sudo tee /etc/sysctl.d/kubernetes.conf << EOF",
      "net.bridge.bridge-nf-call-ip6tables = 1",
      "net.bridge.bridge-nf-call-iptables = 1",
      "net.ipv4.ip_forward = 1",
      "EOF",
      
      "sudo sysctl --system",
      
      "# Install containerd",
      "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg",
      "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null",
      "sudo apt-get update",
      "sudo apt-get install -y containerd.io",
      
      "# Configure containerd",
      "sudo mkdir -p /etc/containerd",
      "containerd config default | sudo tee /etc/containerd/config.toml > /dev/null",
      "sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml",
      "sudo systemctl restart containerd",
      "sudo systemctl enable containerd",
      
      "# Install additional tools",
      "sudo apt-get install -y nfs-common open-iscsi",
      "sudo systemctl enable iscsid",
      "sudo systemctl start iscsid"
    ]
  }
}