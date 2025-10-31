// Development environment variables

// Environment marker
environment = "nyc"

// Environment-specific settings
proxmox_node = "proxmox"

// Common VM Settings
template_prefix      = "ubuntu-server"
vm_id                = null // Let Proxmox auto-assign
cores                = "2"
memory               = "2048"
disk_size            = "20G"
storage_pool         = "local-lvm"
storage_pool_type    = "lvm-thin"
network_bridge       = "vmbr0"
qemu_agent           = true
scsi_controller      = "virtio-scsi-pci"

// ISO Settings (Using Ubuntu 24.04 as an example)
iso_file             = "local:iso/ubuntu-24.04.3-live-server-amd64.iso" // Standard Proxmox ISO location
# iso_url              = "https://releases.ubuntu.com/24.04/ubuntu-24.04.2-live-server-amd64.iso" # Uncomment if downloading
# iso_checksum         = "sha256:d6dab0c3a657988501b4bd76f1297c053df710e06e0c3aece60dead24f270b4d" # Uncomment if downloading
iso_storage_pool     = "local" // Standard Proxmox ISO storage

// SSH Settings (Username defined here, password should be in credentials.pkrvars.hcl)
ssh_username         = "sfcal"
ssh_private_key_file = "~/.ssh/id_ed25519"

// Cloud-Init Settings
cloud_init_storage_pool = "local-lvm" // Standard Proxmox VM disk storage

/*
Note: The following variables are expected to be in credentials.pkrvars.hcl:
- proxmox_api_url
- proxmox_api_token_id
- proxmox_api_token_secret
- ssh_password
*/