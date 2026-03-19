# Secrets Management

How sensitive configuration is encrypted and managed with SOPS and Age.

## Overview

Secrets are encrypted at rest with **SOPS** using **Age** encryption and committed to Git alongside code. Ansible decrypts them at deploy time via the `community.sops` collection.

```bash
# Edit a secrets file (decrypts in-editor, re-encrypts on save)
sops ansible/environments/wil/group_vars/all/secrets.sops.yml

# Decrypt to stdout
sops decrypt ansible/environments/wil/group_vars/all/secrets.sops.yml

# Encrypt a new file
sops encrypt --in-place myfile.yml
```

## Age Key

The Age private key lives at `~/.config/sops/age/keys.txt`. This key must be present on any machine that needs to decrypt secrets.

```bash
# Generate a new key
age-keygen -o ~/.config/sops/age/keys.txt

# View the public key
age-keygen -y ~/.config/sops/age/keys.txt
```

The public key is configured in `.sops.yaml` at the repository root.

## Encrypted File Patterns

SOPS determines which files to encrypt and how based on creation rules in `.sops.yaml`:

| Pattern | Encryption | Purpose |
|---------|-----------|---------|
| `terraform/**/*.tfvars` | Full file | Proxmox credentials, SSH keys |
| `packer/**/*.pkrvars.hcl` | Full file | Proxmox API tokens |
| `(docker\|ansible)/**/*.sops.yml` | Full file | Ansible secrets, Docker configs |
| `(docker\|ansible)/**/*.env` | Full file | Docker environment files |
| `(docker\|ansible)/**/cf-token` | Full file | Cloudflare API tokens |

!!! tip
    Decrypted temporary files match the pattern `**/.decrypted~*` and are gitignored. Never commit decrypted secrets.

## Workflow

### Adding a New Secret

1. Create the file following the naming convention (e.g., `secrets.sops.yml`)
2. SOPS auto-detects the creation rule from `.sops.yaml` and encrypts with the correct key
3. Commit the encrypted file

```bash
# Create and encrypt a new secrets file
sops ansible/environments/wil/group_vars/app_myservice/secrets.sops.yml
```

### Using Secrets in Ansible

Ansible automatically decrypts `*.sops.yml` files in `group_vars/` via the `community.sops` collection. Reference variables normally:

```yaml
# In a playbook or template
{{ my_secret_variable }}
```

### Rotating the Age Key

1. Generate a new Age key
2. Update the public key in `.sops.yaml`
3. Re-encrypt all files: `sops updatekeys <file>` for each encrypted file

## Troubleshooting

**"no matching keys found"** — The Age private key at `~/.config/sops/age/keys.txt` doesn't match the public key in `.sops.yaml`. Verify with `age-keygen -y` and compare.

**File not encrypting** — Check that the file path matches a creation rule in `.sops.yaml`. Run `sops encrypt` explicitly to see the error.

**Ansible can't decrypt** — Ensure the Age key is present on the machine running Ansible and that `community.sops` is installed.
