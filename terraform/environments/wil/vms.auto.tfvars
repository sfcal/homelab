vms = {
  networking = {
    name           = "networking"
    description    = "Networking (DNS, Reverse Proxy, Tailscale)"
    proxmox_node   = "proxmox"
    vmid           = 1000
    template_name  = "ubuntu-server-wil-base"
    ip_address     = "10.2.20.53"
    gateway        = "10.2.20.1"
    nameserver     = "10.2.20.1"
    cores          = 2
    memory         = 6144
    disk_size      = "50G"
    storage_pool   = "local-lvm"
    network_bridge = "vmbr0"
    tags           = "infrastructure"
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
    tags           = "infrastructure"
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
    tags           = "application"
    ssh_user       = "sfcal"
  }

  ca_server = {
    name           = "ca"
    description    = "Certificate Authority (Step-CA)"
    proxmox_node   = "proxmox"
    vmid           = 1003
    template_name  = "ubuntu-server-wil-base"
    ip_address     = "10.2.20.9"
    gateway        = "10.2.20.1"
    nameserver     = "10.2.20.53"
    cores          = 1
    memory         = 4096
    disk_size      = "20G"
    storage_pool   = "local-lvm"
    network_bridge = "vmbr0"
    tags           = "infrastructure"
    ssh_user       = "sfcal"
  }

  web_server = {
    name           = "web"
    description    = "personal site"
    proxmox_node   = "proxmox"
    vmid           = 1109
    template_name  = "ubuntu-server-wil-base"
    ip_address     = "10.2.20.45"
    gateway        = "10.2.20.1"
    nameserver     = "10.2.20.53"
    cores          = 2
    memory         = 4096
    disk_size      = "20G"
    storage_pool   = "local-lvm"
    network_bridge = "vmbr0"
    tags           = "application"
    ssh_user       = "sfcal"
  }

  work_server = {
    name           = "work"
    description    = "Work Apps (IT-Tools, CyberChef, Stirling-PDF, BookStack, Kasm)"
    proxmox_node   = "proxmox"
    vmid           = 1112
    template_name  = "ubuntu-server-wil-base"
    ip_address     = "10.2.20.60"
    gateway        = "10.2.20.1"
    nameserver     = "10.2.20.53"
    cores          = 4
    memory         = 8192
    disk_size      = "256G"
    storage_pool   = "local-lvm"
    network_bridge = "vmbr0"
    tags           = "application"
    ssh_user       = "sfcal"
  }

  seafile_server = {
    name           = "seafile"
    description    = "Seafile File Sync & Share"
    proxmox_node   = "proxmox"
    vmid           = 1113
    template_name  = "ubuntu-server-wil-base"
    ip_address     = "10.2.20.70"
    gateway        = "10.2.20.1"
    nameserver     = "10.2.20.53"
    cores          = 2
    memory         = 8192
    disk_size      = "50G"
    storage_pool   = "local-lvm"
    network_bridge = "vmbr0"
    tags           = "application"
    ssh_user       = "sfcal"
  }

  ntp_server = {
    name           = "ntp"
    description    = "NTP Time Server (Chrony)"
    proxmox_node   = "proxmox"
    vmid           = 1002
    template_name  = "ubuntu-server-wil-base"
    ip_address     = "10.2.20.123"
    gateway        = "10.2.20.1"
    nameserver     = "10.2.20.53"
    cores          = 1
    memory         = 1024
    disk_size      = "20G"
    storage_pool   = "local-lvm"
    network_bridge = "vmbr0"
    tags           = "infrastructure"
    ssh_user       = "sfcal"
  }

}
