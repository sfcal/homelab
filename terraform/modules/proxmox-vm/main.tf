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
  
  # Main disk (using standard format for Telmate provider)
  disk {
    storage = var.disk_storage
    size    = var.disk_size
    type    = "disk"
    slot    = "scsi0"
  }

  # Cloud-init settings
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
}

# SSH Keys provisioning
resource "null_resource" "ssh_keys_provisioning" {
  count = var.enable_provisioning && var.provision_ssh_keys ? 1 : 0

  triggers = {
    vm_id = proxmox_vm_qemu.vm.id
  }

  connection {
    type        = "ssh"
    host        = proxmox_vm_qemu.vm.default_ipv4_address
    user        = var.ciuser
    private_key = file(var.ssh_private_key_path)
    timeout     = var.connection_timeout
  }

  # SSH private key
  provisioner "file" {
    source      = var.ssh_private_key_path
    destination = "/home/${var.ciuser}/.ssh/id_ed25519"
  }

  # SSH public key
  provisioner "file" {
    source      = "${var.ssh_private_key_path}.pub"
    destination = "/home/${var.ciuser}/.ssh/id_ed25519.pub"
  }

  # Set permissions
  provisioner "remote-exec" {
    inline = [
      "chmod 700 /home/${var.ciuser}/.ssh",
      "chmod 600 /home/${var.ciuser}/.ssh/id_ed25519",
      "chmod 644 /home/${var.ciuser}/.ssh/id_ed25519.pub",
      "cat /home/${var.ciuser}/.ssh/id_ed25519.pub >> /home/${var.ciuser}/.ssh/authorized_keys",
      "chmod 600 /home/${var.ciuser}/.ssh/authorized_keys"
    ]
  }
}

# Git setup
resource "null_resource" "git_provisioning" {
  count = var.enable_provisioning && var.provision_git ? 1 : 0

  depends_on = [null_resource.ssh_keys_provisioning]

  triggers = {
    vm_id = proxmox_vm_qemu.vm.id
  }

  connection {
    type        = "ssh"
    host        = proxmox_vm_qemu.vm.default_ipv4_address
    user        = var.ciuser
    private_key = file(var.ssh_private_key_path)
    timeout     = var.connection_timeout
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y git",
      "touch ~/.ssh/known_hosts",
      "ssh-keyscan github.com >> ~/.ssh/known_hosts",
      "git --version"
    ]
  }
}

# Terraform installation
resource "null_resource" "terraform_provisioning" {
  count = var.enable_provisioning && var.provision_terraform ? 1 : 0

  depends_on = [null_resource.ssh_keys_provisioning]

  triggers = {
    vm_id = proxmox_vm_qemu.vm.id
  }

  connection {
    type        = "ssh"
    host        = proxmox_vm_qemu.vm.default_ipv4_address
    user        = var.ciuser
    private_key = file(var.ssh_private_key_path)
    timeout     = var.connection_timeout
  }

  provisioner "remote-exec" {
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

# Git repo cloning
resource "null_resource" "git_repo_provisioning" {
  count = var.enable_provisioning && var.provision_git_repo ? 1 : 0

  depends_on = [null_resource.git_provisioning]

  triggers = {
    vm_id = proxmox_vm_qemu.vm.id
  }

  connection {
    type        = "ssh"
    host        = proxmox_vm_qemu.vm.default_ipv4_address
    user        = var.ciuser
    private_key = file(var.ssh_private_key_path)
    timeout     = var.connection_timeout
  }

  provisioner "remote-exec" {
    inline = [
      "git clone ${var.git_repo_url}",
      "cd ~/${split("/", var.git_repo_url)[1]}",
      "git checkout ${var.git_branch}",
      "echo 'Repository cloned successfully!'"
    ]
  }
}