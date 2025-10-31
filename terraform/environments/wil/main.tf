# DNS Server
module "dns_server" {
  source = "../../modules/dns-server"

  name         = "prod-dns-01"
  proxmox_node = "wil-pve-02"
  vmid         = 2000
  
  template_name = "ubuntu-server-prod-base"
  
  # Network
  ip_address = "10.2.20.53"
  gateway    = "10.2.20.1"
  nameserver = "1.1.1.1"  # Use Cloudflare until DNS is configured
  
  # Resources
  memory    = 2048
  cores     = 2
  disk_size = "20G"
  
  # Storage
  storage_pool = "vm-disks"
  
  # SSH
  ssh_user       = "sfcal"
  ssh_public_key = var.ssh_public_key
}