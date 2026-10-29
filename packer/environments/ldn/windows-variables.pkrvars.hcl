// LDN environment variables for the Windows template

// Environment marker
environment = "ldn"

// Environment-specific settings
proxmox_node = "pve-ldn"

// VM Settings
template_prefix   = "windows"
vm_id             = null // Let Proxmox auto-assign
cores             = 4
memory            = 8192
disk_size         = "64G" // Windows 11 minimum
storage_pool      = "local-lvm"
storage_pool_type = "lvm-thin"
network_bridge    = "vmbr0"
qemu_agent        = true
scsi_controller   = "virtio-scsi-pci"

// UEFI / Q35 / TPM Settings (Windows 11 requirements)
cpu_type         = "host"
machine          = "q35"
bios             = "ovmf"
efi_storage_pool = "local-lvm"

// ISO Settings - upload both to the node's ISO storage first (local > ISO Images)
//   Windows 11: https://www.microsoft.com/software-download/windows11 (x64 ISO, English)
//   virtio-win: https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso
iso_file         = "local:iso/Windows11_Client_x64_en-us_26300_9457.iso"
virtio_iso_file  = "local:iso/virtio-win.iso"
iso_storage_pool = "local"

// Windows Settings (edition name inside the ISO; language must match the ISO)
windows_image_name = "Windows 11 Pro"
windows_language   = "en-US"
virtio_driver_os   = "w11"
# windows_product_key = "VK7JG-NPHTM-C97JM-9MPGT-3V66T" # generic Windows 11 Pro key, only if Setup asks for one

// Local administrator (password comes from credentials.pkrvars.hcl as ssh_password)
ssh_username = "sfcal"

/*
Note: The following variables are expected to be in credentials.pkrvars.hcl:
- proxmox_api_url
- proxmox_api_token_id
- proxmox_api_token_secret
- ssh_password
*/
