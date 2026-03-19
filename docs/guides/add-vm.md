# Add a New VM

Provision a new virtual machine on Proxmox using Terraform.

## 1. Define the VM

Add an entry to `terraform/environments/<env>/vms.auto.tfvars`:

```hcl
vms = {
  # ... existing VMs ...

  my_server = {
    name          = "myserver"
    description   = "My new server"
    proxmox_node  = "proxmox"
    vmid          = 1114
    template_name = "ubuntu-server-wil-base"
    ip_address    = "10.2.20.80"
    gateway       = "10.2.20.1"
    nameserver    = "10.2.20.53"
    cores         = 2
    memory        = 4096
    disk_size     = "50G"
    storage_pool  = "local-lvm"
    network_bridge = "vmbr0"
    tags          = "application"
    ssh_user      = "sfcal"
  }
}
```

!!! warning
    Ensure the `vmid` and `ip_address` are unique. Check existing entries in the same file.

## 2. Provision

Deploy just the new VM:

```bash
task terraform:deploy-vm ENV=wil VM=my_server
```

Or deploy all VMs:

```bash
task terraform:deploy ENV=wil
```

## 3. Add to Ansible Inventory

Add the VM's IP to `ansible/environments/<env>/hosts.ini`:

```ini
[app_myserver]
10.2.20.80

[apps:children]
# ... existing groups ...
app_myserver
```

## 4. Verify

```bash
# Test SSH access
ssh sfcal@10.2.20.80

# Test via Ansible
task ansible:ping ENV=wil
```

## VM Variable Reference

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `name` | string | required | VM hostname |
| `description` | string | `"Virtual Machine"` | Proxmox description |
| `proxmox_node` | string | required | Proxmox host (e.g., `proxmox`, `pve-lon`) |
| `vmid` | number | required | Unique Proxmox VM ID |
| `template_name` | string | required | Packer template to clone |
| `ip_address` | string | required | Static IP (assumes /24 subnet) |
| `gateway` | string | required | Default gateway |
| `nameserver` | string | required | DNS server (usually the networking VM) |
| `cores` | number | `2` | CPU cores |
| `memory` | number | `2048` | RAM in MB |
| `disk_size` | string | `"20G"` | Root disk size |
| `storage_pool` | string | required | Proxmox storage (e.g., `local-lvm`) |
| `network_bridge` | string | `"vmbr0"` | Network bridge |
| `tags` | string | `""` | `"infrastructure"` or `"application"` |
| `ssh_user` | string | required | SSH username |
| `onboot` | bool | `true` | Start on Proxmox boot |

## Troubleshooting

**Template not found** — The `template_name` must match an existing Packer template. Check with `qm list` on the Proxmox host. Build one with `task packer:build-ubuntu ENV=wil`.

**VMID conflict** — Each VM needs a unique VMID. Check existing IDs in `vms.auto.tfvars` or with `qm list`.

**Can't SSH after provisioning** — Cloud-init may still be running. Wait 30 seconds, then retry. Verify the IP is correct and the VM is on the right network bridge.

**State conflict** — If a VM was manually deleted, Terraform state is stale. Run `task terraform:clean ENV=wil` and redeploy.
