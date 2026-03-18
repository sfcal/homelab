# Reverse Proxy (Caddy)

Caddy serves as the reverse proxy for all web-facing services. It runs as a Docker container with a custom-built image that includes the Cloudflare DNS plugin for automatic wildcard TLS certificates.

!!! tip
    For an overview of the full networking stack, see [Networking](index.md).

## File Locations

| File | Purpose |
|------|---------|
| `playbooks/infrastructure/networking/tasks/caddy.yml` | Installation and configuration task |
| `playbooks/infrastructure/networking/templates/Caddyfile.j2` | Reverse proxy configuration |
| `playbooks/infrastructure/networking/templates/compose.yaml.j2` | Docker Compose service definition |
| `playbooks/infrastructure/networking/templates/Dockerfile.j2` | Custom xcaddy build with Cloudflare plugin |
| `environments/<env>/group_vars/all/proxy/*.yml` | Per-domain service definitions |
| `environments/<env>/group_vars/all/proxy/_services.yml` | Service aggregation |

## Architecture

The Caddyfile is generated from the unified `services` list. For each domain, a wildcard server block (`*.domain.tld`) is created with:

1. **TLS configuration** — Cloudflare DNS-01 ACME challenge for wildcard certificates
2. **Per-service matchers** — named host matchers (`@servicename`) route requests to the correct backend
3. **Reverse proxy directives** — each service gets a `handle` block with optional headers, encoding, and transport configuration

Only services with `proxied: true` and `enabled: true` (default) generate Caddy entries.

```
*.5am.video {
    tls { dns cloudflare ... }

    @plex host plex.5am.video
    handle @plex {
        reverse_proxy 10.2.0.5:32400
    }

    @sonarr host sonarr.5am.video
    handle @sonarr {
        reverse_proxy 10.2.0.5:8989
    }
}
```

## TLS Certificate Management

Caddy obtains wildcard certificates for each domain using the Cloudflare DNS-01 ACME challenge. This means:

- No ports need to be publicly open for certificate validation
- One wildcard cert covers all subdomains per domain (e.g., `*.5am.video`)
- Certificates auto-renew before expiry

