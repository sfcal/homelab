# Prerequisites

Before deploying the homelab infrastructure, ensure you have the following prerequisites in place.

## Hardware Requirements

### Proxmox Host(s)

- **Minimum**: 1 Proxmox server
- **Recommended**: 3+ Proxmox servers for HA
- **CPU**: 8+ cores (16+ recommended)
- **RAM**: 32GB minimum (64GB+ recommended)
- **Storage**: 500GB+ SSD/NVMe
- **Network**: 1Gbps+ network connection

### Resource Allocation

For a minimal dev environment, you'll need:

| Component | VMs | CPU per VM | RAM per VM | Storage per VM |
|-----------|-----|------------|------------|----------------|
| K3s Masters | 3 | 2 cores | 4GB | 50GB |
| K3s Workers | 2 | 2 cores | 4GB | 50GB |
| **Total** | **5** | **10 cores** | **20GB** | **250GB** |

## Software Requirements

### On Your Local Machine

1. **Docker & Docker Compose**
   ```bash
   # Check if installed
   docker --version
   docker compose version
   ```

2. **Git**
   ```bash
   # Check if installed
   git --version
   ```

3. **SSH Client**
   ```bash
   # Generate SSH key if needed
   ssh-keygen -t ed25519 -C "your-email@example.com"
   ```

### On Proxmox

1. **Proxmox VE 8.0+**
   - Latest updates installed
   - Valid subscription or configured no-subscription repository

2. **ISO Images**
   - Ubuntu Server 24.04 LTS ISO uploaded to Proxmox storage

3. **Storage Configuration**
   - At least one storage pool configured (e.g., local-lvm)
   - Sufficient free space for VMs

## Network Requirements

### IP Address Planning

Reserve the following IP ranges for your environment:

| Environment | Network | Purpose | IP Range |
|-------------|---------|---------|----------|
| Dev | 10.1.20.0/24 | K3s Cluster | 10.1.20.40-60 |
| Dev | 10.1.20.0/24 | MetalLB Pool | 10.1.20.140-150 |
| Dev | 10.1.20.0/24 | Virtual IP | 10.1.20.222 |
| Prod | 10.2.20.0/24 | K3s Cluster | 10.2.20.40-60 |
| Prod | 10.2.20.0/24 | MetalLB Pool | 10.2.20.140-150 |
| Prod | 10.2.20.0/24 | Virtual IP | 10.2.20.222 |

### DNS Configuration

- Configure local DNS to resolve `*.local.samuelcalvert.com` to your MetalLB IP range
- Or plan to use `/etc/hosts` entries for testing

### Firewall Rules

Ensure the following ports are open between nodes:

| Port | Protocol | Purpose |
|------|----------|---------|
| 6443 | TCP | Kubernetes API |
| 10250 | TCP | Kubelet API |
| 2379-2380 | TCP | etcd |
| 8472 | UDP | Flannel VXLAN |
| 51820-51821 | UDP | WireGuard (if used) |

## Proxmox Configuration

### API Token Creation

1. Log into Proxmox web UI
2. Navigate to Datacenter → Permissions → API Tokens
3. Create tokens for:
   - **Packer**: `packer@pve!packer` with VM creation permissions
   - **Terraform**: `terraform@pve!terraform` with full VM permissions

### Required Permissions

For the Packer token:
```
VM.Allocate
VM.Clone
VM.Config.CDROM
VM.Config.CPU
VM.Config.Disk
VM.Config.HWType
VM.Config.Memory
VM.Config.Network
VM.Config.Options
VM.PowerMgmt
Datastore.AllocateSpace
Datastore.Audit
```

For the Terraform token:
```
VM.Allocate
VM.Clone
VM.Config.CDROM
VM.Config.CPU
VM.Config.Disk
VM.Config.HWType
VM.Config.Memory
VM.Config.Network
VM.Config.Options
VM.PowerMgmt
VM.Audit
VM.Console
VM.Monitor
Datastore.AllocateSpace
Datastore.Audit
```

## Optional But Recommended

### Backup Solution

- Configure Proxmox Backup Server or similar
- Plan backup strategy for VMs and persistent data

### Monitoring

- Consider setting up external monitoring for Proxmox hosts
- Plan for log aggregation

### Security

- Configure Proxmox firewall
- Set up fail2ban on Proxmox hosts
- Use strong passwords and API tokens
- Consider VPN access for management

## Verification Checklist

Before proceeding, verify:

- [ ] Proxmox is accessible and updated
- [ ] Sufficient resources available
- [ ] Network ranges are free and documented
- [ ] API tokens are created with correct permissions
- [ ] Ubuntu ISO is uploaded to Proxmox storage
- [ ] SSH keys are generated
- [ ] Docker is installed locally
- [ ] Git repository is cloned

Once all prerequisites are met, proceed to the [Quick Start Guide](quick-start.md).