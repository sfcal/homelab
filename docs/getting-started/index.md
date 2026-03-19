# Prerequisites

Everything you need before deploying the homelab.

## Hardware

- **Proxmox VE 8.0+** host with latest updates
- **CPU**: 8+ cores
- **RAM**: 32GB minimum
- **Storage**: 500GB+ SSD/NVMe
- **Network**: 1Gbps connection, UDM Pro (or equivalent gateway)

## Software

Install these on your local machine:

```bash
# Task runner (required)
brew install go-task

# Infrastructure tools (run inside Docker execution environment)
task docker:exe
```

The Docker execution environment bundles Terraform, Ansible, Packer, and SOPS. Alternatively, install them directly:

| Tool | Purpose |
|------|---------|
| [Task](https://taskfile.dev/) | Command orchestration |
| [Terraform](https://www.terraform.io/) | VM provisioning |
| [Ansible](https://docs.ansible.com/) | Configuration management |
| [Packer](https://www.packer.io/) | VM template building |
| [SOPS](https://github.com/getsops/sops) | Secrets encryption |

## Access & Credentials

### Proxmox API Tokens

Create two API tokens in Proxmox (Datacenter > Permissions > API Tokens):

**Packer token** (`packer@pve!packer`):
```
VM.Allocate, VM.Clone, VM.Config.CDROM, VM.Config.CPU, VM.Config.Disk,
VM.Config.HWType, VM.Config.Memory, VM.Config.Network, VM.Config.Options,
VM.PowerMgmt, Datastore.AllocateSpace, Datastore.Audit
```

**Terraform token** (`terraform@pve!terraform`):
```
VM.Allocate, VM.Clone, VM.Config.CDROM, VM.Config.CPU, VM.Config.Disk,
VM.Config.HWType, VM.Config.Memory, VM.Config.Network, VM.Config.Options,
VM.PowerMgmt, VM.Audit, VM.Console, VM.Monitor,
Datastore.AllocateSpace, Datastore.Audit
```

### Other Credentials

- **SSH key pair** — ed25519, used for VM access
- **Age key** — at `~/.config/sops/age/keys.txt` for SOPS decryption
- **Cloudflare API token** — for DNS-01 TLS certificate challenges
- **Tailscale auth key** — for VPN mesh enrollment

## Network Planning

Reserve a /24 range per environment on VLAN 20:

| Environment | Network | Gateway |
|-------------|---------|---------|
| WIL (dev) | 10.2.20.0/24 | 10.2.20.1 |
| LDN (prod) | 10.3.20.0/24 | 10.3.20.1 |
| NYC (prod) | 10.1.20.0/24 | 10.1.20.1 |

## Verification Checklist

- [ ] Proxmox accessible and updated
- [ ] API tokens created with correct permissions
- [ ] SSH key pair generated
- [ ] Age key in `~/.config/sops/age/keys.txt`
- [ ] Cloudflare API token ready
- [ ] Network ranges reserved and documented
- [ ] Repository cloned: `git clone git@github.com:sfcal/homelab.git`

## Troubleshooting

**Can't connect to Proxmox API** — Verify the API URL includes `/api2/json` and the token has the `PVEAudit` role at minimum. Test with `curl`.

**Missing Age key** — Generate one with `age-keygen -o ~/.config/sops/age/keys.txt`. Add the public key to `.sops.yaml`.

**Task not found** — Install via `brew install go-task` or see [taskfile.dev](https://taskfile.dev/installation/).
