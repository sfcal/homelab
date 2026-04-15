// LDN environment EFI template variables
// (UEFI/Q35 Ubuntu template; also carries GPU-passthrough prereqs)

// Environment marker
environment = "ldn"

// Environment-specific settings
proxmox_node = "pve-ldn"

// VM Settings
template_prefix      = "ubuntu-server"
vm_id                = null
cores                = 4
memory               = 8192
disk_size            = "40G"
storage_pool         = "local-lvm"
storage_pool_type    = "lvm-thin"
network_bridge       = "vmbr0"
qemu_agent           = true
scsi_controller      = "virtio-scsi-pci"

// UEFI / Q35 Settings
cpu_type             = "host"
machine              = "q35"
bios                 = "ovmf"

// ISO Settings
iso_file             = "local:iso/ubuntu-25.10-live-server-amd64.iso"
iso_storage_pool     = "local"

// SSH Settings
ssh_username         = "sfcal"
ssh_private_key_file = "~/.ssh/id_ed25519"

// Cloud-Init and EFI Settings
cloud_init_storage_pool = "local-lvm"
efi_storage_pool        = "local-lvm"

/*
Note: The following variables are expected to be in credentials.pkrvars.hcl:
- proxmox_api_url
- proxmox_api_token_id
- proxmox_api_token_secret
- ssh_password
*/
