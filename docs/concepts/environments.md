# Environments

The homelab supports multiple deployment environments, each with isolated configuration and network ranges.

## Overview

| Environment | Purpose | Network Range | Proxmox Node |
|-------------|---------|---------------|--------------|
| **WIL** | Development / Primary | 10.2.20.0/24 | `proxmox` |
| **LDN** | Production (London) | 10.3.20.0/24 | `pve-lon` |
| **External** | VPS (Uptime Kuma) | N/A | N/A |

Every `task` command takes an `ENV=` variable that threads through to Terraform, Ansible, and Packer:

```bash
task ansible:deploy-all ENV=wil
task terraform:deploy ENV=ldn
task packer:build-ubuntu ENV=wil
```

## Directory Structure

Each environment has its own configuration under both Ansible and Terraform:

=== "Ansible"

    ```
    ansible/environments/
    ├── wil/
    │   ├── hosts.ini                    # Inventory
    │   └── group_vars/
    │       ├── all/
    │       │   ├── vars.yml             # Shared variables
    │       │   ├── apps.yml             # App registry
    │       │   ├── secrets.sops.yml     # Encrypted secrets
    │       │   └── proxy/               # Service definitions per domain
    │       ├── infra_networking/        # Networking-specific vars
    │       ├── infra_ca/               # CA-specific vars
    │       └── app_mediastack/         # Media stack vars
    ├── ldn/
    │   ├── hosts.ini
    │   └── group_vars/
    └── external/
        ├── hosts.ini
        └── group_vars/
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
    ├── ldn/
    └── nyc/
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
        │   └── credentials.wil.pkrvars.hcl  # Encrypted
        └── ldn/
    ```

## How `ENV=` Works

The root `Taskfile.yaml` defines `ENV` as a variable (defaults to `dev`). Each namespace's Taskfile uses it to resolve paths:

```yaml
# .taskfiles/ansible/Taskfile.yaml
vars:
  ENV_DIR: "environments/{{.ENV}}"
  HOSTS_FILE: "{{.ENV_DIR}}/hosts.ini"
```

```yaml
# .taskfiles/terraform/Taskfile.yaml
vars:
  ENV_DIR: "environments/{{.ENV}}"
```

This means the same task commands work across environments — just change `ENV=`:

```bash
task ansible:ping ENV=wil    # Pings WIL hosts
task ansible:ping ENV=ldn    # Pings LDN hosts
```

## Shared vs. Environment-Specific Config

**Shared across environments:**

- Ansible roles (`ansible/roles/`)
- Playbook definitions (`ansible/playbooks/`)
- Terraform modules (`terraform/modules/`)
- Packer templates (`packer/templates/`)

**Per-environment:**

- Inventory (`hosts.ini`)
- Group variables (`group_vars/`)
- VM definitions (`vms.auto.tfvars`)
- Secrets (`secrets.sops.yml`, `credentials.*.pkrvars.hcl`)
- Terraform state (`terraform.tfstate`)

## Troubleshooting

**Wrong environment deployed** — Double-check `ENV=` in your command. The default is `dev`, not `wil`. Run `task ansible:ping ENV=<env>` to verify you're targeting the right hosts.

**Missing environment directory** — Each new environment needs both `ansible/environments/<env>/` and `terraform/environments/<env>/` directories with the required files.

**Cross-site access** — WIL and LDN communicate over Tailscale. Ensure the subnet router VM is deployed and advertising routes. See [Tailscale](../infrastructure/networking/tailscale.md).
