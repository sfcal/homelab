// Windows Base Template (UEFI / Q35 / TPM 2.0)
// Unattended Windows install for one-off VMs: build once, then clone the
// template from the Proxmox UI (or `qm clone`), boot it and RDP in.
//
// Needs two ISOs uploaded to Proxmox first (paths in the environment var file):
//   - the Windows installer ISO (Windows 11 or Windows Server; the edition is
//     picked with windows_image_name)
//   - the virtio-win ISO (disk/network drivers for Setup, QEMU guest agent, SPICE agent)
//
// Packer burns files/windows/autounattend.xml.pkrtpl (rendered) and
// files/windows/setup.ps1 onto a third, generated ISO that it uploads, attaches
// and deletes again after the build. Windows Setup picks the answer file up from
// there on its own. setup.ps1 runs at the first automatic logon, enables WinRM
// and installs the virtio-win guest tools (drivers, QEMU guest agent, SPICE
// agent); only then can Packer find the VM's IP and connect. The local
// administrator reuses ssh_username / ssh_password so the shared credentials
// file works unchanged.
//
// The SPICE agent gives the Proxmox console a clipboard once the template's
// display has clipboard=vnc. Packer cannot set that option, so set it by hand
// after a build: Hardware > Display > Edit > Advanced > Clipboard: VNC (or
// `qm set <vmid> --vga std,clipboard=vnc`). Clones inherit it.
//
// No sysprep: clones share hostname and SID, which is fine for throwaway
// instances and sidesteps the Windows 11 sysprep failures caused by Store app
// updates during the first logon.

