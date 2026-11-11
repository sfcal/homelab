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
│   ├── main.tf                      # proxmox_virtual_environment_vm resource (bpg/proxmox)
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
| `template_name` | string | required | Packer template to clone; exactly one template of that name must exist on `proxmox_node` |
| `tags` | string | `""` | `"infrastructure"` or `"application"` |
| `onboot` | bool | `true` | Auto-start on Proxmox boot |
| `cores` | number | `2` | CPU cores |
| `memory` | number | `2048` | RAM in MB |
| `disk_size` | string | `"20G"` | Root disk size in GB, written `"<N>G"` |
| `storage_pool` | string | required | Proxmox storage pool |
| `network_bridge` | string | `"vmbr0"` | Network bridge |
| `ip_address` | string | required | Static IP (assumes /24) |
| `gateway` | string | required | Default gateway |
| `nameserver` | string | required | DNS server |
| `ssh_user` | string | required | SSH username |
| `ssh_public_key` | string | required | Passed from environment variables; one key per line |
| `bios` | string | `"seabios"` | `"ovmf"` for UEFI (required with `pci_mapping`) |
| `machine` | string | `""` (Proxmox default) | `"q35"` for PCIe passthrough |
| `pci_mapping` | string | `""` | Proxmox PCI resource mapping ID (e.g. `b50-vf1`); see [Proxmox Hosts](../infrastructure/proxmox.md) |

## WIL Environment VMs

| Key | Name | VMID | IP | Cores | Memory | Disk | Tags |
|-----|------|------|----|-------|--------|------|------|
| `networking` | networking | 1000 | 10.2.20.53 | 2 | 4GB | 50G | infrastructure |
| `ca_server` | ca | 1003 | 10.2.20.9 | 1 | 4GB | 20G | infrastructure |
| `monitoring_server` | monitoring | 1107 | 10.2.20.30 | 1 | 8GB | 50G | infrastructure |

## Implementation Details

- **Provider** — [bpg/proxmox](https://registry.terraform.io/providers/bpg/proxmox/latest/docs), pinned in `versions.tf`. It takes the endpoint and API token from the variables in the site's `terraform.tfvars.sops` (`proxmox_api_url` without `/api2/json`, `<token id>=<secret>`), which each task decrypts for its one command (`sops exec-file`).
- **Full clones** — VMs are full clones, not linked. Independent of templates after creation. The template is looked up by name on every plan, so a missing or duplicated template name fails the plan (it never destroys anything).
- **Cloud-init** — Static IP via the `initialization` block (`ipconfig0: ip=<address>/24,gw=<gateway>`, drive on `ide0`). Assumes /24 subnets. bpg keeps cloud-init values of the template that the module does not set, such as a `cipassword` set by hand on the template; telmate removed them.
- **State** — Per-environment state files at `terraform/environments/<env>/terraform.tfstate`. Import a VM with `terraform import 'module.infrastructure.module.vms["<key>"].proxmox_virtual_environment_vm.vm' <node>/<vmid>`.
- **QEMU agent** — Enabled on all VMs (installed in Packer templates).

## Troubleshooting

**Plan error at `clone.vm_id`** — "Attempt to get attribute from null value" means no template named `template_name` exists on `proxmox_node`; "must be a list, set, or tuple value with either zero or one elements" means two templates share the name. Check with `qm list` on the Proxmox host. Names follow `ubuntu-server-<env>-base`.

**"VMID already exists"** — Another VM uses that ID. Check `qm list` or the existing entries in `vms.auto.tfvars`.

**State out of sync** — If a VM was deleted outside Terraform, it is still in the state. Drop it with `terraform state rm 'module.infrastructure.module.vms["<key>"]'` in `terraform/environments/<env>/` and redeploy. (`task terraform:clean` only removes the plugin cache.)

**Provider authentication error** — Verify the Proxmox API credentials in the encrypted `terraform.tfvars.sops`. Open it with `sops terraform/environments/<env>/terraform.tfvars.sops`. The tasks decrypt it themselves and pass it with `-var-file`, which wins over a plain-text `terraform.tfvars` left in the folder, so that copy is no longer needed.
