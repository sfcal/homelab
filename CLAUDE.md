# Homelab — Claude Guidelines

## Project Overview

Infrastructure-as-Code homelab on Proxmox. Uses Terraform (VM provisioning), Ansible (configuration/deployment), Packer (VM templates), and go-task (task runner). Multiple environments: wil (dev), ldn (prod), ovh (the dashboard VPS: no Proxmox, no LAN).

## Repository Structure

```
ansible/                    Playbooks, roles, one inventory for both sites (ansible/inventory)
terraform/                  VM provisioning with per-environment tfvars and state
packer/                     VM template building (Ubuntu, Windows)
.taskfiles/                 Modular Taskfile configs (ansible, terraform, packer, ca, docker)
docs/                       MkDocs documentation site
Taskfile.yaml               Root task runner entry point
```

## Task Commands

All operations go through `task`. Pattern: `task <namespace>:<operation> ENV=<environment>`. `ENV` has no default: a task that needs it stops with "Pass ENV=<site>" when it is missing.

```
task ansible:deploy-<service> ENV=wil    # Deploy a service
task ansible:deploy-proxmox ENV=ldn      # Proxmox hosts (group infra_proxmox): node-exporter; on pve-ldn SR-IOV GPU VFs + PCI mappings
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
- Terraform VM keys: `snake_case` (e.g., `networking`, `ca_server`, `monitoring_server`)
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
- `terraform.tfvars.sops` — encrypted terraform vars (credentials), one per `terraform/environments/<env>/`
- `credentials.<env>.pkrvars.hcl.sops` — encrypted packer credentials
- The terraform and packer tasks decrypt these for the one command (`sops exec-file ... -var-file={}`); no plain-text `terraform.tfvars` or `credentials.<env>.pkrvars.hcl` is needed
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
| Alert rules | `ansible/playbooks/infrastructure/dashboard/files/grafana/provisioning/alerting/alerting.yml` |
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
- Auto-deploy allowlist lives in `.github/scripts/deploy-plan.sh` (`PLAYBOOK_FOR`); keep it in sync with the host pattern in `ansible/playbooks/ci-access.yml` (`task ci:known-hosts` reads its hosts from that playbook)
- Renovate never automerges image bumps CI can't deploy (`matchFileNames` rule in `renovate.json`: `infra_ca`, `infra_networking`, `app_hermes`, `site_ovh/`, Caddy's `Dockerfile.j2`); a group that pins an image and stays off the allowlist belongs in that rule. Automerges happen before 06:00 UTC on weekdays (`automergeSchedule`)
- One deploy run at a time (workflow-level `concurrency` in `deploy.yml`), so a run never plans from a `deploy/<env>` tag the run before it is about to move
- Only commits authored by `renovate[bot]` auto-deploy; tag `deploy/<env>` marks the last successful CI deploy (don't move it by hand)
- Compose changes must not notify restart handlers — `docker_compose_v2 state: present` recreates only changed services. Restart handlers are for bind-mounted config files, scoped with `services:`
- The sites' Caddy is reloaded, not restarted, when its Caddyfile changes (`Reload caddy` in the networking handlers feeds the file to `caddy reload` on stdin: the single-file bind mount still shows the old file). Requests in flight finish, websockets reconnect, a refused Caddyfile fails the deploy and the old config keeps serving
- Never add `--diff`/`-v` to CI runs; rendered templates contain decrypted secrets
- Each site's sops file (`group_vars/site_<env>/secrets.sops.yml`) is encrypted to master + that site's CI age key (`.sops.yaml`, `# ci:<env>` rules), so every CI ansible run must keep `--limit site_<env>`: without it Ansible tries to decrypt the other site's file and fails
- The planner maps a changed file to a site: `site_<env>/<group>/` and the folders of groups with hosts at the site count for it, `site_<env>/apps.yml` deploys only the apps whose entry changed; files moved unchanged don't count

## Alerts (Grafana)

