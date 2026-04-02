// Ubuntu Server GPU Base Template (UEFI/Q35/SR-IOV)
// This template builds an Ubuntu 25.10 VM template with UEFI boot, Q35 machine type,
// and kernel-level prerequisites for SR-IOV GPU passthrough.

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
  description = "Prefix for template names (e.g., ubuntu-server-gpu)"
}

// VM Configuration (Expected from environment var file)
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
  description = "Disk size for the primary VM disk (e.g., 40G)"
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

// GPU/UEFI Configuration
variable "cpu_type" {
  type        = string
  default     = "host"
  description = "CPU type - must be 'host' for GPU passthrough"
}

variable "machine" {
  type        = string
  default     = "q35"
  description = "Machine type - Q35 required for PCIe passthrough"
}

variable "bios" {
  type        = string
  default     = "ovmf"
  description = "BIOS type - OVMF (UEFI) required for Q35"
}

variable "efi_storage_pool" {
  type        = string
  description = "Storage pool for the EFI disk"
}

// ISO Configuration (Expected from environment var file)
variable "iso_file" {
  type        = string
  description = "Path to the ISO file on Proxmox storage (e.g., local:iso/ubuntu.iso)"
  default     = null
}

variable "iso_url" {
  type        = string
  description = "URL to download the ISO if not present locally"
  default     = null
}

variable "iso_checksum" {
  type        = string
  description = "Checksum for the ISO file (e.g., sha256:xxxx)"
  default     = null
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
  default     = null
  description = "Path to SSH private key file for Packer connection"
}

// Cloud-Init Configuration (Expected from environment var file)
variable "cloud_init_storage_pool" {
  type        = string
  description = "Storage pool for the Cloud-Init drive"
}

// --- Local Variables ---
locals {
  vm_name              = "${var.template_prefix}-${var.environment}-base"
  template_description = "Ubuntu Server GPU/UEFI (${var.environment}) - Built by Packer on ${timestamp()}"
  use_iso_file         = var.iso_file != null && var.iso_file != ""
}

// --- Source Definition ---
source "proxmox-iso" "ubuntu-server-gpu-base" {
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

  // ISO Configuration (Conditional logic)
  iso_file         = local.use_iso_file ? var.iso_file : null
  iso_url          = !local.use_iso_file ? var.iso_url : null
  iso_checksum     = !local.use_iso_file ? var.iso_checksum : null
  iso_storage_pool = var.iso_storage_pool
  unmount_iso      = true

  // UEFI / Q35 / GPU Settings
  bios     = var.bios
  machine  = var.machine
  cpu_type = var.cpu_type

  efi_config {
    efi_storage_pool  = var.efi_storage_pool
    efi_type          = "4m"
    pre_enrolled_keys = false
  }

  // VM System Settings
  os       = "l26"
  qemu_agent = var.qemu_agent

  // VM Hard Disk Settings (scsi required -- OVMF cannot boot from virtio-blk)
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
    model    = "virtio"
    bridge   = var.network_bridge
    firewall = false
  }

  // VM Cloud-Init Settings
  cloud_init              = true
  cloud_init_storage_pool = var.cloud_init_storage_pool

  // Packer Boot Commands for Ubuntu AutoInstall (UEFI)
  boot_command = [
    "<wait>",
    "e<wait>",
    "<down><down><down><end>",
    " autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/",
    "<f10>"
  ]
  boot      = "order=scsi0;ide2"
  boot_wait = "15s"

  // Packer Communication Settings
  communicator         = "ssh"
  ssh_username         = var.ssh_username
  ssh_password         = var.ssh_password
  ssh_private_key_file = var.ssh_private_key_file
  ssh_timeout          = "20m"
  ssh_pty              = true

  // Packer HTTP Server for AutoInstall files
  http_directory = "http"
}

