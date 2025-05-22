// Production environment variables

// Environment marker (used for naming, etc.)
environment = "prod"

// Environment-specific settings
proxmox_node = "wil-pve-01" // Example Prod Node IP/Hostname

// Common VM Settings (adjust defaults per environment if needed)
template_prefix      = "ubuntu-server"
vm_id                = null // Let Proxmox auto-assign
cores                = "2"
memory               = "2048" // 2GB RAM
disk_size            = "20G"  // Default disk size for base template
storage_pool         = "vm-disks" // Or maybe a different pool for prod, e.g., "ceph-ssd"
storage_pool_type    = "rbd"       // Or "rbd" if using Ceph
network_bridge       = "vmbr0"
qemu_agent           = true
scsi_controller      = "virtio-scsi-pci"

// ISO Settings (Using Ubuntu 24.04 as an example)
iso_file             = "ISOs-Templates:iso/ubuntu-24.04.2-live-server-amd64.iso" // Preferred: Use local ISO if available
# iso_url              = "https://releases.ubuntu.com/24.04/ubuntu-24.04.2-live-server-amd64.iso" # Uncomment if downloading
# iso_checksum         = "sha256:d6dab0c3a657988501b4bd76f1297c053df710e06e0c3aece60dead24f270b4d" # Uncomment if downloading
iso_storage_pool     = "ISOs-Templates" // Storage pool where ISO resides or will be downloaded to

// SSH Settings (Username defined here, password should be in credentials.pkrvars.hcl)
ssh_username         = "sfcal"
ssh_private_key_file = "~/.ssh/id_ed25519" // Optional: Path to your private key if using key-based auth

// Cloud-Init Settings
cloud_init_storage_pool = "vm-disks" // Or maybe a different pool for prod

/*
Note: The following variables are expected to be in credentials.pkrvars.hcl:
- proxmox_api_url
- proxmox_api_token_id
- proxmox_api_token_secret
- ssh_password
*/
