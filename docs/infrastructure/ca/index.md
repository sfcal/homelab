# Certificate Authority (Step-CA)

Step-CA provides a private certificate authority for issuing internal TLS certificates. It runs as a Docker container on a dedicated VM in each environment, enabling services to communicate over HTTPS without relying on public CAs.

!!! note "Deployment order"
    Step-CA deploys after [Networking](../networking/index.md) and before NTP, monitoring, and applications.

## Architecture

```mermaid
graph TD
    Root[5am Root CA<br/>key on the YubiKey]
    WIL[WIL intermediate<br/>wil.5am.cloud, 10.2.0.0/16]
    LDN[LDN intermediate<br/>ldn.5am.cloud, 10.3.0.0/16]
    Service1[Services at wil]
    Service2[Services at ldn]

    Root -->|signs| WIL
    Root -->|signs| LDN
    WIL -->|issues certs| Service1
    LDN -->|issues certs| Service2
```

There is one root for both sites. Its key was generated on a YubiKey (PIV slot 9c) and cannot be copied off it; every signature needs the PIN and a touch. There is no backup: if the YubiKey is lost, the intermediates keep working until they expire, but a new root has to be made and trusted everywhere.

Each site's Step-CA holds an intermediate signed by that root. The intermediate carries name constraints, so it can only issue for its own site's domain (`<site>.5am.cloud` and anything under it), its LAN range and `127.0.0.1`. Step-CA refuses other names, and clients reject such a certificate even if one were made with a stolen intermediate key. Services request certificates via the ACME protocol or the `step` CLI. Devices only need to trust the one root, `ansible/playbooks/infrastructure/ca/files/root_ca.crt`.

### Root and intermediates

Needs `ykman`, `step` and the `step-kms-plugin` on the machine with the YubiKey.

```bash
# Once, ever: change the PIN and PUK, then make the root on the YubiKey
ykman piv access change-pin
ykman piv access change-puk
task ca:root-init

# Per site, and again before an intermediate expires (5 years)
task ca:sign-intermediate ENV=wil
task ansible:deploy-ca ENV=wil
```

`ca:sign-intermediate` makes a new intermediate key on the site's CA (it never leaves the VM), signs it on the YubiKey and saves the certificate as `files/intermediate_ca_<site>.crt`. The deploy installs the root and the intermediate, switches to the new key only if it matches the certificate, deletes the key of the root Step-CA made for itself on first start, and restarts the CA. A site with no signed intermediate in `files/` keeps Step-CA's self-made chain.

## File Locations

| File | Purpose |
|------|---------|
| `playbooks/infrastructure/ca/deploy.yml` | Main playbook |
| `playbooks/infrastructure/ca/tasks/step-ca.yml` | Installation and configuration task |
| `playbooks/infrastructure/ca/templates/compose.yaml.j2` | Docker Compose service definition |
| `playbooks/infrastructure/ca/handlers/main.yml` | Container lifecycle handlers |
| `playbooks/infrastructure/ca/files/root_ca.crt` | The root certificate (public) |
| `playbooks/infrastructure/ca/files/intermediate_ca_<site>.crt` | Each site's intermediate certificate (public) |
| `playbooks/infrastructure/ca/files/intermediate.tpl` | Template for intermediates (name constraints) |
| `inventory/group_vars/site_<env>/infra_ca/vars.yml` | Per-environment CA variables |
| `inventory/group_vars/site_<env>/secrets.sops.yml` | Encrypted provisioner password (section `infra_ca`) |

## Hosts

| Environment | IP | FQDN |
|-------------|----|------|
| WIL | `10.2.20.9` | `ca.wil.5am.cloud` |
| LDN | `10.3.20.9` | `ca.ldn.5am.cloud` |

## Deployment

```bash
task ansible:deploy-ca ENV=wil
```

The task file performs these steps in order:

1. Creates `/opt/step-ca/` (compose, password file) and `/var/lib/step-ca/data/` (CA state)
2. Deploys the provisioner password file (mode `0600`)
3. Deploys `compose.yaml` from template
4. Starts the Step-CA container
5. Waits 10 seconds for initialization
6. Runs a health check against `https://127.0.0.1:9000/health`
7. Configures certificate duration claims in `ca.json` via `jq`
8. Exports the root CA certificate to `/opt/step-ca/root_ca.crt`
9. Displays status output

<small>**Source:** [`ansible/playbooks/infrastructure/ca/tasks/step-ca.yml`](https://github.com/sfcal/homelab/blob/main/ansible/playbooks/infrastructure/ca/tasks/step-ca.yml)</small>

## Docker Compose

The container runs `smallstep/step-ca` with the following configuration:

- **Port:** `9000` (HTTPS API)
- **Volumes:** `./data` for CA state, `./password.txt` mounted read-only
- **Restart policy:** `unless-stopped`
- **Initialization:** handled via `DOCKER_STEPCA_INIT_*` environment variables on first run

<small>**Source:** [`ansible/playbooks/infrastructure/ca/templates/compose.yaml.j2`](https://github.com/sfcal/homelab/blob/main/ansible/playbooks/infrastructure/ca/templates/compose.yaml.j2)</small>

## Configuration Reference

All variables are set in `ansible/inventory/group_vars/site_<env>/infra_ca/vars.yml`.

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `step_ca_image` | `string` | Docker image for Step-CA | (per-env) |
| `step_ca_port` | `integer` | HTTPS API listen port | `9000` |
| `step_ca_name` | `string` | CA display name, appears in issued certificates | (per-env) |
| `step_ca_dns_names` | `string` | Comma-separated DNS names and IPs for the CA's TLS cert | (per-env) |
| `step_ca_provisioner_name` | `string` | Admin provisioner name | `"admin"` |
| `step_ca_init_ssh` | `string` | Initialize SSH certificate support | `"false"` |
| `step_ca_uid` | `string` | Container file ownership UID | `"1000"` |
| `step_ca_gid` | `string` | Container file ownership GID | `"1000"` |
| `step_ca_default_cert_duration` | `string` | Default certificate validity period | `"720h"` |
| `step_ca_max_cert_duration` | `string` | Maximum certificate validity period | `"17520h"` |
| `step_ca_provisioner_password` | `string` | Admin provisioner password (SOPS-encrypted) | (required) |

<small>**Sources:** `ansible/inventory/group_vars/site_<env>/infra_ca/vars.yml` · `ansible/inventory/group_vars/site_<env>/secrets.sops.yml`</small>

## Common Tasks

### Verify CA health

```bash
task ca:health ENV=wil
```

Or manually:

```bash
curl -k https://ca.wil.5am.cloud:9000/health
```

### Export the root CA certificate

The root certificate is automatically exported during deployment to `/opt/step-ca/root_ca.crt`. To retrieve it:

```bash
ssh sfcal@10.2.20.9 cat /opt/step-ca/root_ca.crt
```

### Change certificate duration

1. Edit `ansible/inventory/group_vars/site_<env>/infra_ca/vars.yml`:

    ```yaml
    step_ca_default_cert_duration: "2160h"   # 90 days
    step_ca_max_cert_duration: "17520h"      # 2 years
    ```

2. Deploy:

    ```bash
    task ansible:deploy-ca ENV=wil
    ```

The task applies duration changes to `ca.json` via `jq` on each run.

### Restart the CA

The playbook handlers support lifecycle management:

```bash
# Full redeploy (will restart automatically if config changes)
task ansible:deploy-ca ENV=wil
```
