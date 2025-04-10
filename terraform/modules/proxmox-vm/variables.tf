/**
 * # Proxmox VM Module Variables
 *
 * All variables for the Proxmox VM module
 */

# -- General VM Settings
variable "vm_name" {
  description = "Name of the VM"
  type        = string
}

variable "vm_description" {
  description = "Description of the VM"
  type        = string
  default     = "Managed by Terraform"
}

variable "agent_enabled" {
  description = "Enable QEMU Guest Agent"
  type        = bool
  default     = true
}

variable "target_node" {
  description = "Target Proxmox node"
  type        = string
}

variable "vmid" {
  description = "VM ID (optional, Proxmox will assign if not specified)"
  type        = number
  default     = null
}

variable "template_name" {
  description = "Name of the template/clone source"
  type        = string
}

variable "full_clone" {
  description = "Create a full clone (true) or linked clone (false)"
  type        = bool
  default     = true
}

# -- Boot Settings
variable "onboot" {
  description = "Start VM on boot"
  type        = bool
  default     = true
}

variable "automatic_reboot" {
  description = "Automatically reboot VM on Proxmox reboot"
  type        = bool
  default     = true
}

# -- Hardware Settings
variable "qemu_os" {
  description = "QEMU OS type"
  type        = string
  default     = "other"
}

variable "bios" {
  description = "BIOS type (seabios or ovmf)"
  type        = string
  default     = "seabios"
}

variable "cores" {
  description = "Number of CPU cores"
  type        = number
  default     = 2
}

variable "sockets" {
  description = "Number of CPU sockets"
  type        = number
  default     = 1
}

variable "cpu_type" {
  description = "CPU type"
  type        = string
  default     = "host"
}

variable "memory" {
  description = "Memory in MB"
  type        = number
  default     = 4096
}

# -- Network Settings
variable "network_bridge" {
  description = "Network bridge"
  type        = string
  default     = "vmbr0"
}

variable "network_model" {
  description = "Network model"
  type        = string
  default     = "virtio"
}

# -- Storage Settings
variable "scsihw" {
  description = "SCSI controller model"
  type        = string
  default     = "virtio-scsi-single"
}

variable "cloudinit_storage" {
  description = "Storage for cloud-init drive"
  type        = string
  default     = "local-lvm"
}

variable "disk_storage" {
  description = "Storage for main disk"
  type        = string
  default     = "local-lvm"
}

variable "disk_size" {
  description = "Size of the main disk"
  type        = string
  default     = "20G"
}

variable "disk_iothread" {
  description = "Enable IO thread for disk"
  type        = bool
  default     = true
}

variable "disk_replicate" {
  description = "Enable disk replication"
  type        = bool
  default     = false
}

# -- Cloud-Init Settings
variable "os_type" {
  description = "OS type"
  type        = string
  default     = "cloud-init"
}

variable "use_dhcp" {
  description = "Use DHCP instead of static IP"
  type        = bool
  default     = true
}

variable "static_ip" {
  description = "Static IP address"
  type        = string
  default     = ""
}

variable "gateway" {
  description = "Network gateway"
  type        = string
  default     = ""
}

variable "nameserver" {
  description = "DNS nameserver"
  type        = string
  default     = "8.8.8.8"
}

variable "ciuser" {
  description = "Cloud-init username"
  type        = string
  default     = "ubuntu"
}

variable "ssh_public_key" {
  description = "SSH public key"
  type        = string
  sensitive   = true
}

# -- Provisioning Settings
variable "enable_provisioning" {
  description = "Enable provisioning via SSH"
  type        = bool
  default     = false
}

variable "ssh_private_key_path" {
  description = "Path to SSH private key"
  type        = string
  default     = "~/.ssh/id_ed25519"
  sensitive   = true
}

variable "connection_timeout" {
  description = "SSH connection timeout"
  type        = string
  default     = "2m"
}

variable "provision_ssh_keys" {
  description = "Provision SSH keys"
  type        = bool
  default     = false
}

variable "provision_git" {
  description = "Provision Git"
  type        = bool
  default     = false
}

variable "provision_terraform" {
  description = "Provision Terraform"
  type        = bool
  default     = false
}

variable "terraform_version" {
  description = "Terraform version to install"
  type        = string
  default     = "1.7.5"
}

variable "provision_git_repo" {
  description = "Clone a Git repository"
  type        = bool
  default     = false
}

variable "git_repo_url" {
  description = "URL of the Git repository"
  type        = string
  default     = ""
}

variable "git_branch" {
  description = "Git branch to checkout"
  type        = string
  default     = "main"
}