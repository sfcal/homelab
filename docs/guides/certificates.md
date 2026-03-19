# Certificates

The homelab uses two certificate systems: Caddy for public wildcard TLS and Step-CA for private internal certificates.

## Public TLS (Caddy)

Caddy automatically obtains wildcard certificates for all configured domains using Cloudflare DNS-01 challenges. No manual intervention required.

Any service with `proxied: true` in its [service definition](networking-changes.md#service-definition-options) gets automatic HTTPS.

```yaml
- name: myapp
  backend_host: 10.2.20.60
  backend_port: 8080
  proxied: true  # Automatic TLS via Caddy
```

Caddy handles certificate issuance, renewal, and OCSP stapling automatically.

## Private CA (Step-CA)

[Step-CA](../infrastructure/ca/index.md) provides a private certificate authority for internal services that need TLS but aren't behind Caddy.

### Check CA Health

```bash
task ca:health ENV=wil
```

### Fetch the Root Certificate

```bash
task ca:root ENV=wil
```

### Sign a Certificate

```bash
task ca:sign ENV=wil CSR=path/to/request.csr
```

Optionally set a custom duration (default: 8760h / 1 year):

```bash
task ca:sign ENV=wil CSR=path/to/request.csr DURATION=2160h
```

The `ca:sign` task uploads the CSR to the CA host, signs it with Step-CA, and downloads the signed certificate.

## When to Use Which

| Scenario | System | Why |
|----------|--------|-----|
| Web app behind Caddy | Caddy (automatic) | Wildcard cert covers all subdomains |
| Service with self-signed TLS | Step-CA | Replace self-signed with trusted internal cert |
| Inter-service mTLS | Step-CA | Issue client and server certificates |
| Backend that Caddy proxies over HTTPS | Caddy + `tls_skip_verify` | Or replace backend cert with Step-CA |

## Troubleshooting

**Caddy certificate not renewing** — Check Caddy logs: `ssh <networking-ip> docker logs caddy`. Common cause: Cloudflare API token expired or rate-limited by Let's Encrypt. Verify the token in the encrypted secrets file.

**Browser shows "not secure" for internal service** — The service isn't behind Caddy, or you haven't trusted the Step-CA root certificate. Install the root cert on your device: `task ca:root ENV=wil`.

**Step-CA health check failing** — SSH to the CA host and check the container: `docker ps`, `docker logs step-ca`. Common cause: the CA container restarted and needs its password file.
