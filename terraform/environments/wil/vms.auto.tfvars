# VMs to create
vms = {
  dns_server = {
    name           = "dns"
    description    = "DNS Server (BIND9)"
    proxmox_node   = "proxmox"
    vmid           = 1000
    template_name  = "ubuntu-server-wil-base"
    ip_address     = "10.2.20.53"
    gateway        = "10.2.20.1"
    nameserver     = "10.2.20.1"
    cores          = 2
    memory         = 4096
    disk_size      = "20G"
    storage_pool   = "local-lvm"
    network_bridge = "vmbr0"
    ssh_user       = "sfcal"
  }

  reverse_proxy = {
    name           = "caddy"
    description    = "Reverse Proxy"
    proxmox_node   = "proxmox"
    vmid           = 1104
    template_name  = "ubuntu-server-wil-base"
    ip_address     = "10.2.20.80"
    gateway        = "10.2.20.1"
    nameserver     = "10.2.20.53"
    cores          = 1
    memory         = 1024
    disk_size      = "50G"
    storage_pool   = "local-lvm"
    network_bridge = "vmbr0"
    ssh_user       = "sfcal"
  }

  monitoring_server = {
    name           = "monitoring"
    description    = "Monitoring Server"
    proxmox_node   = "proxmox"
    vmid           = 1107
    template_name  = "ubuntu-server-wil-base"
    ip_address     = "10.2.20.30"
    gateway        = "10.2.20.1"
    nameserver     = "10.2.20.53"
    cores          = 1
    memory         = 8192
    disk_size      = "50G"
    storage_pool   = "local-lvm"
    network_bridge = "vmbr0"
    ssh_user       = "sfcal"
  }

  games_server = {
    name           = "games"
    description    = "game Server"
    proxmox_node   = "proxmox"
    vmid           = 1111
    template_name  = "ubuntu-server-wil-base"
    ip_address     = "10.2.20.50"
    gateway        = "10.2.20.1"
    nameserver     = "10.2.20.53"
    cores          = 1
    memory         = 8192
    disk_size      = "50G"
    storage_pool   = "local-lvm"
    network_bridge = "vmbr0"
    ssh_user       = "sfcal"
  }

  web_server = {
    name           = "web"
    description    = "personal sight"
    proxmox_node   = "proxmox"
    vmid           = 1109
    template_name  = "ubuntu-server-wil-base"
    ip_address     = "10.2.20.45"
    gateway        = "10.2.20.1"
    nameserver     = "10.2.20.53"
    cores          = 2
    memory         = 2048
    disk_size      = "20G"
    storage_pool   = "local-lvm"
    network_bridge = "vmbr0"
    ssh_user       = "sfcal"
  }

}
