# Config Reference

Consolidated reference for configuration formats used across the homelab.

## Service Definitions

Service definitions drive both DNS records and reverse proxy entries. They come from two sources:

1. **App registry** — apps in the site's registry `group_vars/site_<env>/apps.yml` declare a `proxy:` block; `registry_services` (in `group_vars/all/vars.yml`) gets an entry for each one (see [App Registry](#app-registry))
2. **Manual per-domain files** — for services outside the catalog (third-party devices, media stack, monitoring, Frigate, cloud gaming), each domain has its own file in the proxy folder of the site that is primary for it, `ansible/inventory/group_vars/site_<env>/proxy/`:

```
site_wil/proxy/
├── 5am.video.yml          # video_services
├── 5am.cloud.yml          # cloud_services
└── wil.5am.cloud.yml      # wil_services
site_ldn/proxy/
└── ldn.5am.cloud.yml      # ldn_services
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
| `auth` | no | `false` | Require a [Kanidm](../infrastructure/networking/sso.md) login |

For registry-generated entries, `backend_host` is derived (first inventory host of the app's `host_group`) and `backend_port` defaults to the app's `port` — the `proxy:` block supplies `name`, `domain`, `proxied`, and any optional fields.

### Service Aggregation

`services` in `group_vars/all/vars.yml` combines the site's manual domain lists (injecting the domain name), appends the registry-generated entries, and keeps only the zones of the host's site:

```yaml
services: >-
  {{
    (
      (video_services | default([]) | map('combine', {'domain': '5am.video'}) | list) +
      (cloud_services | default([]) | map('combine', {'domain': '5am.cloud'}) | list) +
      (wil_services | default([]) | map('combine', {'domain': 'wil.5am.cloud'}) | list) +
      (ext_services | default([]) | map('combine', {'domain': 'ext.5am.cloud'}) | list) +
      (sfc_services | default([]) | map('combine', {'domain': 'sfc.al'}) | list) +
      (ldn_services | default([]) | map('combine', {'domain': 'ldn.5am.cloud'}) | list) +
      registry_services
    ) | selectattr('domain', 'in', sites[site].zones) | list
  }}
```

Both BIND9 and Caddy templates consume the unified `services` list.

## VM Definitions

VMs are defined in HCL maps in `terraform/environments/<env>/vms.auto.tfvars`. See [Terraform — VM Module Variables](terraform.md#vm-module-variables) for the full field reference.

## App Registry

Data-driven apps are defined in the registry of the site that hosts them, `ansible/inventory/group_vars/site_<env>/apps.yml` — the service catalog for images, ports, and proxy/DNS metadata:

```yaml
apps:
  myapp:
    host_group: app_myapp      # Ansible inventory group
    # renovate: datasource=docker
    image: "myimage:latest"     # Primary container image
    port: 8080                  # Exposed port; default proxy backend_port
    proxy:                      # Optional — omit for no DNS/proxy entry
      name: myapp               # Subdomain
      domain: wil.5am.cloud
      proxied: true             # Required (no default in zone template)
      # Optional: tls_skip_verify, forward_headers, host_header, encode,
      #           read_buffer, auth, dns, enabled, backend_port (overrides port)
    # Optional:
    # nfs: true                 # Mount NFS shares
    # user: "1000"              # Service user
    # group: "1000"             # Service group
```

### Image Keys

There is no `images:` list — `deploy-app.yml` derives the pre-pull list from every key ending in `image` (top level and one nesting level down). Renovate updates these automatically, so image keys must follow these rules:

- `# renovate: datasource=docker` comment directly above the image key
- Key ends in `image` (e.g., `image`, `db_image`, `redis_image`) with no hyphens in the key
- Value is double-quoted

### Multi-Service Apps

Apps that run several containers nest sub-services one level deep, each with its own image, port, and `proxy:` block (sub-keys must be hyphen-free):

```yaml
apps:
  work:
    host_group: app_work
    microbin:
      # renovate: datasource=docker
      image: "danielszabo99/microbin:latest"
      port: 8081
      proxy:
        name: bin
        domain: ldn.5am.cloud
        proxied: true
    another_svc:
      # ...
```

Compose templates read these via `apps.work.<svc>.*`.

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
| `app_*` | Applications | `app_mediastack`, `app_kosync` |
| `site_*` | Sites; every host is in one | `site_wil`, `site_ldn` |

Parent groups: `[infrastructure:children]` and `[apps:children]` aggregate all groups of each type.

## Global Variables

Defined in `ansible/inventory/group_vars/all/vars.yml`, filled in from the site's row in `all/sites.yml` (see [Environments](../concepts/environments.md)):

```yaml
domains: "{{ sites[site].zones | map('community.general.dict_kv', 'name') | list }}"
system_timezone: "{{ sites[site].tz }}"
```

### Filesystem Layout

Hosts follow the Filesystem Hierarchy Standard. The paths are hard-coded in
the playbooks and templates; each stack is a *project* (`work`, `monitoring`,
`media-stack`, ...):

| Path | Holds |
|------|-------|
| `/opt/<project>/` | `compose.yaml`, Dockerfiles, config rendered by Ansible |
| `/var/lib/<project>/<service>/` | State the containers write: databases, caches, uploads |
| `/var/log/<project>/` | Log files mounted out of containers |
| `/srv/<project>/` | Files served to clients: netboot images, the ROM library |

Stacks with their own playbook define `<stack>_deploy_path` / `<stack>_data_path`
in their group_vars so the tasks and templates share one definition.
