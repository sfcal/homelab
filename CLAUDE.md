# Homelab — Claude Guidelines

## Project Overview

Infrastructure-as-Code homelab on Proxmox. Uses Terraform (VM provisioning), Ansible (configuration/deployment), Packer (VM templates), and go-task (task runner). Multiple environments: wil (dev), ldn (prod), ovh (the dashboard VPS: no Proxmox, no LAN).

## Repository Structure

```
ansible/                    Playbooks, roles, one inventory for both sites (ansible/inventory)
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
task ansible:deploy-proxmox ENV=ldn      # Proxmox host: SR-IOV GPU VFs + PCI mappings (group infra_proxmox)
task terraform:deploy ENV=wil            # Deploy all VMs
task terraform:deploy-vm ENV=wil VM=key  # Deploy specific VM
task packer:build-ubuntu ENV=wil         # Build VM template
task ca:health ENV=wil                   # Check CA health
```

Discover all tasks: `task --list-all --json`

## Environments

One Ansible inventory for both sites: `ansible/inventory/hosts.ini`. Every host is in its site group (`site_wil`, `site_ldn`) and in its role groups; the Taskfile turns `ENV=<env>` into `--limit site_<env>`. A host added to the inventory must also go under its `[site_<env>]` group.
- `ansible/inventory/group_vars/all/sites.yml` — one row per site (`cidr`, `tz`, `dns`, `ts_router_ips`, `zones`; a site without a LAN or DNS, like ovh, leaves out `cidr` and has empty lists). Cross-site values derive from it (BIND trusted networks, secondary zones, allow-transfer, also-notify) and so do `domains` and `system_timezone`; never hand-copy one site's addresses into the other's vars
- `ansible/inventory/group_vars/all/vars.yml` — values worked out for the host's site (`domains`, `system_timezone`, the DNS/proxy `services` list); `all/` holds only this file and `sites.yml`
- `ansible/inventory/group_vars/site_<env>/` — that site's own values: its app registry (`apps.yml`), its DNS/proxy entries (`proxy/<domain>.yml`), sub-folders named after the group that reads them (e.g. `site_wil/infra_networking/bind9.yml`; they apply to every host of the site), and all of the site's secrets in one file, `secrets.sops.yml`
- No `group_vars/<group>/` folders: a group that runs at one site only keeps its values in that site's folder too (`site_wil/app_mediastack/`, `site_ldn/infra_proxmox/`); if it starts running at the other site, copy the folder there. Site vars reach every host of the site, so never gate a task on `<var> is defined` when another group at the site sets that var (the gaming NFS step uses `gaming_nfs`, not `nfs_mounts`, for this reason)
- `terraform/environments/<env>/vms.auto.tfvars` — VM definitions (HCL)
- `terraform/environments/<env>/terraform.tfstate` — provisioning state

Network ranges: wil=10.2.x.x, ldn=10.3.x.x, ovh=none (VPS 135.148.219.216, tailnet name `dashboard`)

## Conventions

### Naming
- All variables: `snake_case`
- Ansible groups: `infra_*` (infrastructure), `app_*` (applications)
- Terraform VM keys: `snake_case` (e.g., `networking`, `ca_server`, `games_server`)
- Files/directories: `snake_case` with hyphens for app names (e.g., `media-stack`)
- Domains: lowercase dot-separated (5am.video, wil.5am.cloud)

### YAML
- 2-space indentation
- Files start with `---`
- Section comments: `# --- Section Name ---`