// --- Build Definition ---
build {
  name    = "ubuntu-gpu-${var.environment}"
  sources = ["source.proxmox-iso.ubuntu-server-gpu-base"]

  // Wait for cloud-init to complete
  provisioner "shell" {
    inline = [
      "echo 'Waiting for cloud-init to finish first boot setup...'",
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting...'; sleep 2; done",
      "echo 'Cloud-init finished.'"
    ]
  }

  // Configure IOMMU and VFIO for SR-IOV GPU passthrough
  provisioner "shell" {
    inline = [
      "echo 'Configuring IOMMU and VFIO for SR-IOV GPU passthrough...'",

      // Add IOMMU kernel parameters to GRUB (AMD)
      "sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=\"\\(.*\\)\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\\1 amd_iommu=on iommu=pt\"/' /etc/default/grub",
      "sudo update-grub",

      // Load vfio-pci modules at boot
      "echo 'vfio' | sudo tee /etc/modules-load.d/vfio.conf",
      "echo 'vfio_iommu_type1' | sudo tee -a /etc/modules-load.d/vfio.conf",
      "echo 'vfio_pci' | sudo tee -a /etc/modules-load.d/vfio.conf",

      // Configure vfio-pci options
      "echo 'options vfio_iommu_type1 allow_unsafe_interrupts=1' | sudo tee /etc/modprobe.d/vfio.conf",

      // Update initramfs to include vfio modules
      "sudo update-initramfs -u -k all",

      "echo 'IOMMU and VFIO configuration complete.'"
    ]
  }

  // Install GPU/SR-IOV driver prerequisites
  provisioner "shell" {
    inline = [
      "echo 'Installing GPU and SR-IOV driver prerequisites...'",
      "sudo apt-get update",
      "sudo apt-get install -y dkms build-essential linux-headers-$(uname -r) pciutils sysfsutils intel-media-va-driver-non-free libva2 vainfo",

      // Add user to render and video groups for GPU access
      "sudo usermod -aG render,video ${var.ssh_username}",

      // Blacklist nouveau driver (conflicts with NVIDIA vGPU/SR-IOV)
      "echo 'blacklist nouveau' | sudo tee /etc/modprobe.d/blacklist-nouveau.conf",
      "echo 'options nouveau modeset=0' | sudo tee -a /etc/modprobe.d/blacklist-nouveau.conf",
      "sudo update-initramfs -u -k all",

      "echo 'GPU prerequisites installation complete.'"
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

  // Install Node Exporter
  provisioner "shell" {
    inline = [
      "echo 'Installing Node Exporter...'",
      "NODE_EXPORTER_VERSION='1.9.1'",
      "wget -q https://github.com/prometheus/node_exporter/releases/download/v$${NODE_EXPORTER_VERSION}/node_exporter-$${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz -O /tmp/node_exporter.tar.gz",
      "sudo tar xzf /tmp/node_exporter.tar.gz -C /usr/local/bin --strip-components=1 --wildcards '*/node_exporter'",
      "rm -f /tmp/node_exporter.tar.gz",
      "sudo useradd --no-create-home --shell /usr/sbin/nologin node_exporter || true",
      "cat <<'EOF' | sudo tee /etc/systemd/system/node-exporter.service",
      "[Unit]",
      "Description=Prometheus Node Exporter",
      "After=network.target",
      "",
      "[Service]",
      "User=node_exporter",
      "ExecStart=/usr/local/bin/node_exporter",
      "Restart=on-failure",
      "RestartSec=5",
      "",
      "[Install]",
      "WantedBy=multi-user.target",
      "EOF",
      "sudo systemctl daemon-reload",
      "sudo systemctl enable node-exporter",
      "echo 'Node Exporter installation complete!'"
    ]
  }

  // Cleanup
  provisioner "shell" {
    expect_disconnect = true
    inline = [
      "echo 'Running cleanup script.'",
      "sudo rm -f /etc/ssh/ssh_host_*",
      "sudo truncate -s 0 /etc/machine-id",
      "sudo rm -f /var/lib/dbus/machine-id",
      "sudo ln -s /etc/machine-id /var/lib/dbus/machine-id",
      "sudo apt-get autoremove -y --purge",
      "sudo apt-get clean -y",
      "sudo apt-get autoclean -y",
      "echo 'Cleaning cloud-init logs and artifacts...'",
      "sudo cloud-init clean --logs --seed",
      "sudo rm -f /etc/cloud/cloud.cfg.d/subiquity-disable-cloudinit-networking.cfg",
      "sudo rm -f /etc/netplan/00-installer-config.yaml",
      "echo 'Clearing bash history...'",
      "unset HISTFILE",
      "sudo rm -f /root/.bash_history",
      "rm -f /home/${var.ssh_username}/.bash_history",
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
