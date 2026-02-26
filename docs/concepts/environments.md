# Multi-Environment

<!-- TODO: expand with configuration examples -->

How the homelab supports multiple deployment environments.

## Environments

| Name | Purpose | Description |
|------|---------|-------------|
| **WIL** | Development / Primary | Main homelab environment |
| **NYC** | Production | Remote production deployment |
| **External** | VPS | External monitoring (Uptime Kuma) |

## Directory Structure

Each environment has its own configuration under both Ansible and Terraform:

```
ansible/environments/
├── wil/
│   ├── hosts.ini
│   └── group_vars/
└── external/
    ├── hosts.ini
    └── group_vars/

terraform/environments/
├── wil/
└── nyc/
```

## How It Works

- **Ansible** uses inventory files (`hosts.ini`) and group variables per environment
- **Terraform** uses separate `terraform.tfvars` per environment
- **Packer** uses environment-specific variable files
- Shared configuration lives in `group_vars/all/`
