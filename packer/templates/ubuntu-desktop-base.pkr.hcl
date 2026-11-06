// Ubuntu Desktop Base Template
// Built like ubuntu-server-base: the Ubuntu Server ISO is installed unattended
// (autoinstall from http/user-data), then the desktop is installed on top
// instead of Docker and Node Exporter. Still a cloud-init template, so the
// terraform VM module clones it like the server one.
//
// Clones start a GNOME desktop at boot and serve it through KasmVNC on https
// port 8444 (ssh_username / kasmvnc_password), to be reached through Kasm and
// SSO, so GNOME's lock screen is off. The NAS share is mounted at /mnt/data.
// The Proxmox console still has the GNOME login screen (ssh_username /
// ssh_password).

packer {
  required_plugins {
    proxmox = {
      version = ">= 1.2.0"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

// --- Variable Declarations ---

// Proxmox Connection (Expected from credentials.pkrvars.hcl)
variable "proxmox_api_url" {
  type        = string
  description = "The Proxmox API URL (e.g., https://pve.example.com:8006/api2/json)"
}

variable "proxmox_api_token_id" {
  type        = string
  description = "Proxmox API token ID (e.g., user@realm!tokenid)"
}

variable "proxmox_api_token_secret" {
  type        = string
  sensitive   = true
  description = "Proxmox API token secret"
}

// Environment Specific (Expected from environment var file)
variable "proxmox_node" {
  type        = string
  description = "Proxmox node to build on"
}

variable "environment" {
  type        = string
  description = "Environment identifier (e.g., ldn, wil)"
}

variable "template_prefix" {
  type        = string
  description = "Prefix for template names (e.g., ubuntu-desktop)"
}

// VM Configuration (Expected from environment var file)
variable "vm_id" {
  type        = number
  default     = null
  description = "Optional: Specific VM ID for the build VM (null for auto)"
}

variable "cores" {
  type        = number
  description = "Number of CPU cores for the VM"
}

variable "memory" {
  type        = number
  description = "Memory in MB for the VM (Ubuntu Desktop wants at least 4096)"
}

variable "disk_size" {
  type        = string
  description = "Disk size for the primary VM disk (Ubuntu Desktop wants at least 25G)"
}

variable "storage_pool" {
  type        = string
  description = "Storage pool for the VM disk"
}

variable "network_bridge" {
  type        = string
  description = "Network bridge for the VM (e.g., vmbr0)"
}

variable "qemu_agent" {
  type        = bool
  description = "Enable QEMU Guest Agent (required: Packer reads the VM's IP from it)"
}

variable "scsi_controller" {
  type        = string
  description = "SCSI controller type (e.g., virtio-scsi-pci)"
}

// ISO Configuration (Expected from environment var file)
variable "iso_file" {
  type        = string
  description = "Ubuntu Server ISO on Proxmox storage (e.g., local:iso/ubuntu-24.04.3-live-server-amd64.iso)"
}

// SSH Configuration (username from environment var file, password from credentials.pkrvars.hcl)
variable "ssh_username" {
  type        = string
  description = "User created by the autoinstall (http/user-data); Packer connects as it and it is the desktop login"
}

variable "ssh_password" {
  type        = string
  sensitive   = true
  description = "Password of that user"
}

// Cloud-Init Configuration (Expected from environment var file)
variable "cloud_init_storage_pool" {
  type        = string
  description = "Storage pool for the Cloud-Init drive"
}

// KasmVNC login (password from credentials.pkrvars.hcl)
variable "kasmvnc_password" {
  type        = string
  sensitive   = true
  description = "Password for ssh_username on KasmVNC's port 8444 (6 to 128 characters). Not ssh_password: that port is open to the whole network"
}

// NAS share (Expected from environment var file)
variable "nfs_share" {
  type        = string
  description = "NFS export mounted at /mnt/data on every clone (e.g., 10.2.10.100:/mnt/NAS-WIL/Media)"
}

// --- Local Variables ---
locals {
  kasmvnc_version      = "1.4.0"
  vm_name              = "${var.template_prefix}-${var.environment}-base"
  template_description = "Ubuntu Desktop Base (${var.environment}) - Built by Packer on ${timestamp()}"
}

// --- Source Definition ---
source "proxmox-iso" "ubuntu-desktop-base" {
  // Proxmox Connection Settings
  proxmox_url              = var.proxmox_api_url
  username                 = var.proxmox_api_token_id
  token                    = var.proxmox_api_token_secret
  insecure_skip_tls_verify = true

  // VM General Settings
  node                 = var.proxmox_node
  vm_id                = var.vm_id
  vm_name              = local.vm_name
  template_description = local.template_description

  // Ubuntu Server installer, already on Proxmox storage (ide2)
  boot_iso {
    iso_file = var.iso_file
    unmount  = true
  }

  // VM System Settings
  os         = "l26"
  cpu_type   = "host" // what the terraform VM module gives clones; GNOME renders in software and is slow on the default kvm64
  qemu_agent = var.qemu_agent

  // VM Hard Disk Settings (virtio0, the slot the terraform VM module declares)
  scsi_controller = var.scsi_controller
  disks {
    type         = "virtio"
    disk_size    = var.disk_size
    storage_pool = var.storage_pool
    format       = "raw"
  }

  // VM CPU/RAM
  cores  = var.cores
  memory = var.memory

  // VM Network Settings
  network_adapters {
    model    = "virtio"
    bridge   = var.network_bridge
    firewall = false
  }

  // VM Cloud-Init Settings
  cloud_init              = true
  cloud_init_storage_pool = var.cloud_init_storage_pool

  // Packer Boot Commands for Ubuntu AutoInstall (same as ubuntu-server-base)
  boot_command = [
    "<esc><wait>",                                                                    // Wait for boot menu
    "e<wait>",                                                                        // Edit GRUB options
    "<down><down><down><end>",                                                        // Go to the end of the linux line
    "<bs><bs><bs><bs><wait>",                                                         // Delete " ---"
    "autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ ---<wait>", // Add autoinstall parameter
    "<f10><wait>"                                                                     // Boot with modified options
  ]
  boot      = "order=virtio0;ide2" // The empty disk falls through to the ISO; after the install the disk boots
  boot_wait = "10s"

  // Packer Communication Settings
  communicator = "ssh"
  ssh_username = var.ssh_username
  ssh_password = var.ssh_password
  ssh_timeout  = "20m"
  ssh_pty      = true

  // Packer HTTP Server for AutoInstall files (shared with the server templates)
  http_directory = "http"
}

// --- Build Definition ---
build {
  name    = "ubuntu-desktop-${var.environment}"
  sources = ["source.proxmox-iso.ubuntu-desktop-base"]

  // Wait for cloud-init to complete (it upgrades all packages on the first boot)
  provisioner "shell" {
    inline = [
      "echo 'Waiting for cloud-init to finish first boot setup...'",
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting...'; sleep 2; done",
      "echo 'Cloud-init finished.'"
    ]
  }

  // Configure mDNS so every clone answers to <hostname>.local, IPv4 only
  // (same as the server templates, see ubuntu-server-base for the reason).
  provisioner "shell" {
    inline = [
      "echo 'Configuring mDNS...'",
      "sudo sed -i 's/^use-ipv6=yes/use-ipv6=no/' /etc/avahi/avahi-daemon.conf",
      "grep -q '^use-ipv6=no' /etc/avahi/avahi-daemon.conf",
      "echo 'mDNS configuration complete!'"
    ]
  }

  // Install KasmVNC. Above the desktop install because it downloads (see the DNS
  // note there).
  provisioner "shell" {
    inline = [
      "echo 'Installing KasmVNC...'",
      "sudo apt-get update",
      "curl -fsSL -o /tmp/kasmvnc.deb https://github.com/kasmtech/KasmVNC/releases/download/v${local.kasmvnc_version}/kasmvncserver_noble_${local.kasmvnc_version}_amd64.deb",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y /tmp/kasmvnc.deb",
      "rm /tmp/kasmvnc.deb",
      "echo 'KasmVNC installation complete!'"
    ]
  }

  // Install the desktop. ubuntu-desktop-minimal is the default selection of the
  // Ubuntu Desktop installer: GNOME and the basic utilities. The trailing "-"
  // skips two of its recommends: Firefox, a deb that only downloads the snap and
  // its GNOME runtime (well over an hour of the build), and the welcome wizard
  // that would otherwise open on the first login of every clone.
  // Prompt=never stops the popup offering an upgrade to the next Ubuntu release.
  // The package also makes NetworkManager the netplan renderer (ubuntu-settings), so
  // clones come up under NetworkManager like a stock desktop. The server
  // install's systemd-networkd-wait-online is disabled to match: with no
  // interface left for networkd it would hold every clone boot for 2 minutes.
  // Keep steps that need the network above this one: on 24.04 the renderer
  // change can leave the running system without DNS until the next boot
  // (LP: #2097769).
  // MUTTER_DEBUG_KMS_THREAD_TYPE=user: on the Proxmox std VGA, GNOME Shell is
  // killed two seconds after it starts whenever its display (KMS) thread runs
  // realtime, so the login screen restarted six times on every boot of a clone.
  provisioner "shell" {
    inline = [
      "echo 'Installing Ubuntu Desktop...'",
      "sudo apt-get update",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ubuntu-desktop-minimal firefox- gnome-initial-setup-",
      "sudo sed -i 's/^Prompt=.*/Prompt=never/' /etc/update-manager/release-upgrades",
      "sudo systemctl disable systemd-networkd-wait-online.service",
      "echo 'MUTTER_DEBUG_KMS_THREAD_TYPE=user' | sudo tee -a /etc/environment",
      "echo 'Ubuntu Desktop installation complete!'"
    ]
  }

  // Set up the KasmVNC desktop: it starts at boot as ssh_username, who needs group
  // ssl-cert to read the self-signed certificate. .de-was-selected skips
  // vncserver's desktop chooser, xstartup already picks GNOME.
  provisioner "file" {
    source      = "files/kasmvnc"
    destination = "/tmp"
  }

  provisioner "shell" {
    environment_vars = ["KASMVNC_PASSWORD=${var.kasmvnc_password}"]
    inline = [
      "echo 'Configuring KasmVNC...'",
      "sudo cp '/tmp/kasmvnc/kasmvnc@.service' /etc/systemd/system/",
      "sudo systemctl enable kasmvnc@${var.ssh_username}.service",
      "sudo usermod -aG ssl-cert ${var.ssh_username}",
      "mkdir -m 700 /home/${var.ssh_username}/.vnc",
      "cp /tmp/kasmvnc/kasmvnc.yaml /tmp/kasmvnc/xstartup /home/${var.ssh_username}/.vnc/",
      "chmod 755 /home/${var.ssh_username}/.vnc/xstartup",
      "touch /home/${var.ssh_username}/.vnc/.de-was-selected",
      "printf '%s\\n%s\\n' \"$KASMVNC_PASSWORD\" \"$KASMVNC_PASSWORD\" | kasmvncpasswd -u ${var.ssh_username} -wo",
      "echo 'Turning off the GNOME lock screen...'", // as the default for every user
      "sudo cp /tmp/kasmvnc/90-no-lock-screen.gschema.override /usr/share/glib-2.0/schemas/",
      "sudo glib-compile-schemas /usr/share/glib-2.0/schemas/",
      "echo 'KasmVNC configuration complete!'"
    ]
  }

  // Mount the NAS share at /mnt/data, the export and path the nfs_mount role gives
  // wil's media VM (nfs-common comes with the autoinstall). nofail and automount:
  // it mounts on first use, so a clone that cannot reach the NAS still boots.
  // x-gvfs-show puts it in the Files sidebar.
  provisioner "shell" {
    inline = [
      "sudo mkdir -p /mnt/data",
      "echo '${var.nfs_share} /mnt/data nfs defaults,nofail,x-systemd.automount,x-gvfs-show 0 0' | sudo tee -a /etc/fstab"
    ]
  }

  // Cleanup
  provisioner "shell" {
    expect_disconnect = true // Cloud-init clean might restart network or SSH
    inline = [
      "echo 'Running cleanup script.'",
      "sudo rm -f /etc/ssh/ssh_host_*",                      // Remove host keys
      "sudo truncate -s 0 /etc/machine-id",                  // Clear machine ID
      "sudo rm -f /var/lib/dbus/machine-id",                 // Remove dbus machine ID if present
      "sudo ln -s /etc/machine-id /var/lib/dbus/machine-id", // Relink dbus machine ID
      "sudo apt-get autoremove -y --purge",                  // Remove unused packages
      "sudo apt-get clean -y",                               // Clean apt cache
      "sudo apt-get autoclean -y",                           // Clean old packages
      "echo 'Cleaning cloud-init logs and artifacts...'",
      "sudo cloud-init clean --logs --seed",                                          // Clean cloud-init logs and seed data
      "sudo rm -f /etc/cloud/cloud.cfg.d/subiquity-disable-cloudinit-networking.cfg", // Remove Subiquity network config
      "sudo rm -f /etc/netplan/00-installer-config.yaml",                             // Remove installer Netplan config
      "echo 'Clearing bash history...'",
      "unset HISTFILE",                                // Disable history writing for current session
      "sudo rm -f /root/.bash_history",                // Clear root history
      "rm -f /home/${var.ssh_username}/.bash_history", // Clear user history
      "echo 'Syncing filesystem...'",
      "sudo sync",
      "echo 'Cleanup complete. VM will disconnect.'",
    ]
  }

  // Add Proxmox-specific cloud-init datasource config
  provisioner "file" {
    source      = "files/99-pve.cfg"
    destination = "/tmp/99-pve.cfg"
  }

  // ...and keep the desktop login working on clones. cloud-init locks its
  // default user's password on a clone's first boot (lock_passwd defaults to
  // true), which a server never notices but leaves GDM with no way in. Making
  // ssh_username that default user also stops by-hand clones (no cloud-init
  // user set) from growing a second, unusable "ubuntu" account.
  // That password must not work over SSH, though: the autoinstall leaves sshd
  // password logins on, and on server clones only the lock stops them. So
  // ssh_pwauth turns them off: password at the console, key over SSH.
  provisioner "shell" {
    inline = [
      "sudo cp /tmp/99-pve.cfg /etc/cloud/cloud.cfg.d/99-pve.cfg",
      "echo 'system_info: {default_user: {name: ${var.ssh_username}, lock_passwd: false}}' | sudo tee /etc/cloud/cloud.cfg.d/99-default-user.cfg",
      "echo 'ssh_pwauth: false' | sudo tee -a /etc/cloud/cloud.cfg.d/99-default-user.cfg"
    ]
  }
}
