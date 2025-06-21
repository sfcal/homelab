// Production environment variables for Debian

// Environment marker
environment = "prod"

// Environment-specific settings
proxmox_node = "wil-pve-01"

// Common VM Settings
template_prefix      = "debian-bookworm"
vm_id                = null // Let Proxmox auto-assign
cores                = "4"
memory               = "8192"
disk_size            = "20G"
storage_pool         = "vm-disks"
storage_pool_type    = "rbd"
network_bridge       = "vmbr0"
qemu_agent           = true
scsi_controller      = "virtio-scsi-pci"

// ISO Settings for Debian 12 (Bookworm)
iso_file             = "ISOs-Templates:iso/debian-12.8.0-amd64-netinst.iso" // Update with your actual Debian ISO
# iso_url              = "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-12.8.0-amd64-netinst.iso" # Uncomment if downloading
# iso_checksum         = "sha256:1ce6dcf23166eebfadb7b5f84de38fb2b0feda8e7767d72e7e899e0e7c915196" # Uncomment if downloading
iso_storage_pool     = "ISOs-Templates" 

// SSH Settings (Username defined here, password should be in credentials.pkrvars.hcl)
ssh_username         = "sfcal"
ssh_private_key_file = "~/.ssh/id_ed25519"

// Cloud-Init Settings
cloud_init_storage_pool = "vm-disks"

/*
Note: The following variables are expected to be in credentials.pkrvars.hcl:
- proxmox_api_url
- proxmox_api_token_id
- proxmox_api_token_secret
- ssh_password
*/