# Environments

The homelab supports multiple deployment environments, each with isolated configuration and network ranges.

## Overview

| Environment | Purpose | Network Range | Proxmox Node |
|-------------|---------|---------------|--------------|
| **WIL** | Development / Primary | 10.2.20.0/24 | `proxmox` |
| **LDN** | Production (London) | 10.3.20.0/24 | `pve-lon` |
| **OVH** | Dashboard VPS (Virginia), outside the lab | none; tailnet name `dashboard` | — |

Every `task` command takes an `ENV=` variable that threads through to Terraform, Ansible, and Packer:

```bash
task ansible:deploy-all ENV=wil
task terraform:deploy ENV=ldn
task packer:build-ubuntu ENV=wil
```

## Directory Structure

Terraform and Packer have a directory per environment. Ansible has one inventory for both sites:

=== "Ansible"

    ```
    ansible/inventory/
    ├── hosts.ini                        # Inventory (both sites)
    └── group_vars/
        ├── all/                         # Every host
        │   ├── sites.yml                # One row per site
        │   └── vars.yml                 # Shared variables, services list
        ├── site_wil/                    # wil's own values and secrets
        │   ├── vars.yml                 # site: wil
        │   ├── secrets.sops.yml         # Encrypted secrets
        │   ├── apps.yml                 # wil's app registry
        │   ├── proxy/                   # wil's DNS/proxy entries per domain
        │   ├── infra_networking/        # Networking-specific vars
        │   ├── infra_ca/                # CA-specific vars
        │   └── app_mediastack/          # Media stack vars (wil only)
        └── site_ldn/
    ```

=== "Terraform"

    ```
    terraform/environments/
    ├── wil/
    │   ├── main.tf                      # Calls VM module
    │   ├── variables.tf                 # Variable definitions
    │   ├── providers.tf                 # Proxmox provider
    │   ├── vms.auto.tfvars              # VM definitions
    │   └── terraform.tfstate            # State file
    └── ldn/
    ```

=== "Packer"

    ```
    packer/
    ├── templates/
    │   ├── ubuntu-server-base.pkr.hcl   # Ubuntu template
    │   └── debian-bookworm-base.pkr.hcl # Debian template
    └── environments/
        ├── wil/
        │   ├── ubuntu-variables.pkrvars.hcl
        │   └── credentials.wil.pkrvars.hcl.sops  # Encrypted
        └── ldn/
    ```

Every host in `hosts.ini` is listed in its site group (`[site_wil]`, `[site_ldn]`) and in the role groups the playbooks target, so `[infra_networking]` lists both `.53` VMs. Group variables come from two kinds of folders:

- `all/` — every host. `sites.yml` has one row per site; `domains`, `system_timezone` and the cross-site BIND9 settings (trusted networks, secondary zones, zone transfers, notifies) are derived from it. `vars.yml` also combines the site's DNS/proxy lists into `services`.
- `site_<site>/` — that site's own values: its app registry (`apps.yml`), its DNS/proxy entries (`proxy/<domain>.yml`), sub-folders named after the group that reads them (they apply to every host of the site), and all of the site's secrets. Groups that run at one site only (`app_mediastack`, `app_frigate`, `infra_ntp` at wil; `app_hermes`, `infra_proxmox` at ldn; `infra_dashboard`, `app_kasm_agent` at ovh) have their folder there too.

```yaml
# ansible/inventory/group_vars/all/sites.yml
sites:
  wil:
    cidr: 10.2.0.0/16                   # LAN range
    tz: America/New_York                # Timezone of the site's hosts
    dns: ["10.2.20.53"]                 # BIND9 primary (networking VM)
    ts_router_ips: ["100.103.137.102"]  # Tailnet IP of the subnet router
    zones: [5am.video, 5am.cloud, wil.5am.cloud, ext.5am.cloud, sfc.al]  # Zones it is primary for
  ldn:
    # ...
  ovh:                                  # Dashboard VPS: no LAN or DNS, so no cidr
    tz: America/New_York
    dns: []
    ts_router_ips: []
    zones: []
```

To add a site, or move a site's DNS server or zones, edit its row, then deploy networking at every site. A site without DNS (ovh) changes nothing at the others.

## How `ENV=` Works

`ENV` names the site and has no default: a task that reads it stops with "Pass ENV=<site>" when it is missing. Terraform and Packer use it to resolve paths; Ansible uses it to limit the run to the site's group:

```yaml
# .taskfiles/ansible/Taskfile.yaml
vars:
  HOSTS_FILE: 'inventory/hosts.ini'
  LIMIT: 'site_{{.ENV}}'
```

```yaml
# .taskfiles/terraform/Taskfile.yaml
vars:
  ENV_DIR: "environments/{{.ENV}}"
```

So `task ansible:deploy-networking ENV=wil` runs `ansible-playbook -i inventory/hosts.ini --limit site_wil ...`. Running `ansible-playbook` by hand without `--limit` hits both sites and needs both sites' secrets, which is fine with the master key.

This means the same task commands work across environments — just change `ENV=`:

```bash
task ansible:ping ENV=wil    # Pings WIL hosts
task ansible:ping ENV=ldn    # Pings LDN hosts
```

## Shared vs. Environment-Specific Config

**Shared across environments:**

- Ansible roles (`ansible/roles/`)
- Playbook definitions (`ansible/playbooks/`)
- Inventory (`hosts.ini`) and `group_vars/all/` (sites table, derived variables)
- Terraform modules (`terraform/modules/`)
- Packer templates (`packer/templates/`)

**Per-environment:**

- Group variables (`group_vars/site_<env>/`, including the app registry and proxy lists)
- VM definitions (`vms.auto.tfvars`)
- Secrets (`secrets.sops.yml`, `terraform.tfvars.sops`, `credentials.*.pkrvars.hcl.sops`)
- Terraform state (`terraform.tfstate`)

## Troubleshooting

**Wrong environment deployed** — Double-check `ENV=` in your command (there is no default). Run `task ansible:ping ENV=<env>` to verify you're targeting the right hosts.

**Missing environment directory** — Each new environment needs a `[site_<env>]` group in `ansible/inventory/hosts.ini`, a row in `group_vars/all/sites.yml`, a `group_vars/site_<env>/` folder (with `site: <env>` in its `vars.yml`, and an `apps.yml`, at least `apps: {}`, which the Taskfile passes to `deploy-app` and `deploy-all`), and a `terraform/environments/<env>/` directory with the required files.

**Cross-site access** — WIL and LDN communicate over Tailscale. Ensure the subnet router VM is deployed and advertising routes. See [Tailscale](../infrastructure/networking/tailscale.md).
