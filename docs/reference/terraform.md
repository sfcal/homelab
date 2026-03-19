# Terraform

Terraform provisions VMs on Proxmox by cloning Packer-built templates.

## Quick Start

```bash
# Deploy all VMs
task terraform:deploy ENV=wil

# Deploy a single VM
task terraform:deploy-vm ENV=wil VM=networking

# Destroy a single VM
task terraform:destroy-vm ENV=wil VM=networking

# Clean up state files
task terraform:clean ENV=wil
```

## How It Works

VMs are defined as a map in `terraform/environments/<env>/vms.auto.tfvars`. The root module iterates over this map with `for_each` and calls the VM module for each entry.

```
terraform/
├── main.tf                          # Root module (for_each over vms)
├── modules/vm/
│   ├── main.tf                      # proxmox_vm_qemu resource
│   └── variables.tf                 # VM variable definitions
└── environments/
    ├── wil/
    │   ├── main.tf                  # Calls root module
    │   ├── variables.tf             # Variable declarations
    │   ├── providers.tf             # Proxmox provider config
    │   ├── vms.auto.tfvars          # VM definitions
    │   └── terraform.tfstate        # State file
    └── ldn/
```

## VM Definition Format

Each VM is an entry in the `vms` map in `vms.auto.tfvars`:

```hcl
vms = {
  networking = {
    name           = "networking"
    description    = "Networking VM"
    proxmox_node   = "proxmox"
    vmid           = 1000
    template_name  = "ubuntu-server-wil-base"
    ip_address     = "10.2.20.53"
    gateway        = "10.2.20.1"
    nameserver     = "10.2.20.53"
    cores          = 2
    memory         = 4096
    disk_size      = "50G"
    storage_pool   = "local-lvm"
    network_bridge = "vmbr0"
    tags           = "infrastructure"
    ssh_user       = "sfcal"
  }

  ca_server = {
    name           = "ca"
    description    = "Certificate Authority"
    proxmox_node   = "proxmox"
    vmid           = 1003
    template_name  = "ubuntu-server-wil-base"
    ip_address     = "10.2.20.9"
    gateway        = "10.2.20.1"
    nameserver     = "10.2.20.53"
    cores          = 1
    memory         = 4096
    disk_size      = "20G"
    storage_pool   = "local-lvm"
    network_bridge = "vmbr0"
    tags           = "infrastructure"
    ssh_user       = "sfcal"
  }
}
```

## VM Module Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `name` | string | required | VM hostname |
| `description` | string | `"Virtual Machine"` | Proxmox description |
| `proxmox_node` | string | required | Target Proxmox host |
| `vmid` | number | required | Unique VM ID |
| `template_name` | string | required | Packer template to clone |
| `tags` | string | `""` | `"infrastructure"` or `"application"` |
| `onboot` | bool | `true` | Auto-start on Proxmox boot |
| `cores` | number | `2` | CPU cores |
| `memory` | number | `2048` | RAM in MB |
| `disk_size` | string | `"20G"` | Root disk size |
| `storage_pool` | string | required | Proxmox storage pool |
| `network_bridge` | string | `"vmbr0"` | Network bridge |
| `ip_address` | string | required | Static IP (assumes /24) |
| `gateway` | string | required | Default gateway |
| `nameserver` | string | required | DNS server |
| `ssh_user` | string | required | SSH username |
| `ssh_public_key` | string | required | Passed from environment variables |

## WIL Environment VMs

| Key | Name | VMID | IP | Cores | Memory | Disk | Tags |
|-----|------|------|----|-------|--------|------|------|
| `networking` | networking | 1000 | 10.2.20.53 | 2 | 4GB | 50G | infrastructure |
| `ca_server` | ca | 1003 | 10.2.20.9 | 1 | 4GB | 20G | infrastructure |
| `ntp_server` | ntp | 1002 | 10.2.20.123 | 1 | 1GB | 20G | infrastructure |
| `monitoring_server` | monitoring | 1107 | 10.2.20.30 | 1 | 8GB | 50G | infrastructure |
| `web_server` | web | 1109 | 10.2.20.45 | 2 | 4GB | 20G | application |
| `games_server` | games | 1111 | 10.2.20.50 | 1 | 8GB | 50G | application |
| `work_server` | work | 1112 | 10.2.20.60 | 4 | 8GB | 256G | application |
| `seafile_server` | seafile | 1113 | 10.2.20.70 | 2 | 8GB | 50G | application |

## Implementation Details

- **Full clones** — VMs are full clones, not linked. Independent of templates after creation.
- **Cloud-init** — Static IP configured via `ipconfig0 = "ip=<address>/24,gw=<gateway>"`. Assumes /24 subnets.
- **State** — Per-environment state files at `terraform/environments/<env>/terraform.tfstate`.
- **QEMU agent** — Enabled on all VMs (installed in Packer templates).

## Troubleshooting

**"template not found"** — The `template_name` must match a Packer-built template. Check with `qm list` on the Proxmox host. Names follow `ubuntu-server-<env>-base`.

**"VMID already exists"** — Another VM uses that ID. Check `qm list` or the existing entries in `vms.auto.tfvars`.

**State out of sync** — If a VM was deleted outside Terraform, clean state with `task terraform:clean ENV=wil` and redeploy.

**Provider authentication error** — Verify Proxmox API credentials in the encrypted `terraform.tfvars` file. Decrypt with `sops terraform/environments/<env>/terraform.tfvars`.
