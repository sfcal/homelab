# DNS Server
module "dns_server" {
  source = "../../modules/dns-server"

  name         = "dev-dns-01"
  proxmox_node = "proxmox"
  vmid         = 1000
  
  template_name = "ubuntu-server-nyc-base"
  
  # Network
  ip_address = "10.1.30.53"
  gateway    = "10.1.30.1"
  nameserver = "1.1.1.1"  # Use Cloudflare until DNS is configured
  
  # Resources
  memory    = 2048
  cores     = 2
  disk_size = "20G"
  
  # Storage
  storage_pool = "local-lvm"
  network_bridge = "vmbr0"
  
  # SSH
  ssh_user       = "sfcal"
  ssh_public_key = var.ssh_public_key
}

# Docker VM
module "docker_vm" {
  source = "../../modules/docker-vm"

  name         = "nyc-docker-01"
  proxmox_node = "proxmox"
  vmid         = 1001
  
  template_name = "ubuntu-server-nyc-base"
  
  # Network
  ip_address = "10.1.30.54"
  gateway    = "10.1.30.1"
  nameserver = "1.1.1.1"
  
  # Resources
  memory    = 8192
  cores     = 4
  disk_size = "100G"
  
  # Storage
  storage_pool = "local-lvm"
  network_bridge = "vmbr0"
  
  # SSH
  ssh_user       = "sfcal"
  ssh_public_key = var.ssh_public_key
}