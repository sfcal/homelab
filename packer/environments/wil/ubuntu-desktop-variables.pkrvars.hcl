// WIL environment variables for the Ubuntu Desktop template

// Environment marker
environment = "wil"

// Environment-specific settings
proxmox_node = "proxmox"

// VM Settings (Ubuntu Desktop wants at least 4 GB RAM and 25 GB disk)
template_prefix = "ubuntu-desktop"
vm_id           = null // Let Proxmox auto-assign
cores           = 2
memory          = 4096
disk_size       = "32G"
storage_pool    = "local-lvm"
network_bridge  = "vmbr0"
qemu_agent      = true
scsi_controller = "virtio-scsi-pci"

// ISO Settings - the Ubuntu Server ISO, same as ubuntu-variables.pkrvars.hcl
// (the desktop is installed on top of it during the build)
iso_file = "local:iso/ubuntu-24.04.3-live-server-amd64.iso"

// SSH Settings (password comes from credentials.pkrvars.hcl as ssh_password)
ssh_username = "sfcal"

// Cloud-Init Settings
cloud_init_storage_pool = "local-lvm"

/*
Note: The following variables are expected to be in credentials.pkrvars.hcl:
- proxmox_api_url
- proxmox_api_token_id
- proxmox_api_token_secret
- ssh_password
*/
