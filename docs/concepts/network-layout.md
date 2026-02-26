# Network Layout

<!-- TODO: expand with detailed network diagram -->

How DNS, routing, and domains are structured across the homelab.

## Domains

| Domain | Purpose |
|--------|---------|
| `5am.video` | Media services (Plex, *arr stack) |
| `wil.5am.cloud` | Internal infrastructure (monitoring, dashboard) |
| `ext.5am.cloud` | External-facing services |
| `sfc.al` | Personal projects (website, Birdle) |

## Split-Horizon DNS

The homelab uses BIND9 for internal DNS resolution:

- **Internal clients** resolve service domains to local IPs via BIND9
- **External clients** resolve via Cloudflare DNS to public IPs
- **DDNS** keeps dynamic records up to date

## Reverse Proxy

Caddy handles HTTPS termination and request routing for all services, with automatic certificate management.
