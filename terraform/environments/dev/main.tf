# K3s Cluster
module "k3s_cluster" {
  source = "../../modules/k3s-cluster"

  cluster_name = "k3s"
  
  # Deploy one master and one worker on each Proxmox node
  proxmox_nodes = ["nyc-pve-01", "nyc-pve-02", "nyc-pve-03"]
  
  template_name = "ubuntu-server-dev-base"

  # Storage settings
  storage_pool   = "vm-disks"
  network_bridge = "vmbr0"

  # Network configuration
  use_dhcp        = false
  network_prefix  = "10.1.20"
  master_ip_start = 51
  worker_ip_start = 41
  gateway         = "10.1.20.1"
  nameserver      = "10.1.20.1"

  # Ceph network configuration
  enable_ceph_network  = true
  ceph_network_bridge  = "vmbr100"
  ceph_network_prefix  = "10.0.8"  # Will create 10.0.81.x, 10.0.82.x, 10.0.83.x
  ceph_master_ip_start = 11
  ceph_worker_ip_start = 21
  ceph_target_network  = "10.0.0.0/24"
  ceph_mtu            = 9000

  # SSH configuration
  ssh_user             = "sfcal"
  ssh_public_key       = var.ssh_public_key
  ssh_private_key_path = "~/.ssh/id_ed25519"  # Adjust if needed
}

# DNS Server
module "dns_server" {
  source = "../../modules/dns-server"

  name         = "dev-dns-01"
  proxmox_node = "nyc-pve-02"
  vmid         = 1000
  
  template_name = "ubuntu-server-dev-base"
  
  # Network
  ip_address = "10.1.20.53"
  gateway    = "10.1.20.1"
  nameserver = "1.1.1.1"  # Use Cloudflare until DNS is configured
  
  # Resources
  memory    = 2048
  cores     = 2
  disk_size = "20G"
  
  # Storage
  storage_pool = "vm-disks"
  network_bridge = "vmbr0"
  
  # SSH
  ssh_user       = "sfcal"
  ssh_public_key = var.ssh_public_key
}

# Docker VM
module "docker_vm" {
  source = "../../modules/docker-vm"

  name         = "dev-docker-01"
  proxmox_node = "nyc-pve-03"
  vmid         = 1001
  
  template_name = "ubuntu-server-dev-base"
  
  # Network
  ip_address = "10.1.20.54"
  gateway    = "10.1.20.1"
  nameserver = "10.1.20.53"  # Use our DNS server
  
  # Resources
  memory    = 8192
  cores     = 4
  disk_size = "100G"
  
  # Storage
  storage_pool = "vm-disks"
  network_bridge = "vmbr0"
  
  # SSH
  ssh_user       = "sfcal"
  ssh_public_key = var.ssh_public_key
}