# Configure Ceph network routes after VM creation
resource "null_resource" "master_ceph_routes" {
  for_each = var.enable_ceph_network ? local.node_pairs : {}
  
  depends_on = [proxmox_vm_qemu.master_nodes]
  
  connection {
    type     = "ssh"
    user     = var.ssh_user
    host     = local.node_pairs[each.key].master.ip
    private_key = file("~/.ssh/id_ed25519")  # Adjust path as needed
  }
  
  provisioner "remote-exec" {
    inline = [
      # Wait for cloud-init to complete
      "cloud-init status --wait || true",
      
      # Create netplan configuration for Ceph network
      "sudo tee /etc/netplan/60-ceph-network.yaml > /dev/null <<'EOF'",
      "network:",
      "  version: 2",
      "  ethernets:",
      "    eth1:",
      "      dhcp4: false",
      "      addresses:",
      "        - ${local.node_pairs[each.key].master.ceph_ip}/24",
      "      mtu: ${var.ceph_mtu}",
      "      routes:",
      "        - to: ${var.ceph_target_network}",
      "          via: ${local.node_pairs[each.key].master.ceph_gateway}",
      "EOF",
      
      # Apply netplan configuration
      "sudo netplan apply",
      
      # Verify the route was added
      "ip route show | grep ${var.ceph_target_network} || echo 'Route configuration pending'"
    ]
  }
}

resource "null_resource" "worker_ceph_routes" {
  for_each = var.enable_ceph_network ? local.node_pairs : {}
  
  depends_on = [proxmox_vm_qemu.worker_nodes]
  
  connection {
    type     = "ssh"
    user     = var.ssh_user
    host     = local.node_pairs[each.key].worker.ip
    private_key = file("~/.ssh/id_ed25519")  # Adjust path as needed
  }
  
  provisioner "remote-exec" {
    inline = [
      # Wait for cloud-init to complete
      "cloud-init status --wait || true",
      
      # Create netplan configuration for Ceph network
      "sudo tee /etc/netplan/60-ceph-network.yaml > /dev/null <<'EOF'",
      "network:",
      "  version: 2",
      "  ethernets:",
      "    eth1:",
      "      dhcp4: false",
      "      addresses:",
      "        - ${local.node_pairs[each.key].worker.ceph_ip}/24",
      "      mtu: ${var.ceph_mtu}",
      "      routes:",
      "        - to: ${var.ceph_target_network}",
      "          via: ${local.node_pairs[each.key].worker.ceph_gateway}",
      "EOF",
      
      # Apply netplan configuration
      "sudo netplan apply",
      
      # Verify the route was added
      "ip route show | grep ${var.ceph_target_network} || echo 'Route configuration pending'"
    ]
  }
}