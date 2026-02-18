// WIL environment variables for Netboot VM

// Environment marker
environment = "wil"

// Environment-specific settings
proxmox_node = "proxmox"

// Common VM Settings
template_prefix      = "netboot-vm"
vm_id                = null // Let Proxmox auto-assign
cores                = 2
memory               = 2048
disk_size            = "32G"
storage_pool         = "local-lvm"
storage_pool_type    = "lvm-thin"
network_bridge       = "vmbr0"
scsi_controller      = "virtio-scsi-pci"

// ISO Settings
iso_file             = "local:iso/alpine-virt-3.19.0-x86_64.iso" // Standard Proxmox ISO location
# iso_url              = "https://releases.ubuntu.com/24.04/ubuntu-24.04.2-live-server-amd64.iso" # Uncomment if downloading
# iso_checksum         = "sha256:d6dab0c3a657988501b4bd76f1297c053df710e06e0c3aece60dead24f270b4d" # Uncomment if downloading
iso_storage_pool     = "local" // Standard Proxmox ISO storage

// BIOS Settings
bios_type            = "seabios"  // UEFI wasn't working. Gone back to legacy
efi_storage_pool     = "local-lvm"  // Only needed if using UEFI
machine_type         = "pc"   // "pc" or "q35"

/*
Note: The following variables are expected to be in credentials.pkrvars.hcl:
- proxmox_api_url
- proxmox_api_token_id
- proxmox_api_token_secret
*/
