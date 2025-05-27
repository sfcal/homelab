# Frequently Asked Questions

## General Questions

### What is this project?

This is a complete Infrastructure as Code (IaC) solution for deploying and managing a Kubernetes homelab. It automates everything from VM creation to application deployment using industry-standard tools like Packer, Terraform, Ansible, and Flux.

### What do I need to run this?

At minimum, you need:
- A Proxmox server with at least 32GB RAM and 500GB storage
- Docker installed on your local machine
- Basic networking knowledge
- Patience and willingness to learn!

### Is this production-ready?

While this project uses production-grade tools and practices, it's designed for homelab use. For production environments, you'd want to add:
- High availability Proxmox cluster
- Proper backup solutions
- Security hardening
- Monitoring and alerting

## Installation Issues

### Packer build fails with "401 Unauthorized"

This usually means your Proxmox API token is incorrect. Verify:
1. Token exists in Proxmox
2. Token has the required permissions
3. Token format is correct: `user@realm!tokenname`

### Terraform can't find the template

Ensure:
1. Packer build completed successfully
2. Template name in Terraform matches what Packer created
3. You're targeting the correct Proxmox node

### Ansible can't connect to VMs

Check:
1. VMs have the correct IP addresses
2. SSH key was properly injected via cloud-init
3. No firewall blocking SSH (port 22)
4. You can manually SSH to the VMs

### K3s installation hangs

Common causes:
1. Network connectivity between nodes
2. Firewall blocking required ports
3. Incorrect `apiserver_endpoint` configuration
4. DNS resolution issues

## Networking Questions

### Can I use different IP ranges?

Yes! Update these files:
- `terraform/environments/dev/main.tf` - VM IP configuration
- `ansible/environments/dev/hosts.ini` - Ansible inventory
- `ansible/environments/dev/group_vars/all.yml` - K3s configuration

### How do I access services from outside?

You have several options:
1. **Port forwarding** on your router to MetalLB IPs
2. **Reverse proxy** like nginx on your network
3. **VPN access** to your homelab network
4. **Cloudflare Tunnel** for secure external access

### Why can't I resolve *.local.samuelcalvert.com?

You need to:
1. Add DNS entries pointing to your MetalLB IP range
2. Or add entries to your `/etc/hosts` file
3. Or use a tool like dnsmasq for local DNS

## Resource Questions

### How much RAM do I really need?

Minimum for dev environment:
- 3 masters × 4GB = 12GB
- 2 workers × 4GB = 8GB
- Total: 20GB for VMs + overhead

Recommended: 32GB+ for comfortable operation

### Can I run with fewer VMs?

Yes, but with limitations:
- Single master: No HA, risky for learning
- No workers: Workloads run on masters (not recommended)
- Minimum recommended: 1 master + 1 worker

### How much storage will I use?

Base usage:
- VM templates: ~5GB each
- VMs: ~20-50GB each
- Applications: Varies greatly

Plan for at least 250GB for a basic setup.

## Application Questions

### How do I add my own applications?

1. Create manifests in `kubernetes/apps/base/`
2. Add environment-specific configs in `kubernetes/apps/dev/`
3. Update `kustomization.yaml` files
4. Commit and push - Flux will deploy automatically

### Can I use Helm charts?

Yes! Flux supports Helm. Create a `HelmRelease` resource:

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: my-app
  namespace: default
spec:
  interval: 5m
  chart:
    spec:
      chart: my-chart
      version: '1.0.0'
      sourceRef:
        kind: HelmRepository
        name: my-repo
```

### How do I update applications?

For GitOps-managed apps:
1. Update manifests in Git
2. Push changes
3. Flux automatically syncs

For manual updates:
```bash
kubectl set image deployment/app app=image:newtag
```

## Troubleshooting

### How do I check Flux status?

```bash
# Overall status
flux get all

# Specific resources
flux get kustomizations
flux get helmreleases

# Logs
flux logs --follow
```

### Where are the logs?

- **Proxmox**: `/var/log/pve/`
- **K3s**: `journalctl -u k3s`
- **Pods**: `kubectl logs <pod-name>`
- **Flux**: `flux logs`

### How do I reset everything?

To start over:

```bash
# Destroy VMs
cd terraform/environments/dev
terraform destroy

# Clean up templates (optional)
# Manually delete from Proxmox UI

# Reset local state
rm -rf terraform/environments/dev/.terraform
rm -f terraform/environments/dev/terraform.tfstate*
```

## Best Practices

### Should I modify the base files?

No, use the environment-specific overrides:
- `environments/dev/` for development
- `environments/prod/` for production

### How do I handle secrets?

1. Never commit secrets to Git
2. Use Kubernetes secrets
3. Consider tools like Sealed Secrets or External Secrets
4. Use `.gitignore` for sensitive files

### How do I backup my cluster?

Consider:
1. **VM level**: Proxmox backup/snapshots
2. **Application level**: Velero for Kubernetes
3. **Data level**: Application-specific backups
4. **GitOps**: Your Git repo is your source of truth

## Getting Help

### Where can I get more help?

1. Check the [documentation](https://homelab.samuel.computer)
2. Search [existing issues](https://github.com/sfcal/homelab/issues)
3. Ask in [discussions](https://github.com/sfcal/homelab/discussions)
4. Open a new issue with details

### How can I contribute?

We welcome contributions! See [CONTRIBUTING.md](https://github.com/sfcal/homelab/blob/main/CONTRIBUTING.md) for guidelines.

### I found a security issue

Please report security issues privately to samuel.f.calvert@gmail.com instead of public issues.