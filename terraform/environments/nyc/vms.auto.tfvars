# VMs to create
vms = {
  dns_server = {
    name           = "dns"
    description    = "DNS Server (BIND9)"
    proxmox_node   = "proxmox"
    vmid           = 1000
    template_name  = "ubuntu-server-nyc-base"
    ip_address     = "10.1.30.53"
    gateway        = "10.1.30.1"
    nameserver     = "10.1.30.1"
    cores          = 2
    memory         = 2048
    disk_size      = "20G"
    storage_pool   = "local-lvm"
    network_bridge = "vmbr0"
    ssh_user       = "sfcal"
  }

  ntp_server = {
    name           = "ntp-ptp"
    description    = "NTP Server"
    proxmox_node   = "proxmox"
    vmid           = 1100
    template_name  = "ubuntu-server-nyc-base"
    ip_address     = "10.1.30.123"
    gateway        = "10.1.30.1"
    nameserver     = "10.1.30.1"
    cores          = 1
    memory         = 1024
    disk_size      = "50G"
    storage_pool   = "local-lvm"
    network_bridge = "vmbr0"
    ssh_user       = "sfcal"
  }

  netboot_server = {
    name           = "netbootxyz"
    description    = "Netboot Server"
    proxmox_node   = "proxmox"
    vmid           = 1101
    template_name  = "ubuntu-server-nyc-base"
    ip_address     = "10.1.30.69"
    gateway        = "10.1.30.1"
    nameserver     = "10.1.30.1"
    cores          = 1
    memory         = 1024
    disk_size      = "50G"
    storage_pool   = "local-lvm"
    network_bridge = "vmbr0"
    ssh_user       = "sfcal"
  }

  reverse_proxy = {
    name           = "nginx"
    description    = "Reverse Proxy"
    proxmox_node   = "proxmox"
    vmid           = 1104
    template_name  = "ubuntu-server-nyc-base"
    ip_address     = "10.1.30.80"
    gateway        = "10.1.30.1"
    nameserver     = "10.1.30.1"
    cores          = 1
    memory         = 1024
    disk_size      = "50G"
    storage_pool   = "local-lvm"
    network_bridge = "vmbr0"
    ssh_user       = "sfcal"
  }

  certificate_authority = {
    name           = "step-ca"
    description    = "Certificate Authority"
    proxmox_node   = "proxmox"
    vmid           = 1103
    template_name  = "ubuntu-server-nyc-base"
    ip_address     = "10.1.30.3"
    gateway        = "10.1.30.1"
    nameserver     = "10.1.30.1"
    cores          = 1
    memory         = 2048
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
    template_name  = "ubuntu-server-nyc-base"
    ip_address     = "10.1.30.30"
    gateway        = "10.1.30.1"
    nameserver     = "10.1.30.1"
    cores          = 1
    memory         = 2048
    disk_size      = "50G"
    storage_pool   = "local-lvm"
    network_bridge = "vmbr0"
    ssh_user       = "sfcal"
  }

  media_server = {
    name           = "media-stack"
    description    = "Media Server"
    proxmox_node   = "proxmox"
    vmid           = 1102
    template_name  = "ubuntu-server-nyc-base"
    ip_address     = "10.1.30.100"
    gateway        = "10.1.30.1"
    nameserver     = "10.1.30.53"
    cores          = 2
    memory         = 8192
    disk_size      = "50G"
    storage_pool   = "local-lvm"
    network_bridge = "vmbr0"
    ssh_user       = "sfcal"
  }
}
