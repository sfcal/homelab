// Haivision VF Kicker environment variables for ldn

// Environment marker
environment = "ldn"

// Environment-specific settings
proxmox_node = "pve-ldn"

// VM Settings
template_prefix   = "haivision-vfkicker"
vm_id             = null // Let Proxmox auto-assign
cores             = 2
memory            = 4096
disk_size         = "50G"
storage_pool      = "local-lvm"
storage_pool_type = "lvm-thin"
network_bridge    = "vmbr0"
qemu_agent        = false // No guest agent during iPXE boot
scsi_controller   = "virtio-scsi-pci"
cpu_type          = "host"       // Required for AVX instruction passthrough
network_model     = "e1000"      // VF Kicker kernel lacks virtio-net drivers

// ISO Settings - standard iPXE ISO (downloaded automatically by Packer)
iso_url          = "https://boot.ipxe.org/ipxe.iso"
iso_checksum     = "none"
iso_storage_pool = "local"
