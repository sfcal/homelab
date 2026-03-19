# Quick Start

Deploy the homelab from scratch in four steps.

!!! note
    Complete the [Prerequisites](index.md) first. You need Proxmox API tokens, an SSH key, and an Age key before proceeding.

## 1. Clone and Configure

```bash
git clone git@github.com:sfcal/homelab.git
cd homelab
```

Set your environment (defaults to `dev`):

```bash
export ENV=wil
```

## 2. Build VM Templates

Build the base Ubuntu template on Proxmox:

```bash
task packer:build-ubuntu ENV=wil
```

This creates a cloud-init-enabled Ubuntu Server template with Docker, Node Exporter, and Lazydocker pre-installed.

!!! tip
    Debian templates are also available: `task packer:build-debian ENV=wil`

## 3. Provision VMs

Deploy all VMs defined in `terraform/environments/wil/vms.auto.tfvars`:

```bash
task terraform:deploy ENV=wil
```

To provision a single VM:

```bash
task terraform:deploy-vm ENV=wil VM=networking
```

!!! warning
    The **networking** VM must be provisioned first — it provides DNS for all other VMs.

## 4. Deploy Services

Deploy the full infrastructure stack:

```bash
task ansible:deploy-all ENV=wil
```

Or deploy services individually, in dependency order:

```bash
task ansible:deploy-networking ENV=wil     # DNS, Caddy, Tailscale
task ansible:deploy-ca ENV=wil             # Step-CA certificate authority
task ansible:deploy-ntp ENV=wil            # Chrony time server
task ansible:deploy-monitoring ENV=wil     # Prometheus, Grafana, Homepage
task ansible:deploy-media ENV=wil          # Plex, *arr stack
```

## 5. Verify

```bash
# Test connectivity to all hosts
task ansible:ping ENV=wil

# Check a specific service
curl -k https://wil.5am.cloud
```

## Next Steps

- [Architecture](../concepts/architecture.md) — understand the pipeline
- [Deploy a Service](../guides/deploy-service.md) — add a new application
- [Task Commands](../reference/tasks.md) — full command reference

## Troubleshooting

**Packer build fails with 401** — Check Proxmox API token credentials in `packer/environments/wil/credentials.wil.pkrvars.hcl`. Ensure the token has `VM.Allocate` and `Datastore.AllocateSpace` permissions.

**Terraform can't find template** — The template name must match what Packer created. Check with `qm list` on the Proxmox host. Template names follow the pattern `ubuntu-server-<env>-base`.

**Ansible can't connect** — Verify the VM is running (`qm status <vmid>`), the IP is correct in `hosts.ini`, and your SSH key is authorized.

**DNS not resolving** — The networking VM must be deployed first. Other VMs use it as their nameserver (`10.2.20.53` in WIL).
