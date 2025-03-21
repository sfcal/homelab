resource "proxmox_vm_qemu" "k3s-master" {
  
  # -- General settings

  name = "k3s-master-0${count.index + 1}"
  desc = "description"
  count = 3
  agent = 1
  target_node = "pve-dev01"
  #vmid = "401"

  clone = "ubuntu-server-noble"
  #full_clone = true

  # -- Boot Process

  onboot = true 
  automatic_reboot = true

  # -- Hardware Settings

  qemu_os = "other"
  bios = "seabios"
  cores = 2
  sockets = 1
  cpu_type = "host"
  memory = 4096
  

  network {
    id     = 0  # <-- ! required since 3.x.x
    bridge = "vmbr0"
    model  = "virtio"
  }

  
  scsihw = "virtio-scsi-single"  # <-- (Optional) Change the SCSI controller type, since Proxmox 7.3, virtio-scsi-single is the default one         
  
  disks {  # <-- ! changed in 3.x.x
    ide {
      ide0 {
        cloudinit {
          storage = "local-lvm"
        }
      }
    }
    virtio {
      virtio0 {
        disk {
          storage = "local-lvm"
          size = "20G"  # <-- Change the desired disk size, ! since 3.x.x size change will trigger a disk resize
          iothread = true  # <-- (Optional) Enable IOThread for better disk performance in virtio-scsi-single
          replicate = false  # <-- (Optional) Enable for disk replication
        }
      }
    }
  }

  # -- Cloud Init Settings
  os_type = "cloud-init"
  ipconfig0 = "ip=10.1.10.${count.index + 51}/24,gw=10.1.10.1"
  nameserver = "8.8.8.8"  # <-- Change to your desired DNS server
  ciuser = "sfcal"
  sshkeys = var.ssh_public_key  # <-- (Optional) Change to your public SSH key


 # Ensure that VM gets unique ID
  lifecycle {
    ignore_changes = [
      network,
    ]
  }

#   # SSH connection for provisioning
#   connection {
#     type        = "ssh"
#     host        = self.default_ipv4_address
#     user        = "sfcal"
#     password    = "Proxmox4me!"
#     private_key = file("~/.ssh/id_ed25519")
#     timeout     = "2m"
#   }
}

resource "proxmox_vm_qemu" "k3s-worker" {
  
  # -- General settings

  name = "k3s-worker-0${count.index + 1}"
  desc = "description"
  count = 2
  agent = 1
  target_node = "pve-dev01"
  #vmid = "401"

  clone = "ubuntu-server-noble"
  #full_clone = true

  # -- Boot Process

  onboot = true 
  automatic_reboot = true

  # -- Hardware Settings

  qemu_os = "other"
  bios = "seabios"
  cores = 2
  sockets = 1
  cpu_type = "host"
  memory = 4096
  

  network {
    id     = 0  # <-- ! required since 3.x.x
    bridge = "vmbr0"
    model  = "virtio"
  }

  
  scsihw = "virtio-scsi-single"  # <-- (Optional) Change the SCSI controller type, since Proxmox 7.3, virtio-scsi-single is the default one         
  
  disks {  # <-- ! changed in 3.x.x
    ide {
      ide0 {
        cloudinit {
          storage = "local-lvm"
        }
      }
    }
    virtio {
      virtio0 {
        disk {
          storage = "local-lvm"
          size = "20G"  # <-- Change the desired disk size, ! since 3.x.x size change will trigger a disk resize
          iothread = true  # <-- (Optional) Enable IOThread for better disk performance in virtio-scsi-single
          replicate = false  # <-- (Optional) Enable for disk replication
        }
      }
    }
  }

  # -- Cloud Init Settings
  os_type = "cloud-init"
  ipconfig0 = "ip=10.1.10.${count.index + 41}/24,gw=10.1.10.1"
  nameserver = "8.8.8.8"  # <-- Change to your desired DNS server
  ciuser = "sfcal"
  sshkeys = var.ssh_public_key  # <-- (Optional) Change to your public SSH key


 # Ensure that VM gets unique ID
  lifecycle {
    ignore_changes = [
      network,
    ]
  }
}

# Outputs - Fixed to handle multiple nodes
output "k3s_master_ips" {
  value = proxmox_vm_qemu.k3s-master[*].default_ipv4_address
  description = "IP addresses of the K3s master nodes"
}

output "k3s_worker_ips" {
  value = proxmox_vm_qemu.k3s-worker[*].default_ipv4_address
  description = "IP addresses of the K3s worker nodes"
}