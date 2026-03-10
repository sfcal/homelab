# VMs to create
vms = {
  dns_server = {
    name           = "dns"
    description    = "DNS Server (BIND9)"
    proxmox_node   = "pve-lon"
    vmid           = 3000
    template_name  = "ubuntu-server-ldn-base"
    ip_address     = "10.3.0.53"
    gateway        = "10.3.0.1"
    nameserver     = "10.3.0.1"
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
    proxmox_node   = "pve-lon"
    vmid           = 3001
    template_name  = "ubuntu-server-ldn-base"
    ip_address     = "10.3.0.80"
    gateway        = "10.3.0.1"
    nameserver     = "10.3.0.53"
    cores          = 1
    memory         = 2048
    disk_size      = "50G"
    storage_pool   = "local-lvm"
    network_bridge = "vmbr0"
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
    ssh_user       = "sfcal"
  }

}