External traffic reaches Caddy via [port forwarding on the UDM Pro](unifi.md#port-forwarding) (ports 80 and 443).

The custom Docker image is built with `xcaddy` to include the `caddy-dns/cloudflare` plugin. Two environment variables authenticate with Cloudflare:

| Variable | Source | Purpose |
|----------|--------|---------|
| `CF_API_TOKEN` | SOPS-encrypted secrets | Cloudflare API token with DNS edit permissions |
| `CF_EMAIL` | SOPS-encrypted secrets | Cloudflare account email |

The Caddy container exposes ports `80`, `443`, and `2019` (admin API), and mounts persistent volumes for certificate storage.

## Service Definition Reference

Services are defined in per-domain YAML files under `ansible/environments/<env>/group_vars/all/proxy/`. Each file defines a list variable (e.g., `wil_services`, `video_services`) that is aggregated by `_services.yml`.

### Required Fields

---

#### `name`

Subdomain name. Combined with the domain to form the FQDN (e.g., `plex` becomes `plex.5am.video`).

**Type:** `string`

```yaml
name: plex
```

---

#### `backend_host`

IP address of the backend service.

**Type:** `string`

```yaml
backend_host: 10.2.0.5
```

---

#### `backend_port`

Port number of the backend service.

**Type:** `integer`

```yaml
backend_port: 32400
```

---

#### `proxied`

Controls both DNS resolution and Caddy proxy behavior:

- `true` — DNS resolves to `reverse_proxy_ip`, Caddy reverse proxies to the backend
- `false` — DNS resolves directly to `backend_host`, no Caddy entry generated

**Type:** `boolean`

```yaml
proxied: true
```

### Optional Fields

---

#### `enabled`

Set to `false` to disable both the DNS record and Caddy entry for this service. Useful for temporarily taking a service offline without removing its definition.

**Type:** `boolean`

**Default:** `true`

```yaml
enabled: false
```

---

#### `dns`

Controls DNS A record generation. Set to `"external"` to skip internal A record creation — useful for services that only need Cloudflare DNS records.

**Type:** `string`

**Default:** `"internal"`

```yaml
dns: external
```

---

#### `tls_skip_verify`

Skip TLS certificate verification when proxying to the backend. Use when the backend serves HTTPS with a self-signed certificate (e.g., Proxmox, Kasm).

**Type:** `boolean`

**Default:** `false`

```yaml
tls_skip_verify: true
```

---

#### `forward_headers`

Add `X-Real-IP`, `X-Forwarded-For`, and `X-Forwarded-Proto` headers to proxied requests. Enable when the backend needs the client's real IP address.

**Type:** `boolean`

**Default:** `false`

```yaml
forward_headers: true
```

---

#### `host_header`

Set to `"upstream"` to override the `Host` header with the upstream host and port. Required by services that validate the Host header (e.g., Plex).

**Type:** `string`

**Default:** not set

```yaml
host_header: upstream
```

---

#### `encode`

Enable response encoding. Reduces bandwidth for content-heavy services.

**Type:** `string`

**Default:** not set

```yaml
encode: gzip
```

---

#### `read_buffer`

Transport read buffer size in bytes. Increase for services with large response headers or streaming payloads.

**Type:** `integer`

**Default:** not set

```yaml
read_buffer: 8192
```

## Service Configuration Examples

### Minimal service

A basic proxied web application:

```yaml
- name: tools
  backend_host: 10.2.20.60
  backend_port: 8070
  proxied: true
```

### Media service with headers and encoding

Plex requires header forwarding, host header override, gzip encoding, and an increased read buffer:

```yaml
- name: plex
  backend_host: 10.2.0.5
  backend_port: 32400
  proxied: true
  encode: gzip
  forward_headers: true
  host_header: upstream
  read_buffer: 8192
```

### Self-signed backend

Proxmox serves HTTPS with a self-signed certificate:

```yaml
- name: vm
  backend_host: 10.2.20.7
  backend_port: 8006
  proxied: true
  tls_skip_verify: true
```

### DNS-only (non-proxied) service

A service that gets a DNS record pointing directly to its IP, with no Caddy proxy:

```yaml
- name: hmg
  backend_host: 10.2.20.186
  backend_port: 443
  proxied: false
```

## Service Aggregation

The `_services.yml` file in each environment aggregates all per-domain service lists and injects the `domain` field:

=== "WIL"

    ```yaml
    services: >-
      {{
        (video_services | default([]) | map('combine', {'domain': '5am.video'}) | list) +
        (cloud_services | default([]) | map('combine', {'domain': '5am.cloud'}) | list) +
        (wil_services | default([]) | map('combine', {'domain': 'wil.5am.cloud'}) | list) +
        (ext_services | default([]) | map('combine', {'domain': 'ext.5am.cloud'}) | list) +
        (sfc_services | default([]) | map('combine', {'domain': 'sfc.al'}) | list)
      }}
    ```

=== "LDN"

    ```yaml
    services: >-
      {{
        (ldn_services | default([]) | map('combine', {'domain': 'ldn.5am.cloud'}) | list)
      }}
    ```

Both BIND9 zone templates and the Caddyfile template consume the resulting `services` list.

## Best Practices

| Scenario | Configuration |
|----------|---------------|
| Modern web app with standard HTTP backend | `proxied: true` (no optional fields needed) |
| Backend with self-signed HTTPS (Proxmox, Kasm) | Add `tls_skip_verify: true` |
| Backend needs client IP (analytics, rate limiting) | Add `forward_headers: true` |
| Backend validates Host header (Plex) | Add `host_header: upstream` |
| Bandwidth-heavy streaming service | Add `encode: gzip` |
| Large response headers or websocket streams | Add `read_buffer: 8192` (or higher) |
| Service only accessible externally via Cloudflare | Add `dns: external` |
| Temporarily take a service offline | Set `enabled: false` |

## Common Tasks

### Add a new service to an existing domain

1. Open the domain file, e.g., `ansible/environments/wil/group_vars/all/proxy/wil.5am.cloud.yml`
2. Add a service entry:

    ```yaml
    - name: myapp
      backend_host: 10.2.20.60
      backend_port: 8080
      proxied: true
    ```

3. Deploy:

    ```bash
    task ansible:deploy-networking ENV=wil
    ```

4. Verify:

    ```bash
    # Check DNS
    dig myapp.wil.5am.cloud @10.2.20.53

    # Check HTTPS
    curl -I https://myapp.wil.5am.cloud
    ```

### Add a new domain

1. Add the domain to `ansible/environments/<env>/group_vars/all/vars.yml`:

    ```yaml
    domains:
      # ... existing domains
      - name: "new.5am.cloud"
    ```

2. Create a service file at `ansible/environments/<env>/group_vars/all/proxy/new.5am.cloud.yml`:

    ```yaml
    ---
    new_services:
      - name: app
        backend_host: 10.2.20.60
        backend_port: 8080
        proxied: true
    ```

3. Update `ansible/environments/<env>/group_vars/all/proxy/_services.yml` to include the new list:

    ```yaml
    services: >-
      {{
        ... +
        (new_services | default([]) | map('combine', {'domain': 'new.5am.cloud'}) | list)
      }}
    ```

4. Ensure the domain is registered with Cloudflare (required for TLS certificates)

5. Deploy:

    ```bash
    task ansible:deploy-networking ENV=wil
    ```

### Disable a service temporarily

Set `enabled: false` on the service entry. This removes both the DNS record and the Caddy proxy entry without deleting the configuration:

```yaml
- name: myapp
  backend_host: 10.2.20.60
  backend_port: 8080
  proxied: true
  enabled: false
```
