# Config Reference

Consolidated reference for configuration formats used across the homelab.

## Service Definitions

Service definitions drive both DNS records and reverse proxy entries. Each domain has its own file in `ansible/environments/<env>/group_vars/all/proxy/`:

```
proxy/
├── _services.yml          # Aggregates all domain lists
├── 5am.video.yml          # video_services
├── wil.5am.cloud.yml      # wil_services
├── ext.5am.cloud.yml      # ext_services
└── sfc.al.yml             # sfc_services
```

### Service Entry Format

```yaml
- name: myapp              # Subdomain → myapp.wil.5am.cloud
  backend_host: 10.2.20.60
  backend_port: 8080
  proxied: true             # true = Caddy proxy, false = DNS direct
```

### All Fields

| Field | Required | Default | Description |
|-------|----------|---------|-------------|
| `name` | yes | — | Subdomain name |
| `backend_host` | yes | — | Backend IP address |
| `backend_port` | yes | — | Backend port |
| `proxied` | yes | — | Route through Caddy (`true`) or direct DNS (`false`) |
| `enabled` | no | `true` | Set `false` to disable both DNS and proxy |
| `dns` | no | — | Set `external` to skip internal A record |
| `tls_skip_verify` | no | `false` | Backend uses self-signed HTTPS |
| `forward_headers` | no | `false` | Add `X-Real-IP`, `X-Forwarded-For` headers |
| `host_header` | no | — | Override `Host` header sent to upstream |
| `encode` | no | — | Response encoding (e.g., `gzip`) |
| `read_buffer` | no | — | Read buffer size |

### Service Aggregation

`_services.yml` combines all domain lists and injects the domain name:

```yaml
services: >-
  {{
    (video_services | default([]) | map('combine', {'domain': '5am.video'}) | list) +
    (wil_services | default([]) | map('combine', {'domain': 'wil.5am.cloud'}) | list) +
    (ext_services | default([]) | map('combine', {'domain': 'ext.5am.cloud'}) | list) +
    (sfc_services | default([]) | map('combine', {'domain': 'sfc.al'}) | list)
  }}
```

Both BIND9 and Caddy templates consume the unified `services` list.

## VM Definitions

VMs are defined in HCL maps in `terraform/environments/<env>/vms.auto.tfvars`. See [Terraform — VM Module Variables](terraform.md#vm-module-variables) for the full field reference.

## App Registry

Data-driven apps are defined in `ansible/environments/<env>/group_vars/all/apps.yml`:

```yaml
myapp:
  host_group: app_myapp      # Ansible inventory group
  images:                     # Docker images to pull
    - myimage:latest
  port: 8080                  # Exposed port
  # Optional:
  # nfs: true                 # Mount NFS shares
  # user: "1000"              # Service user
  # group: "1000"             # Service group
```

## File Naming Conventions

| Pattern | Purpose |
|---------|---------|
| `*.sops.yml` | SOPS-encrypted Ansible variables |
| `*.tfvars` | Terraform variables (encrypted) |
| `*.pkrvars.hcl` | Packer variables (encrypted) |
| `*.env` | Docker environment files (encrypted) |
| `compose.yaml.j2` | Jinja2 Docker Compose template |
| `hosts.ini` | Ansible inventory |
| `vms.auto.tfvars` | VM definitions (auto-loaded by Terraform) |

## Ansible Group Naming

| Prefix | Purpose | Example |
|--------|---------|---------|
| `infra_*` | Infrastructure services | `infra_networking`, `infra_ca` |
| `app_*` | Applications | `app_mediastack`, `app_birdle` |

Parent groups: `[infrastructure:children]` and `[apps:children]` aggregate all groups of each type.

## Global Variables

Defined in `ansible/environments/<env>/group_vars/all/vars.yml`:

```yaml
domains:
  - 5am.video
  - 5am.cloud
  - wil.5am.cloud
  - ext.5am.cloud
  - sfc.al

system_timezone: America/New_York
deploy_path: /opt
```
