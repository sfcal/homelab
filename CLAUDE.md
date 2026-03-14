# Homelab — Claude Guidelines

## Project Overview

Infrastructure-as-Code homelab on Proxmox. Uses Terraform (VM provisioning), Ansible (configuration/deployment), Packer (VM templates), and go-task (task runner). Multiple environments: wil (dev), ldn, nyc (prod), external.

## Repository Structure

```
ansible/                    Playbooks, roles, per-environment inventories and group_vars
terraform/                  VM provisioning with per-environment tfvars and state
packer/                     VM template building (Ubuntu, Debian)
docker/                     Docker execution environment
tui/                        Textual-based terminal UI (Python, UV)
.taskfiles/                 Modular Taskfile configs (ansible, terraform, packer, ca, docker)
docs/                       MkDocs documentation site
Taskfile.yaml               Root task runner entry point
```

## Task Commands

All operations go through `task`. Pattern: `task <namespace>:<operation> ENV=<environment>`

```
task ansible:deploy-<service> ENV=wil    # Deploy a service
task terraform:deploy ENV=wil            # Deploy all VMs
task terraform:deploy-vm ENV=wil VM=key  # Deploy specific VM
task packer:build-ubuntu ENV=wil         # Build VM template
task ca:health ENV=wil                   # Check CA health
```

Discover all tasks: `task --list-all --json`

## Environments

Auto-discovered from `ansible/environments/*/`. Each has:
- `ansible/environments/<env>/hosts.ini` — inventory
- `ansible/environments/<env>/group_vars/` — per-group YAML vars
- `terraform/environments/<env>/vms.auto.tfvars` — VM definitions (HCL)
- `terraform/environments/<env>/terraform.tfstate` — provisioning state

Network ranges: wil=10.2.x.x, ldn=10.3.x.x, nyc=10.1.x.x

## Conventions

### Naming
- All variables: `snake_case`
- Ansible groups: `infra_*` (infrastructure), `app_*` (applications)
- Terraform VM keys: `snake_case` (e.g., `networking`, `ca_server`, `games_server`)
- Files/directories: `snake_case` with hyphens for app names (e.g., `games-server`, `it-tools`)
- Domains: lowercase dot-separated (5am.video, wil.5am.cloud)

### YAML
- 2-space indentation
- Files start with `---`
- Section comments: `# --- Section Name ---`

### Ansible Playbook Pattern
Every playbook follows this structure:
```yaml
---
- name: Deploy <Service>
  hosts: <group_name>
  become: true
  handlers:
    - name: Include handlers
      ansible.builtin.import_tasks: handlers/main.yml
  pre_tasks:
    - name: Include common prerequisites
      ansible.builtin.include_role:
        name: common
  tasks:
    - name: <Task>
      ansible.builtin.include_tasks: tasks/<taskname>.yml
```

### Terraform
- VM definitions in `vms.auto.tfvars` as HCL map
- Fields: name, description, proxmox_node, vmid, template_name, ip_address, gateway, nameserver, cores, memory, disk_size, storage_pool, network_bridge, tags, ssh_user
- Tags: "infrastructure" or "application"
- Uses `python-hcl2` for parsing; custom writer for output (python-hcl2 can't write)

### Docker Compose Templates
- Jinja2 templates at `playbooks/<service>/templates/compose.yaml.j2`
- Service naming: deployed as `compose.yaml`
- Restart policy: `unless-stopped`
- LinuxServer images use PGID/PUID/UMASK vars

## Secrets

SOPS with AGE encryption. Key at `~/.config/sops/age/keys.txt`.
- `*.sops.yml` — encrypted ansible vars
- `*.tfvars` — encrypted terraform vars (credentials)
- `*.pkrvars.hcl` — encrypted packer vars
- `.env` files — encrypted docker env files
- Never commit decrypted secrets. Decrypted temps match `**/.decrypted~*`

## Git

- Commit messages: short, lowercase, no conventional commits prefix
- Work directly on main branch
- SSH user: sfcal

## Key File Locations

| Purpose | Path |
|---------|------|
| Root taskfile | `Taskfile.yaml` |
| Ansible tasks | `.taskfiles/ansible/Taskfile.yaml` |
| Terraform tasks | `.taskfiles/terraform/Taskfile.yaml` |
| VM module | `terraform/modules/vm/main.tf` |
| Master playbook | `ansible/playbooks/site.yml` |
| SOPS config | `.sops.yaml` |
| TUI prompt/spec | `tui/PROMPT.md` |

## Common Operations

```bash
# Deploy a service
task ansible:deploy-media ENV=wil

# Provision all VMs
task terraform:deploy ENV=wil

# Build a packer template
task packer:build-ubuntu ENV=wil TEMPLATE=base

# Check CA health
task ca:health ENV=wil

# Ping all hosts
task ansible:ping ENV=wil

# Decrypt a sops file
sops decrypt ansible/environments/wil/group_vars/all/secrets.sops.yml
```

## Proxy & DNS Service Definitions

Services get DNS records and reverse proxy entries via `group_vars/all/proxy/`. One file per domain:

```
ansible/environments/<env>/group_vars/all/proxy/
├── _services.yml          # Aggregates all domain lists into unified `services` variable
├── 5am.video.yml          # video_services list
├── wil.5am.cloud.yml      # wil_services list
├── ext.5am.cloud.yml      # ext_services list
└── sfc.al.yml             # sfc_services list
```

Each service entry:
```yaml
- name: myapp              # Subdomain (myapp.wil.5am.cloud)
  backend_host: 10.2.20.60 # Backend IP
  backend_port: 8080        # Backend port
  proxied: true             # true=Caddy proxy, false=DNS direct to backend
  # Optional:
  # tls_skip_verify: true   # Backend uses self-signed HTTPS
  # forward_headers: true   # Adds X-Real-IP, X-Forwarded-For
  # host_header: upstream   # Overrides Host header
  # encode: gzip            # Response encoding
  # dns: external           # Skips internal A record generation
  # enabled: false          # Disables both DNS and Caddy entries
```

`_services.yml` aggregates all lists with domain injection:
```yaml
services: >-
  {{
    (video_services | default([]) | map('combine', {'domain': '5am.video'}) | list) +
    (wil_services | default([]) | map('combine', {'domain': 'wil.5am.cloud'}) | list) +
    ...
  }}
```

Both BIND9 (DNS) and Caddy (reverse proxy) templates consume the unified `services` list.

## Adding New Services

1. Create playbook: `ansible/playbooks/apps/<service>/deploy.yml` (follow existing pattern)
2. Create group_vars: `ansible/environments/<env>/group_vars/app_<service>/`
3. Add host group to `hosts.ini` under `[app_<service>]` and `[apps:children]`
4. Add proxy/DNS entry to the appropriate domain file in `group_vars/all/proxy/<domain>.yml`
5. Add task to `.taskfiles/ansible/Taskfile.yaml`
6. Add import to `ansible/playbooks/site.yml`
7. If new VM needed: add to `terraform/environments/<env>/vms.auto.tfvars`