packer {
  required_plugins {
    proxmox = {
      version = ">= 1.2.0"
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

// Environment Specific (Expected from environment var file)
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
  description = "Prefix for template names (e.g., windows)"
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
  description = "Memory in MB for the VM (Windows 11 needs at least 4096)"
}

variable "disk_size" {
  type        = string
  description = "Disk size for the primary VM disk (Windows 11 needs at least 64G)"
}

variable "storage_pool" {
  type        = string
  description = "Storage pool for the VM, EFI and TPM state disks"
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
  description = "Enable QEMU Guest Agent (required: Packer reads the VM's IP from it)"
}

variable "scsi_controller" {
  type        = string
  description = "SCSI controller type (e.g., virtio-scsi-pci)"
}

// UEFI / Q35 / TPM Configuration (Windows 11 requirements)
variable "cpu_type" {
  type        = string
  default     = "host"
  description = "CPU type"
}

variable "machine" {
  type        = string
  default     = "q35"
  description = "Machine type"
}

variable "bios" {
  type        = string
  default     = "ovmf"
  description = "BIOS type - OVMF (UEFI) required for Windows 11"
}

variable "efi_storage_pool" {
  type        = string
  description = "Storage pool for the EFI disk"
}

// ISO Configuration (Expected from environment var file; both ISOs must already be on Proxmox storage)
variable "iso_file" {
  type        = string
  description = "Windows installer ISO on Proxmox storage (e.g., local:iso/Win11_25H2_English_x64.iso)"
}

variable "virtio_iso_file" {
  type        = string
  description = "virtio-win ISO on Proxmox storage (e.g., local:iso/virtio-win.iso)"
}

variable "iso_storage_pool" {
  type        = string
  description = "Storage pool that holds the ISOs and receives the generated answer-file ISO"
}

// Windows Configuration
variable "windows_image_name" {
  type        = string
  default     = "Windows 11 Pro"
  description = "Image (edition) name inside the ISO's install.wim/install.esd, e.g. 'Windows 11 Pro', 'Windows 11 Enterprise Evaluation', 'Windows Server 2025 SERVERSTANDARD'"
}

variable "windows_product_key" {
  type        = string
  default     = ""
  description = "Optional product key for the answer file. Leave empty to install unactivated; set a generic key for the edition if Setup stops at the product key page"
}

variable "windows_language" {
  type        = string
  default     = "en-US"
  description = "UI language, locale and keyboard layout; must be a language the ISO contains (Microsoft's 'English' ISO is en-US, 'English International' is en-GB)"
}

variable "virtio_driver_os" {
  type        = string
  default     = "w11"
  description = "Driver folder on the virtio-win ISO matching the Windows version: w11, w10, 2k25, 2k22, ..."
}

// Local administrator (username from environment var file, password from credentials.pkrvars.hcl)
variable "ssh_username" {
  type        = string
  description = "Local administrator account created by the answer file; also used by Packer's WinRM communicator"
}

variable "ssh_password" {
  type        = string
  sensitive   = true
  description = "Password for the local administrator account (and WinRM)"
}

// --- Local Variables ---
locals {
  vm_name              = "${var.template_prefix}-${var.environment}-base"
  template_description = "Windows Base (${var.environment}) - ${var.windows_image_name} - Built by Packer on ${timestamp()}"

  // The answer file is XML, so the credentials are escaped before they are templated in.
  xml_username = replace(replace(replace(var.ssh_username, "&", "&amp;"), "<", "&lt;"), ">", "&gt;")
  xml_password = replace(replace(replace(var.ssh_password, "&", "&amp;"), "<", "&lt;"), ">", "&gt;")

  autounattend = templatefile("../files/windows/autounattend.xml.pkrtpl", {
    username    = local.xml_username
    password    = local.xml_password
    image_name  = var.windows_image_name
    product_key = var.windows_product_key
    language    = var.windows_language
    virtio_os   = var.virtio_driver_os
  })
}

// --- Source Definition ---
source "proxmox-iso" "windows-base" {
  // Proxmox Connection Settings
  proxmox_url              = var.proxmox_api_url
  username                 = var.proxmox_api_token_id
  token                    = var.proxmox_api_token_secret
  insecure_skip_tls_verify = true
  task_timeout             = "10m" // Windows can take a few minutes to shut down at the end of the build

  // VM General Settings
  node                 = var.proxmox_node
  vm_id                = var.vm_id
  vm_name              = local.vm_name
  template_description = local.template_description

  // Windows installer on ide2 (the firmware's CD boot entry)
  boot_iso {
    iso_file = var.iso_file
    unmount  = true
  }

  // virtio-win: Setup loads viostor/NetKVM from it (see the answer file),
  // setup.ps1 installs the guest tools bundle (drivers, QEMU and SPICE agents) from it.
  additional_iso_files {
    type     = "sata"
    index    = "0"
    iso_file = var.virtio_iso_file
    unmount  = true
  }

  // Answer file + bootstrap script, generated by Packer and deleted after the build.
  // sata (not ide1/ide3): q35 only offers ide0 and ide2.
  additional_iso_files {
    type             = "sata"
    index            = "1"
    cd_label         = "WINSETUP"
    cd_files         = ["${path.root}/../files/windows/setup.ps1"]
    cd_content       = { "autounattend.xml" = local.autounattend }
    iso_storage_pool = var.iso_storage_pool
    unmount          = true
  }

  // UEFI / Q35 / TPM 2.0 Settings
  bios     = var.bios
  machine  = var.machine
  cpu_type = var.cpu_type
  os       = "win11"

  efi_config {
    efi_storage_pool  = var.efi_storage_pool
    efi_type          = "4m"
    pre_enrolled_keys = true // Secure Boot on; the virtio-win drivers are WHQL-signed
  }

  tpm_config {
    tpm_storage_pool = var.storage_pool
    tpm_version      = "v2.0"
  }

  // VM System Settings
  qemu_agent = var.qemu_agent

  // VM Hard Disk Settings
  // virtio0 like the other templates (and the terraform VM module); Setup gets the
  // viostor driver from the virtio-win ISO.
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

  // VM Network Settings
  network_adapters {
    model    = "virtio"
    bridge   = var.network_bridge
    firewall = false
  }

  // No cloud-init drive: Windows ignores it, clones use DHCP
  cloud_init = false

  // The installer only boots while "Press any key to boot from CD or DVD" is on
  // screen (about five seconds), so hit a key a few times after the firmware starts.
  boot_command = ["<spacebar><wait><spacebar><wait><spacebar><wait><spacebar><wait><spacebar>"]
  boot         = "order=virtio0;ide2"
  boot_wait    = "3s"

  // Packer Communication Settings (WinRM over HTTP, enabled by setup.ps1)
  communicator   = "winrm"
  winrm_username = var.ssh_username
  winrm_password = var.ssh_password
  winrm_use_ssl  = false
  winrm_insecure = true
  winrm_timeout  = "1h" // unattended install + first logon before WinRM is reachable
}

// --- Build Definition ---
build {
  name    = "windows-base-${var.environment}"
  sources = ["source.proxmox-iso.windows-base"]

  // By the time Packer connects, setup.ps1 has done the real work. Confirm what
  // clones depend on and leave its log on the template for troubleshooting.
  provisioner "powershell" {
    inline = [
      "$ErrorActionPreference = 'Stop'",
      "$os = Get-CimInstance Win32_OperatingSystem",
      "Write-Host ('Installed: ' + $os.Caption + ' ' + $os.Version)",
      "Write-Host ('QEMU guest agent: ' + (Get-Service -Name QEMU-GA).Status)",
      "Write-Host ('SPICE agent: ' + (Get-Service -Name spice-agent).Status)",
      "Write-Host ('Remote Desktop enabled: ' + ((Get-ItemProperty 'HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Terminal Server').fDenyTSConnections -eq 0))",
      "Write-Host 'setup.ps1 log: C:\\Windows\\Temp\\packer-setup.log'",
    ]
  }
}
