# VMs to create
vms = {
  networking = {
    name           = "networking"
    description    = "Networking (DNS, Reverse Proxy, Tailscale)"
    proxmox_node   = "pve-lon"
    vmid           = 3000
    template_name  = "ubuntu-server-ldn-base"
    ip_address     = "10.3.0.53"
    gateway        = "10.3.0.1"
    nameserver     = "10.3.0.1"
    cores          = 2
    memory         = 4096
    disk_size      = "50G"
    storage_pool   = "local-lvm"
    network_bridge = "vmbr0"
    tags           = "infrastructure"
    ssh_user       = "sfcal"
  }

  ca_server = {
    name           = "ca"
    description    = "Certificate Authority (Step-CA)"
    proxmox_node   = "pve-lon"
    vmid           = 3003
    template_name  = "ubuntu-server-ldn-base"
    ip_address     = "10.3.0.9"
    gateway        = "10.3.0.1"
    nameserver     = "10.3.0.53"
    cores          = 1
    memory         = 2048
    disk_size      = "20G"
    storage_pool   = "local-lvm"
    network_bridge = "vmbr0"
    tags           = "infrastructure"
    ssh_user       = "sfcal"
  }

  monitoring_server = {
    name           = "monitoring"
    description    = "Monitoring Server"
    proxmox_node   = "pve-lon"
    vmid           = 3002
    template_name  = "ubuntu-server-ldn-base"
    ip_address     = "10.3.0.30"
    gateway        = "10.3.0.1"
    nameserver     = "10.3.0.53"
    cores          = 1
    memory         = 8192
    disk_size      = "50G"
    storage_pool   = "local-lvm"
    network_bridge = "vmbr0"
    tags           = "infrastructure"
    ssh_user       = "sfcal"
  }

  homeassistant = {
    name           = "homeassistant"
    description    = "Home Assistant"
    proxmox_node   = "pve-lon"
    vmid           = 3004
    template_name  = "ubuntu-server-ldn-base"
    ip_address     = "10.3.0.50"
    gateway        = "10.3.0.1"
    nameserver     = "10.3.0.53"
    cores          = 2
    memory         = 4096
    disk_size      = "50G"
    storage_pool   = "local-lvm"
    network_bridge = "vmbr0"
    tags           = "application"
    ssh_user       = "sfcal"
  }

}
