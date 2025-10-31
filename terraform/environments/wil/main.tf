# K3s Cluster
module "k3s_cluster" {
  source = "../../modules/k3s-cluster"

  cluster_name = "k3s"
  
  # Deploy one master and one worker on each Proxmox node
  proxmox_nodes = ["wil-pve-01", "wil-pve-02", "wil-pve-03"]
  
  template_name = "ubuntu-server-prod-base"

  # Storage settings
  storage_pool   = "vm-disks"
  network_bridge = "vmbr0"

  # Network configuration
  use_dhcp        = false
  network_prefix  = "10.2.20"
  master_ip_start = 51
  worker_ip_start = 41
  gateway         = "10.2.20.1"
  nameserver      = "10.2.20.1"

  # Ceph network configuration
  enable_ceph_network  = true
  ceph_network_bridge  = "vmbr100"
  ceph_network_prefix  = "10.0.8"  # Will create 10.0.81.x, 10.0.82.x, 10.0.83.x
  ceph_master_ip_start = 11
  ceph_worker_ip_start = 21
  ceph_target_network  = "10.0.0.0/24"
  ceph_mtu            = 65520

  # SSH configuration
  ssh_user             = "sfcal"
  ssh_public_key       = var.ssh_public_key
  ssh_private_key_path = "~/.ssh/id_ed25519"  # Adjust if needed
}

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