### Ansible Playbook Pattern
Every playbook follows this structure (exception: `infrastructure/proxmox/deploy.yml` targets the PVE host itself and skips the `common` role on purpose):
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
- Provider: bpg/proxmox (`proxmox_virtual_environment_vm`), pinned exactly in the root and env `versions.tf`
- VM definitions in `vms.auto.tfvars` as HCL map
- Fields: name, description, proxmox_node, vmid, template_name, ip_address, gateway, nameserver, cores, memory, disk_size, storage_pool, network_bridge, tags, ssh_user
- Tags: "infrastructure" or "application"
- Uses `python-hcl2` for parsing; custom writer for output (python-hcl2 can't write)

### Host Filesystem Layout (FHS)
Paths are hard-coded (no base-path variables); keep new templates on the same split:
- `/opt/<project>` — compose.yaml, Dockerfiles, Ansible-rendered config
- `/var/lib/<project>/<service>` — state containers write (databases, caches, uploads)
- `/var/log/<project>` — logs mounted out of containers
- `/srv/<project>` — files served to clients (netboot images, ROM library)

### Docker Compose Templates
- Jinja2 templates at `playbooks/<service>/templates/compose.yaml.j2`
- Service naming: deployed as `compose.yaml`
- Restart policy: `unless-stopped`
- LinuxServer images use PGID/PUID/UMASK vars

## Secrets

SOPS with AGE encryption. Key at `~/.config/sops/age/keys.txt`.
- `*.sops.yml` — encrypted ansible vars: one file per site, `ansible/inventory/group_vars/site_<env>/secrets.sops.yml`, with a `# --- <group> ---` section for each group that reads them (encrypted to master + that site's CI key; ovh has no CI key yet, so master only)
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
| Ansible inventory | `ansible/inventory/hosts.ini` |
| Sites table | `ansible/inventory/group_vars/all/sites.yml` |
| Ansible tasks | `.taskfiles/ansible/Taskfile.yaml` |
| Terraform tasks | `.taskfiles/terraform/Taskfile.yaml` |
| VM module | `terraform/modules/vm/main.tf` |
| Master playbook | `ansible/playbooks/site.yml` |
| SOPS config | `.sops.yaml` |
| Deploy workflow | `.github/workflows/deploy.yml` |
| Deploy target planner | `.github/scripts/deploy-plan.sh` |

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
sops decrypt ansible/inventory/group_vars/site_wil/secrets.sops.yml
```

## GitOps Deploys (CI)

Renovate merges that touch `ansible/inventory/group_vars/` deploy automatically via `.github/workflows/deploy.yml` (GitHub-hosted runner → Tailscale `tag:ci` → `deploy` user). See `docs/guides/gitops.md`.
- Auto-deploy allowlist lives in `.github/scripts/deploy-plan.sh` (`PLAYBOOK_FOR`); keep it in sync with the host pattern in `ansible/playbooks/ci-access.yml` and `TARGET_PATTERN` in `.taskfiles/ci/Taskfile.yaml`
- Only commits authored by `renovate[bot]` auto-deploy; tag `deploy/<env>` marks the last successful CI deploy (don't move it by hand)
- Compose changes must not notify restart handlers — `docker_compose_v2 state: present` recreates only changed services. Restart handlers are for bind-mounted config files, scoped with `services:`
- Never add `--diff`/`-v` to CI runs; rendered templates contain decrypted secrets
- Each site's sops file (`group_vars/site_<env>/secrets.sops.yml`) is encrypted to master + that site's CI age key (`.sops.yaml`, `# ci:<env>` rules), so every CI ansible run must keep `--limit site_<env>`: without it Ansible tries to decrypt the other site's file and fails
- The planner maps a changed file to a site: `site_<env>/<group>/` and the folders of groups with hosts at the site count for it, `site_<env>/apps.yml` deploys only the apps whose entry changed; files moved unchanged don't count

## Proxy & DNS Service Definitions

The unified `services` list (consumed by both BIND9 and Caddy templates) is built in `group_vars/all/vars.yml` from two sources in the host's site folder:

1. **Registry apps** — generated automatically from `proxy:` blocks in the site's registry `group_vars/site_<env>/apps.yml` (`registry_services`). A site's networking sees only its own registry, so a `proxy:` block must use one of its own site's zones. `backend_host` is derived from the first inventory host of the app's `host_group` (fails loudly if the group is empty); `backend_port` comes from the app's `port`. Add a registry app to DNS/proxy by adding a `proxy:` block:
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
         # host_header, encode, read_buffer, auth, dns, enabled, backend_port
   ```
   Multi-service apps nest sub-services with their own `proxy:` blocks (see `apps.work.*`). Apps without a `proxy:` block get no DNS/proxy entry.

2. **Manual per-domain files** (`group_vars/site_<env>/proxy/<domain>.yml`, in the folder of the site that is primary for the domain) — ONLY for services outside the catalog: third-party devices (Proxmox, NAS, KVM, Haivision), media stack, monitoring, frigate, gaming (Wolf, RomM). Same fields, plus explicit `backend_host`/`backend_port`:
   ```yaml
   - name: vm                 # Subdomain
     backend_host: 10.2.20.7  # Backend IP
     backend_port: 8006       # Backend port
     proxied: true
   ```

`services` in `all/vars.yml` aggregates the manual lists (with domain injection), appends `registry_services`, and keeps only the zones of the host's site:
```yaml
services: >-
  {{
    (
      (video_services | default([]) | map('combine', {'domain': '5am.video'}) | list) +
      (wil_services | default([]) | map('combine', {'domain': 'wil.5am.cloud'}) | list) +
      ... +
      registry_services
    ) | selectattr('domain', 'in', sites[site].zones) | list
  }}
```
A manual entry that points at another site's registry app can't read that site's registry: it takes the host from the inventory (`backend_host: "{{ groups['app_kosync'] | first }}"`, not a copied IP) and repeats the port, with a comment at both ends (`kosync` in `site_wil/proxy/5am.cloud.yml` and in `site_ldn/apps.yml`); a change to that app then needs a networking deploy at that site too.

### Single Sign-On (Authelia)

Authelia (login page) and oauth2-proxy (login check) run next to Caddy on each networking VM (`tasks/authelia.yml`, one compose project in `/opt/authelia`, state in `/var/lib/authelia`). See `docs/infrastructure/networking/sso.md`.
- `auth: true` on a service entry (or inside a registry `proxy:` block) wraps it in the Caddyfile's `(login)` block: Caddy asks oauth2-proxy, which sends the browser to Authelia (OpenID Connect) and back. Works on any domain. Browser UIs only: leave it off anything apps, devices or scripts reach by hostname (Plex, KOSync, MicroBin) and off public sites
- A service entry named `auth` (backend `authelia:9091`) is the site's login page; one per site: `auth.wil.5am.cloud`, `auth.ldn.5am.cloud`. Never add a login page on another domain
- Authelia's client `redirect_uris` and oauth2-proxy's cookie domains are generated from the flagged services, so flagging a service needs only a networking deploy
- Secrets per site in the `infra_networking` section of `group_vars/site_<env>/secrets.sops.yml` (names listed in `infra_networking/authelia.yml`)
- Kasm stays unflagged: it logs in through Authelia itself as a second OpenID Connect client (`kasm` in `authelia-configuration.yml.j2`; its side lives in Kasm's database, values in the SSO docs)

## Adding New Services

For a data-driven (registry) app:
1. Add the app to the registry of the site that hosts it, `ansible/inventory/group_vars/site_<env>/apps.yml`: `host_group`, `image`, `port`, and a `proxy:` block for DNS/reverse-proxy (image keys end in `image`, double-quoted, `# renovate: datasource=docker` directly above; no separate `images:` list — the pre-pull list is derived). For a browser UI on the site domain, add `auth: true` to the `proxy:` block to put it behind the login
2. Create the compose template: `ansible/playbooks/apps/<service>/templates/compose.yaml.j2` referencing `apps[app_name].<field>`
3. Add host group to `ansible/inventory/hosts.ini` under `[app_<service>]` and `[apps:children]`, and the host under its `[site_<env>]` group
4. Add import to `ansible/playbooks/site.yml` (uses `deploy-app.yml` with `app_name`)
5. Deploy: `task ansible:deploy-app APP=<service> ENV=<env>`, then `task ansible:deploy-networking ENV=<env>` for the DNS/proxy entry
6. If new VM needed: add to `terraform/environments/<env>/vms.auto.tfvars`

Non-catalog services (third-party devices, dedicated-playbook stacks) get manual proxy entries in `group_vars/site_<env>/proxy/<domain>.yml` instead of a `proxy:` block.
