# VMs to create
vms = {
  dns_server = {
    name          = "prod-dns-01"
    description   = "DNS Server (BIND9)"
    proxmox_node  = "wil-pve-02"
    vmid          = 2000
    template_name = "ubuntu-server-prod-base"
    ip_address    = "10.2.20.53"
    gateway       = "10.2.20.1"
    nameserver    = "1.1.1.1"
    cores         = 2
    memory        = 2048
    disk_size     = "20G"
    storage_pool  = "vm-disks"
    ssh_user      = "sfcal"
  }
}
