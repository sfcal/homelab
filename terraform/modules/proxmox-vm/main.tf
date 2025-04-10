/**
 * # Proxmox VM Module
 *
 * A reusable module for creating Proxmox VMs with consistent configuration.
 */

resource "proxmox_vm_qemu" "vm" {
  # -- General settings
  name        = var.vm_name
  desc        = var.vm_description
  agent       = var.agent_enabled ? 1 : 0
  target_node = var.target_node
  vmid        = var.vmid != null ? var.vmid : null

  clone     = var.template_name
  full_clone = var.full_clone

  # -- Boot Process
  onboot          = var.onboot
  automatic_reboot = var.automatic_reboot

  # -- Hardware Settings
  qemu_os  = var.qemu_os
  bios     = var.bios
  cores    = var.cores
  sockets  = var.sockets
  cpu_type = var.cpu_type
  memory   = var.memory
  
  network {
    id     = 0
    bridge = var.network_bridge
    model  = var.network_model
  }
  
  scsihw = var.scsihw
  
  disks {
    ide {
      ide0 {
        cloudinit {
          storage = var.cloudinit_storage
        }
      }
    }
    virtio {
      virtio0 {
        disk {
          storage   = var.disk_storage
          size      = var.disk_size
          iothread  = var.disk_iothread
          replicate = var.disk_replicate
        }
      }
    }
  }

  # -- Cloud Init Settings
  os_type    = var.os_type
  ipconfig0  = var.use_dhcp ? "ip=dhcp" : "ip=${var.static_ip}/24,gw=${var.gateway}"
  nameserver = var.nameserver
  ciuser     = var.ciuser
  sshkeys    = var.ssh_public_key

  # Ensure that VM gets unique ID
  lifecycle {
    ignore_changes = [
      network,
    ]
  }

  # Only include connection if provisioning is enabled
  dynamic "connection" {
    for_each = var.enable_provisioning ? [1] : []
    content {
      type        = "ssh"
      host        = self.default_ipv4_address
      user        = var.ciuser
      private_key = file(var.ssh_private_key_path)
      timeout     = var.connection_timeout
    }
  }

  # SSH private key provisioning
  dynamic "provisioner" {
    for_each = var.enable_provisioning && var.provision_ssh_keys ? [1] : []
    content {
      when    = create
      file {
        source      = var.ssh_private_key_path
        destination = "/home/${var.ciuser}/.ssh/id_ed25519"
      }
    }
  }

  # SSH public key provisioning
  dynamic "provisioner" {
    for_each = var.enable_provisioning && var.provision_ssh_keys ? [1] : []
    content {
      when    = create
      file {
        source      = "${var.ssh_private_key_path}.pub"
        destination = "/home/${var.ciuser}/.ssh/id_ed25519.pub"
      }
    }
  }

  # Set correct permissions for SSH keys
  dynamic "provisioner" {
    for_each = var.enable_provisioning && var.provision_ssh_keys ? [1] : []
    content {
      when    = create
      remote-exec {
        inline = [
          "chmod 700 /home/${var.ciuser}/.ssh",
          "chmod 600 /home/${var.ciuser}/.ssh/id_ed25519",
          "chmod 644 /home/${var.ciuser}/.ssh/id_ed25519.pub",
          "cat /home/${var.ciuser}/.ssh/id_ed25519.pub >> /home/${var.ciuser}/.ssh/authorized_keys",
          "chmod 600 /home/${var.ciuser}/.ssh/authorized_keys"
        ]
      }
    }
  }

  # Git setup
  dynamic "provisioner" {
    for_each = var.enable_provisioning && var.provision_git ? [1] : []
    content {
      when    = create
      remote-exec {
        inline = [
          "sudo apt-get update",
          "sudo apt-get install -y git",
          "touch ~/.ssh/known_hosts",
          "ssh-keyscan github.com >> ~/.ssh/known_hosts",
          "git --version"
        ]
      }
    }
  }

  # Terraform installation
  dynamic "provisioner" {
    for_each = var.enable_provisioning && var.provision_terraform ? [1] : []
    content {
      when    = create
      remote-exec {
        inline = [
          "cd /tmp",
          "wget https://releases.hashicorp.com/terraform/${var.terraform_version}/terraform_${var.terraform_version}_linux_amd64.zip",
          "sudo apt-get install -y unzip",
          "unzip terraform_${var.terraform_version}_linux_amd64.zip",
          "sudo mv terraform /usr/local/bin/",
          "terraform version"
        ]
      }
    }
  }

  # Git repo cloning
  dynamic "provisioner" {
    for_each = var.enable_provisioning && var.provision_git_repo ? [1] : []
    content {
      when    = create
      remote-exec {
        inline = [
          "git clone ${var.git_repo_url}",
          "cd ~/${split("/", var.git_repo_url)[1]}",
          "git checkout ${var.git_branch}",
          "echo 'Repository cloned successfully!'"
        ]
      }
    }
  }
}