# VMs to create
vms = {
  dns_server = {
    name           = "dev-dns-01"
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

  docker_vm = {
    name           = "nyc-docker-01"
    description    = "Docker Host"
    proxmox_node   = "proxmox"
    vmid           = 1001
    template_name  = "ubuntu-server-nyc-base"
    ip_address     = "10.1.30.54"
    gateway        = "10.1.30.1"
    nameserver     = "10.1.30.1"
    cores          = 4
    memory         = 8192
    disk_size      = "100G"
    storage_pool   = "local-lvm"
    network_bridge = "vmbr0"
    ssh_user       = "sfcal"
  }

  ntp_server = {
    name           = "ntp-01"
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

  test_server = {
    name           = "test-01"
    description    = "NTP Server"
    proxmox_node   = "proxmox"
    vmid           = 1101
    template_name  = "ubuntu-server-nyc-base"
    ip_address     = "10.1.30.124"
    gateway        = "10.1.30.1"
    nameserver     = "10.1.30.1"
    cores          = 1
    memory         = 1024
    disk_size      = "50G"
    storage_pool   = "local-lvm"
    network_bridge = "vmbr0"
    ssh_user       = "sfcal"
  }
}
