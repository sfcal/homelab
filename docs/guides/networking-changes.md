# Networking Changes

Common DNS, proxy, and routing operations.

## Add a Service to DNS and Proxy

### Registry apps

For apps in the [app registry](../reference/config.md#app-registry), add a `proxy:` block to the app's entry in its site's registry, `ansible/inventory/group_vars/site_<env>/apps.yml`. Use a zone of that site: a site's networking reads only its own registry.

```yaml
# site_wil/apps.yml
myapp:
  host_group: app_myapp
  # renovate: datasource=docker
  image: "myimage:latest"
  port: 8080
  proxy:
    name: myapp
    domain: wil.5am.cloud
    proxied: true
```

Then redeploy networking:

```bash
task ansible:deploy-networking ENV=wil
```

`backend_host` and `backend_port` are derived automatically: the first inventory host of the app's `host_group`, and the app's `port` (override with `backend_port` inside the `proxy:` block).

### Non-catalog services

For services outside the registry (third-party devices, media stack, monitoring), add an entry to the domain's file in the proxy folder of the site that is primary for it, `ansible/inventory/group_vars/site_<env>/proxy/`:

```yaml
# wil.5am.cloud.yml
- name: myapp
  backend_host: 10.2.20.60
  backend_port: 8080
  proxied: true
```

Then redeploy networking as above.

Either path creates both a DNS A record (`myapp.wil.5am.cloud → Caddy`) and a Caddy reverse proxy entry.

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
| `auth` | no | `false` | Require an [Authelia](../infrastructure/networking/sso.md) login |

For registry-generated entries, `backend_host` and `backend_port` are derived — the `proxy:` block only supplies `name`, `domain`, `proxied`, and any optional fields.

## Add a New Domain

1. Create a domain file in the proxy folder of the site that will be primary for it, `ansible/inventory/group_vars/site_<env>/proxy/`:

    ```yaml
    # mydomain.com.yml
    mydomain_services:
      - name: app1
        backend_host: 10.2.20.60
        backend_port: 8080
        proxied: true
    ```

2. Add the domain to the site's `zones` in `group_vars/all/sites.yml`:

    ```yaml
    sites:
      wil:
        # ...
        zones: [5am.video, 5am.cloud, wil.5am.cloud, ext.5am.cloud, sfc.al, mydomain.com]
    ```

3. Add the list to the `services` aggregation in `group_vars/all/vars.yml`:

    ```yaml
    services: >-
      {{
        (
          ...
          (mydomain_services | default([]) | map('combine', {'domain': 'mydomain.com'}) | list) +
          registry_services
        ) | selectattr('domain', 'in', sites[site].zones) | list
      }}
    ```

4. Redeploy networking at every site, so the other sites pick up the new zone as secondaries: `task ansible:deploy-networking ENV=wil`, then `ENV=ldn`

## Add a PTR Record

PTR records (reverse DNS) are not generated from the `services` list — the reverse zone template (`reverse.zone.j2`) is rendered from the `dns_ptr_records` list in `group_vars/site_<env>/infra_networking/bind9.yml`. Add an entry there for any host that needs reverse DNS.

See [DNS — Reverse DNS](../infrastructure/networking/dns.md#reverse-dns-ptr-records) for details.

## Set Up Cross-Site Zone Transfer

Zone transfers between sites (e.g., WIL ↔ LDN) are derived from `group_vars/all/sites.yml`: every site's BIND9 is a secondary for the other sites' `zones`. To change them:

1. Edit the site's row in `group_vars/all/sites.yml` (`dns`, `ts_router_ips`, `zones`)
2. Redeploy networking at every site
3. Ensure Tailscale connectivity between sites

See [DNS — Cross-Site Zone Transfers](../infrastructure/networking/dns.md#cross-site-zone-transfers) for the full configuration.

## Troubleshooting

**DNS not resolving after change** — Redeploy networking: `task ansible:deploy-networking ENV=wil`. Check BIND9 logs: `ssh <networking-ip> docker logs bind9`.

**Certificate not issued** — Caddy uses DNS-01 via Cloudflare. Verify the Cloudflare API token is valid and the domain's nameservers point to Cloudflare. Check Caddy logs: `ssh <networking-ip> docker logs caddy`.

**Zone transfer failing** — Verify Tailscale connectivity between sites. Check that `allow-transfer` includes the remote site's DNS server IP. Test with `dig AXFR <zone> @<primary-dns>`.
