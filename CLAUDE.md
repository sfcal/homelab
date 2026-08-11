# Homelab — Claude Guidelines

## Project Overview

Infrastructure-as-Code homelab on Proxmox. Uses Terraform (VM provisioning), Ansible (configuration/deployment), Packer (VM templates), and go-task (task runner). Multiple environments: wil (dev), ldn (prod), external.

## Repository Structure

```
ansible/                    Playbooks, roles, per-environment inventories and group_vars
terraform/                  VM provisioning with per-environment tfvars and state
packer/                     VM template building (Ubuntu, Debian)
docker/                     Docker execution environment
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

Network ranges: wil=10.2.x.x, ldn=10.3.x.x

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

The unified `services` list (consumed by both BIND9 and Caddy templates) is built from two sources in `group_vars/all/proxy/_services.yml`:

1. **Registry apps** — generated automatically from `proxy:` blocks in `group_vars/all/apps.yml` (`registry_services`). `backend_host` is derived from the first inventory host of the app's `host_group` (fails loudly if the group is empty); `backend_port` comes from the app's `port`. Add a registry app to DNS/proxy by adding a `proxy:` block:
   ```yaml
   apps:
     myapp:
       host_group: app_myapp
       # renovate: datasource=docker
       image: "example/myapp:latest"
       port: 8080
       proxy:
         name: myapp             # Subdomain (myapp.wil.5am.cloud)
         domain: wil.5am.cloud
         proxied: true           # required; true=Caddy proxy, false=DNS direct
         # Optional passthrough: tls_skip_verify, forward_headers,
         # host_header, encode, read_buffer, dns, enabled, backend_port
   ```
   Multi-service apps nest sub-services with their own `proxy:` blocks (see `apps.work.*`). Apps without a `proxy:` block get no DNS/proxy entry.

2. **Manual per-domain files** (`group_vars/all/proxy/<domain>.yml`) — ONLY for services outside the catalog: third-party devices (Proxmox, NAS, KVM, Haivision), media stack, monitoring, frigate, cloud-gaming. Same fields, plus explicit `backend_host`/`backend_port`:
   ```yaml
   - name: vm                 # Subdomain
     backend_host: 10.2.20.7  # Backend IP
     backend_port: 8006       # Backend port
     proxied: true
   ```

`_services.yml` aggregates the manual lists (with domain injection) and appends `registry_services`:
```yaml
services: >-
  {{
    (video_services | default([]) | map('combine', {'domain': '5am.video'}) | list) +
    (wil_services | default([]) | map('combine', {'domain': 'wil.5am.cloud'}) | list) +
    ... +
    registry_services
  }}
```

## Adding New Services

For a data-driven (registry) app:
1. Add the app to `ansible/environments/<env>/group_vars/all/apps.yml`: `host_group`, `image`, `port`, and a `proxy:` block for DNS/reverse-proxy (image keys end in `image`, double-quoted, `# renovate: datasource=docker` directly above; no separate `images:` list — the pre-pull list is derived)
2. Create the compose template: `ansible/playbooks/apps/<service>/templates/compose.yaml.j2` referencing `apps[app_name].<field>`
3. Add host group to `hosts.ini` under `[app_<service>]` and `[apps:children]`
4. Add import to `ansible/playbooks/site.yml` (uses `deploy-app.yml` with `app_name`)
5. Deploy: `task ansible:deploy-app APP=<service> ENV=<env>`, then `task ansible:deploy-networking ENV=<env>` for the DNS/proxy entry
6. If new VM needed: add to `terraform/environments/<env>/vms.auto.tfvars`

Non-catalog services (third-party devices, dedicated-playbook stacks) get manual proxy entries in `group_vars/all/proxy/<domain>.yml` instead of a `proxy:` block.
