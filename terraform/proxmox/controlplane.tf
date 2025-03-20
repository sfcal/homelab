resource "proxmox_vm_qemu" "controlplane" {
  
  # -- General settings

  name = "controlplane"
  desc = "description"
  agent = 1
  target_node = "pve-dev01"
  vmid = "401"

  clone = "ubuntu-server-noble"
  full_clone = true

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
  #ipconfig0 = "ip=10.1.10.40/24,gw=10.1.10.1"
  ipconfig0 = "ip=dhcp"
  nameserver = "8.8.8.8"  # <-- Change to your desired DNS server
  ciuser = "sfcal"
  sshkeys = var.ssh_public_key  # <-- (Optional) Change to your public SSH key


 # Ensure that VM gets unique ID
  lifecycle {
    ignore_changes = [
      network,
    ]
  }

  # SSH connection for provisioning
  connection {
    type        = "ssh"
    host        = self.default_ipv4_address
    user        = "sfcal"
    password    = "Proxmox4me!"
    private_key = file("~/.ssh/id_ed25519")
    timeout     = "2m"
  }

  provisioner "file" {
    source      = "~/.ssh/id_ed25519"
    destination = "/home/sfcal/.ssh/id_ed25519"
  }

  provisioner "file" {
    source      = "~/.ssh/id_ed25519.pub"
    destination = "/home/sfcal/.ssh/id_ed25519.pub"
  }

  # Set correct permissions for SSH keys
  provisioner "remote-exec" {
    inline = [
      "chmod 700 /home/sfcal/.ssh",
      "chmod 600 /home/sfcal/.ssh/id_ed25519",
      "chmod 644 /home/sfcal/.ssh/id_ed25519.pub",
      
      # Add public key to authorized_keys
      "cat /home/sfcal/.ssh/id_ed25519.pub >> /home/sfcal/.ssh/authorized_keys",
      "chmod 600 /home/sfcal/.ssh/authorized_keys"
    ]
  }

  # Install git and setup SSH for GitHub
  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y git",
      "touch ~/.ssh/known_hosts",
      "ssh-keyscan github.com >> ~/.ssh/known_hosts",
      "git --version"
    ]
  }
  # Install Terraform
  provisioner "remote-exec" {
    inline = [
      "cd /tmp",
      "wget https://releases.hashicorp.com/terraform/1.7.5/terraform_1.7.5_linux_amd64.zip",
      "sudo apt-get install -y unzip",
      "unzip terraform_1.7.5_linux_amd64.zip",
      "sudo mv terraform /usr/local/bin/",
      "terraform version"
    ]
  }
  # Clone the repository
  provisioner "remote-exec" {
    inline = [
      "git clone ${var.git_repo_url}",
      "cd ~/homelab",
      "git checkout ${var.git_branch}",
      "echo 'Repository cloned successfully!'"
    ]
  }

  # Start Docker containers from the repository
/*   provisioner "remote-exec" {
    inline = [
      "cd ~/docker-app",
      # Create .env file if needed
      "if [ -f .env.example ]; then cp .env.example .env; fi",
      # Run any setup scripts if they exist
      "if [ -f setup.sh ]; then chmod +x setup.sh && ./setup.sh; fi",
      # Start Docker Compose
      "docker-compose up -d",
      "docker ps",
      "echo 'Docker containers are now running!'"
    ]
  }
} */
}

output "vm_ip" {
  value = proxmox_vm_qemu.controlplane.default_ipv4_address
}
