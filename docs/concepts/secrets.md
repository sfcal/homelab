# Secrets Management

<!-- TODO: expand with workflow examples -->

How sensitive configuration is encrypted and managed.

## Overview

The homelab uses **SOPS** with **Age** encryption to store secrets alongside code. Encrypted files are committed to Git and decrypted at deploy time by Ansible.

## Encrypted File Patterns

| Pattern | Purpose |
|---------|---------|
| `**/secrets.sops.yml` | Ansible group variable secrets |
| `terraform/**/*.tfvars` | Terraform variable files |
| `packer/**/*.pkrvars.hcl` | Packer variable files |
| `docker/**/.env` | Docker environment files |

## Workflow

1. Edit secrets with `sops <file>` (decrypts in-editor, re-encrypts on save)
2. Commit the encrypted file to Git
3. Ansible decrypts at deploy time using the `community.sops` collection