Grafana on the VPS checks both sites' Prometheus once a minute and mails alerts. See `docs/infrastructure/monitoring/index.md` (Alerting).
- Rules, the email contact point and the notification policy are one provisioned file: `ansible/playbooks/infrastructure/dashboard/files/grafana/provisioning/alerting/alerting.yml`. A rule reads one datasource, so every rule is written twice (group `wil`, group `ldn`): change both
- Mail goes through Fastmail as `noreply@5am.cloud` with the login of Kanidm's mail sender (`GF_SMTP_*` in the dashboard compose) to `grafana_alert_email` in `site_ovh/secrets.sops.yml`. The contact point reads it as `$ALERT_EMAIL`, so the address stays out of the repo
- Grafana exits at start on a file it can't read (a bad duration is enough), and a dashboard deploy restarts it: after changing the file, start a local `grafana/grafana` container of the VPS's version with it first, and check http://dashboard:3000/alerting/list after the deploy
- What the rules see: node-exporter on every host under `[site_<env>]`, the Proxmox hosts included (Debian's package, `infrastructure/proxmox`), plus the VPS in ldn's Prometheus (Ubuntu's package on `127.0.0.1:9100`, put on the tailnet by `tailscale serve`; `dashboard/tasks/node-exporter.yml`). Install the exporter before the monitoring deploy that adds the target: a target that doesn't answer raises Target down after 5 minutes
- `blackbox-exporter` on each monitoring VM requests every proxied name of `services` once a minute (job `blackbox`; the loop in `prometheus.yml.j2` is the Caddyfile's): DNS, Caddy and the certificate. A new proxied name is checked after the next monitoring deploy

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
         # host_header, encode, read_buffer, no_service_worker, auth, dns,
         # enabled, backend_port
   ```
   Multi-service apps nest sub-services with their own `proxy:` blocks (see `apps.work.*`). Apps without a `proxy:` block get no DNS/proxy entry.

2. **Manual per-domain files** (`group_vars/site_<env>/proxy/<domain>.yml`, in the folder of the site that is primary for the domain) — ONLY for services outside the catalog: third-party devices (Proxmox, NAS, KVM, Haivision), media stack, monitoring, frigate, gaming (Wolf, RomM), Kasm. Same fields, plus explicit `backend_host`/`backend_port`:
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

### Single Sign-On (Kanidm)

Kanidm on the OVH VPS (dashboard playbook, `https://auth.5am.cloud`) is the one login for both sites, reachable only over the tailnet (`tailscale serve --tcp=443`, never a public listener or a Cloudflare record). Each networking VM runs oauth2-proxy next to Caddy as the login check (`tasks/oauth2-proxy.yml`, `/opt/oauth2-proxy`). See `docs/infrastructure/networking/sso.md`.
- `auth: true` on a service entry (or inside a registry `proxy:` block) wraps it in the Caddyfile's `(login)` block: Caddy asks oauth2-proxy, which sends the browser to Kanidm (OpenID Connect, client `oauth2-proxy-<site>`) and back. Works on any domain. Browser UIs only: leave it off anything apps, devices or scripts reach by hostname (Plex, KOSync, MicroBin) and off public sites
- Kanidm has no wildcard redirect URLs: `tasks/kanidm_redirects.yml` registers every flagged service's callback in each networking deploy, before Caddy, sent from the deploy machine (it must reach auth.5am.cloud), so flagging a service needs only a networking deploy; unflagging leaves the callback until removed by hand
- `auth.5am.cloud` is a record in wil's BIND (`site_wil/proxy/5am.cloud.yml`) pointing at `sites.ovh.tailnet_ip`; hosts that don't use BIND pin it (oauth2-proxy's container with `extra_hosts`, the Proxmox hosts in `/etc/hosts`)
- People, groups and clients live in Kanidm's database, managed with the `kanidm` CLI as `idm_admin`, whose password is not kept (`kanidmd recover-account`); not kanidm-provision
- Secrets per site in the `infra_networking` section of `group_vars/site_<env>/secrets.sops.yml` (names listed in `infra_networking/oauth2-proxy.yml`)
- Proxmox and wil's PBS (realm `sso`, clients `proxmox-<site>`, `pbs-wil`) and Kasm (client `kasm`, PKCE off) log in to Kanidm directly; their side lives in Proxmox, PBS and Kasm's database, values in the SSO docs
- Kanidm upgrades go one minor version at a time and can't be rolled back, so Renovate never automerges `kanidm/server`
- Password reset by email: `kanidm-mail-sender` (dashboard compose, `kanidm_tools_image`, kept at the server's version; Renovate groups the two) sends Kanidm's mail queue through Fastmail as `noreply@5am.cloud`; its token and the Fastmail login are in `site_ovh/secrets.sops.yml`. Its service account, each person's `mail` and the login page's Recover Account switch (`set-allow-account-recovery`, needs `admin`, not idm_admin) live in Kanidm's database. Test sending with the sender's `-t`: `message-queue send-test-message` is refused in 1.12.0

## Adding New Services

For a data-driven (registry) app:
1. Add the app to the registry of the site that hosts it, `ansible/inventory/group_vars/site_<env>/apps.yml`: `host_group`, `image`, `port`, and a `proxy:` block for DNS/reverse-proxy (image keys end in `image`, double-quoted, `# renovate: datasource=docker` directly above; no separate `images:` list — the pre-pull list is derived). For a browser UI on the site domain, add `auth: true` to the `proxy:` block to put it behind the login
2. Create the compose template: `ansible/playbooks/apps/<service>/templates/compose.yaml.j2` referencing `apps[app_name].<field>`
3. Add host group to `ansible/inventory/hosts.ini` under `[app_<service>]` and `[apps:children]`, and the host under its `[site_<env>]` group
4. Add import to `ansible/playbooks/site.yml` (uses `deploy-app.yml` with `app_name`)
5. Deploy: `task ansible:deploy-app APP=<service> ENV=<env>`, then `task ansible:deploy-networking ENV=<env>` for the DNS/proxy entry
6. If new VM needed: add to `terraform/environments/<env>/vms.auto.tfvars`. Prometheus scrapes node-exporter on every host under `[site_<env>]` (`prometheus_node_targets` is derived from the inventory), so the next monitoring deploy picks the VM up

Non-catalog services (third-party devices, dedicated-playbook stacks) get manual proxy entries in `group_vars/site_<env>/proxy/<domain>.yml` instead of a `proxy:` block.
