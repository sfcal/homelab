# Networking Changes

Common DNS, proxy, and routing operations.

## Add a Service to DNS and Proxy

Add an entry to the appropriate domain file in `ansible/environments/<env>/group_vars/all/proxy/`:

```yaml
# wil.5am.cloud.yml
- name: myapp
  backend_host: 10.2.20.60
  backend_port: 8080
  proxied: true
```

Then redeploy networking:

```bash
task ansible:deploy-networking ENV=wil
```

This creates both a DNS A record (`myapp.wil.5am.cloud → Caddy`) and a Caddy reverse proxy entry.

!!! tip
    Set `proxied: false` if the service handles its own TLS or doesn't need a reverse proxy. The DNS record will point directly to `backend_host`.

## Service Definition Options

| Field | Required | Default | Description |
|-------|----------|---------|-------------|
| `name` | yes | — | Subdomain (e.g., `myapp` → `myapp.wil.5am.cloud`) |
| `backend_host` | yes | — | Backend IP address |
| `backend_port` | yes | — | Backend port |
| `proxied` | yes | — | `true` for Caddy proxy, `false` for direct DNS |
| `enabled` | no | `true` | Set `false` to disable both DNS and proxy |
| `dns` | no | — | Set `external` to skip internal A record |
| `tls_skip_verify` | no | `false` | Backend uses self-signed HTTPS |
| `forward_headers` | no | `false` | Adds `X-Real-IP`, `X-Forwarded-For` |
| `host_header` | no | — | Overrides `Host` header to upstream |
| `encode` | no | — | Response encoding (e.g., `gzip`) |
| `read_buffer` | no | — | Read buffer size |

## Add a New Domain

1. Create a domain file in `ansible/environments/<env>/group_vars/all/proxy/`:

    ```yaml
    # mydomain.com.yml
    mydomain_services:
      - name: app1
        backend_host: 10.2.20.60
        backend_port: 8080
        proxied: true
    ```

2. Add the domain to `group_vars/all/vars.yml`:

    ```yaml
    domains:
      - 5am.video
      - 5am.cloud
      # ... existing domains ...
      - mydomain.com
    ```

3. Add the list to `_services.yml` aggregation:

    ```yaml
    services: >-
      {{
        ...
        (mydomain_services | default([]) | map('combine', {'domain': 'mydomain.com'}) | list)
      }}
    ```

4. Redeploy networking: `task ansible:deploy-networking ENV=wil`

## Add a PTR Record

PTR records (reverse DNS) are generated automatically from the service definitions for non-proxied services. For infrastructure hosts, PTR records are defined in the BIND9 reverse zone template.

See [DNS — Reverse DNS](../infrastructure/networking/dns.md#reverse-dns-ptr-records) for details.

## Set Up Cross-Site Zone Transfer

To replicate DNS zones between sites (e.g., WIL ↔ LDN):

1. Configure BIND9 on the primary site as zone master with `allow-transfer`
2. Configure BIND9 on the secondary site as a slave zone
3. Ensure Tailscale connectivity between sites

See [DNS — Cross-Site Zone Transfers](../infrastructure/networking/dns.md#cross-site-zone-transfers) for the full configuration.

## Troubleshooting

**DNS not resolving after change** — Redeploy networking: `task ansible:deploy-networking ENV=wil`. Check BIND9 logs: `ssh <networking-ip> docker logs bind9`.

**Certificate not issued** — Caddy uses DNS-01 via Cloudflare. Verify the Cloudflare API token is valid and the domain's nameservers point to Cloudflare. Check Caddy logs: `ssh <networking-ip> docker logs caddy`.

**Zone transfer failing** — Verify Tailscale connectivity between sites. Check that `allow-transfer` includes the remote site's DNS server IP. Test with `dig AXFR <zone> @<primary-dns>`.
