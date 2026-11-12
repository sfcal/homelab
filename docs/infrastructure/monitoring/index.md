# Monitoring

The monitoring stack provides metrics collection, visualization, alerts by email, a service dashboard, and external uptime monitoring. Prometheus runs as a Docker container on a dedicated VM in each environment; Grafana, Homepage and Uptime Kuma run once for both sites on an OVH VPS outside the lab (see [Grafana](#grafana) and [Homepage](#homepage)).

!!! note "Deployment order"
    Monitoring deploys after [Networking](../networking/index.md), [Step-CA](../ca/index.md), and [NTP](../ntp/index.md). It is the last infrastructure service to deploy before applications.

## Architecture

```mermaid
graph TD
    subgraph Monitoring VM
        Prometheus[Prometheus]
        Blackbox[blackbox-exporter]
    end

    subgraph Dashboard VPS
        Grafana[Grafana]
        Homepage[Homepage]
        UptimeKuma[Uptime Kuma]
        Caddy[Caddy]
    end

    subgraph Targets
        NE1[Node Exporter\nevery VM]
        NE2[Node Exporter\nProxmox host]
        NE3[Node Exporter\ndashboard VPS, from ldn]
        Names[Proxied names\nDNS, Caddy, certificates]
    end

    NE1 & NE2 & NE3 -->|metrics| Prometheus
    Blackbox -->|one request a minute| Names
    Blackbox -->|results| Prometheus
    Grafana -->|datasource, over the tailnet| Prometheus
    Homepage -->|widgets, over the tailnet| Prometheus
    Homepage -->|panels| Grafana
    Homepage -->|widget| UptimeKuma
    Caddy -->|badges only| UptimeKuma
    GitHub[GitHub README] -->|badge images| Caddy
```

- **Prometheus** scrapes a node exporter on every host of its site for system metrics: the VMs, the Proxmox host and, from ldn, the dashboard VPS
- **blackbox-exporter** requests every name the site's Caddy serves once a minute, which checks the site's DNS, Caddy and its certificates in one go
- **Grafana** visualizes metrics from both sites' Prometheus with dashboards, and mails an alert when a rule on them fires (see [Alerting](#alerting))
- **Homepage** provides a service dashboard with status widgets and quick links
- **Uptime Kuma** checks services from outside the lab and serves the README's status badges

## Components

| Component | Image | Port | Purpose |
|-----------|-------|------|---------|
| Prometheus | `prom/prometheus` | 9090 | Metrics collection and storage |
| blackbox-exporter | `prom/blackbox-exporter` | 9115 (inside the compose network only) | Requests each proxied name for Prometheus |
| Grafana | `grafana/grafana` | 3000 (127.0.0.1 on the dashboard VPS) | Metrics visualization |
| Homepage | `ghcr.io/gethomepage/homepage` | 3002 (127.0.0.1 on the dashboard VPS) | Service dashboard |
| Uptime Kuma | `louislam/uptime-kuma` | 3001 (127.0.0.1 on the dashboard VPS) | Uptime checks, README badges |
| Caddy | `caddy` | 80, 443 (public, on the dashboard VPS) | Uptime Kuma's badges only |

## Hosts

| Environment | VM | IP |
|-------------|----|----|
| WIL | Monitoring | `10.2.20.30` |
| LDN | Monitoring | `10.3.20.30` |
| External | VPS | `178.156.190.134` |
| Dashboard | OVH VPS (Grafana, Homepage, Uptime Kuma) | `135.148.219.216`, tailnet `dashboard` |

## File Locations

### Monitoring Stack

| File | Purpose |
|------|---------|
| `playbooks/infrastructure/monitoring/deploy.yml` | Main playbook |
| `playbooks/infrastructure/monitoring/tasks/monitoring-stack.yml` | Deployment task |
| `playbooks/infrastructure/monitoring/templates/compose.yaml.j2` | Docker Compose definition |
| `playbooks/infrastructure/monitoring/templates/prometheus.yml.j2` | Prometheus scrape config |
| `playbooks/infrastructure/monitoring/files/blackbox.yml` | blackbox-exporter's one module: an HTTPS request, redirects not followed |
| `playbooks/infrastructure/monitoring/handlers/main.yml` | Container lifecycle handlers |
| `inventory/group_vars/site_<env>/infra_monitoring/` | Per-environment variables |

### Dashboard VPS (Grafana, Homepage, Uptime Kuma)

| File | Purpose |
|------|---------|
| `playbooks/infrastructure/dashboard/deploy.yml` | Playbook: Tailscale, Docker, node-exporter, Uptime Kuma, Grafana, Homepage |
| `playbooks/infrastructure/dashboard/tasks/node-exporter.yml` | node-exporter on the VPS (Ubuntu's package, localhost only), tailnet port 9100 |
| `playbooks/infrastructure/dashboard/tasks/uptime-kuma.yml` | Uptime Kuma and Caddy directories, Caddyfile, tailnet port 3001 |
| `playbooks/infrastructure/dashboard/tasks/grafana.yml` | Grafana directories, provisioning and dashboards, tailnet port 3000 |
| `playbooks/infrastructure/dashboard/tasks/homepage.yml` | Homepage config, starts the compose project |
| `playbooks/infrastructure/dashboard/templates/compose.yaml.j2` | Docker Compose definition (Homepage, Uptime Kuma, Grafana, Caddy) |
| `playbooks/infrastructure/dashboard/files/grafana/provisioning/` | Grafana datasources (each site's Prometheus) and dashboard provider |
| `playbooks/infrastructure/dashboard/files/grafana/provisioning/alerting/alerting.yml` | Alert rules for both sites, the email contact point and the notification policy |
| `playbooks/infrastructure/dashboard/files/grafana/dashboards/` | Grafana dashboards (JSON) |
| `playbooks/infrastructure/dashboard/files/Caddyfile` | Public site: Uptime Kuma's badges only |
| `playbooks/infrastructure/dashboard/templates/homepage/services.yaml.j2` | Homepage service cards, for all four tabs |
| `playbooks/infrastructure/dashboard/templates/homepage/bookmarks.yaml.j2` | Homepage bookmarks (none) |
| `playbooks/infrastructure/dashboard/templates/homepage/settings.yaml.j2` | Homepage theme, tabs and layout |
| `playbooks/infrastructure/dashboard/templates/homepage/widgets.yaml.j2` | Homepage widgets |
| `playbooks/infrastructure/dashboard/files/homepage/custom.css` | Homepage colours, type and card styles |
| `inventory/group_vars/site_ovh/infra_dashboard/vars.yml` | Images, allowed hosts, Grafana admin user and URL |
| `inventory/group_vars/site_wil/proxy/ext.5am.cloud.yml` | wil's BIND record for `uptime.ext.5am.cloud` |
| `inventory/group_vars/site_ovh/infra_dashboard/tailscale.yml` | Tailscale client settings |
| `inventory/group_vars/site_ovh/secrets.sops.yml` | Widget API keys, Grafana admin password and the address alerts are mailed to (section `infra_dashboard`) |

## Deployment

```bash
task ansible:deploy-monitoring ENV=wil
task ansible:deploy-dashboard ENV=ovh    # Grafana, Homepage, Uptime Kuma and Kanidm on the OVH VPS (site ovh)
```

### Monitoring Stack Deployment

The task file:

1. Creates the directory structure: rendered config under `/opt/monitoring/`, Prometheus state under `/var/lib/monitoring/`
2. Sets ownership to `monitoring_uid:monitoring_gid`
3. Deploys Prometheus configuration and blackbox-exporter's
4. Deploys Docker Compose file
5. Starts all containers and removes any that are no longer in `compose.yaml`

---

## Prometheus

Prometheus scrapes metrics from the node exporter on every host of its site, and the results of blackbox-exporter's requests.

### Node exporters

Every host under `[site_<env>]` in the inventory is scraped on `:9100`. Where node-exporter comes from depends on the host:

| Host | node-exporter is |
|------|------------------|
| VMs cloned from the Packer template | Installed by the template (a binary in `/usr/local/bin`, unit `node-exporter`) |
| wil's media VM | A container in the media stack's compose project |
| Proxmox hosts | Debian's package `prometheus-node-exporter`, installed by `task ansible:deploy-proxmox` (see [Proxmox Hosts](../proxmox.md)) |
| Dashboard VPS | Ubuntu's package, installed by the dashboard playbook (`tasks/node-exporter.yml`) |

The VPS has no Prometheus of its own, so ldn's scrapes it, at its tailnet address (`sites.ovh.tailnet_ip`), and the alert rules for ldn's hosts cover it: an alert about the VPS arrives as an ldn alert for `100.116.40.99:9100`. The VPS has a public address and no firewall of its own, so its node-exporter listens on `127.0.0.1:9100` only (`/etc/default/prometheus-node-exporter`, written before the package is installed, because the package starts the service at once on every address) and `tailscale serve --tcp=9100` puts it on the tailnet. wil's Prometheus can't take this job: wil's VMs can't open a connection to the VPS's tailnet address (their router drops it).

Install node-exporter on a host before the monitoring deploy that adds it as a target. A target that doesn't answer raises *Target down* after 5 minutes.

### Checks through the proxy

Homepage's status dots and the node exporters reach every backend by IP address, so they stay green when the site's DNS, Caddy or a certificate fails. blackbox-exporter closes that gap. It runs next to Prometheus on the monitoring VM and, once a minute, requests `https://<name>.<domain>/` for every name the site's Caddy serves, resolving it through the site's BIND like any browser on the LAN. The list is the Caddyfile's: every entry of `services` with `proxied: true`, so a new proxied name is checked after the next monitoring deploy. ldn's also requests `https://auth.5am.cloud` (`prometheus_blackbox_targets`), the login page that Kanidm serves on the VPS.

Redirects are not followed (`files/blackbox.yml`). A name behind the login answers `302` without its backend being asked, which still shows that DNS, Caddy and the certificate work; a name without the login (Plex, KOSync, Kasm, MicroBin) answers from its backend. The alert rules read two of the results:

| Metric | Meaning |
|--------|---------|
| `probe_http_status_code` | The HTTP status. `0` is no answer at all: the name didn't resolve, Caddy didn't answer or its certificate was refused. `502` is Caddy answering for a backend that is down |
| `probe_ssl_earliest_cert_expiry` | When the certificate runs out (Unix time) |

In Prometheus the job is `blackbox` and `instance` is the name (`https://plex.5am.video`); the address scraped is always `blackbox-exporter:9115`. `up` for this job says whether blackbox-exporter answered, not the name.

### Scrape Configuration

The `prometheus.yml.j2` template generates the scrape config:

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node-exporter'
    static_configs:
      - targets:
          - '10.2.20.7:9100'
          - '10.2.0.5:9100'
          # ... all node targets
```

The `blackbox` job follows (see [Checks through the proxy](#checks-through-the-proxy)). Three additional jobs — `chrony`, `gpsd`, and `node` — scrape the PTP grandmaster's exporters (deployed by the `ptp-experiments` repo's `monitoring` role). Each renders only when its per-environment target list is non-empty; currently only LDN defines them. The `node` job is kept separate from `node-exporter` because the Chrony dashboard's CPU-temperature panel selects `job="node"` unscoped.

### Container Configuration

- **Memory:** 2GB limit, 1GB reservation
- **Retention:** configurable via `prometheus_retention`
- **Storage:** persistent volume at `/prometheus`
- **User:** runs as `monitoring_uid:monitoring_gid`

<small>**Source:** [`ansible/playbooks/infrastructure/monitoring/templates/prometheus.yml.j2`](https://github.com/sfcal/homelab/blob/main/ansible/playbooks/infrastructure/monitoring/templates/prometheus.yml.j2)</small>

### Configuration Reference

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `prometheus_image` | `string` | Docker image for Prometheus | (per-env) |
| `prometheus_retention` | `string` | Metrics data retention period | `"30d"` |
| `blackbox_exporter_image` | `string` | Docker image for blackbox-exporter | (per-env) |
| `prometheus_node_targets` | `list[string]` | Node exporter endpoints to scrape (`host:port`): every host of the site in the inventory (`[site_<env>]`) on `:9100`; ldn's list ends with the dashboard VPS's tailnet address | (derived) |
| `prometheus_blackbox_targets` | `list[string]` | Addresses blackbox-exporter requests besides the site's proxied names (ldn: `https://auth.5am.cloud`) | `[]` |
| `prometheus_chrony_targets` | `list[string]` | chrony_exporter endpoints (PTP grandmaster, `:9123`) | `[]` |
| `prometheus_gpsd_targets` | `list[string]` | gpsd exporter endpoints (PTP grandmaster, `:9015`) | `[]` |
| `prometheus_ptp_node_targets` | `list[string]` | PTP grandmaster node_exporter endpoints (job `node`, `:9100`) | `[]` |

<small>**Sources:** `ansible/inventory/group_vars/site_<env>/infra_monitoring/prometheus.yml` · `ansible/inventory/group_vars/site_<env>/infra_monitoring/containers.yml`</small>

---

## Grafana

One Grafana covers both sites. It runs on the OVH VPS next to Homepage, in the same compose project (`/opt/dashboard`, state in `/var/lib/dashboard/grafana`), and reads each site's Prometheus over the tailnet, so it stays up when a site is down; that site's graphs are then empty.

### Access

Tailnet only: **http://dashboard:3000**. Grafana listens on `127.0.0.1:3000`, and `tailscale serve` puts it on the tailnet's port 3000. Anyone on the tailnet can view the dashboards without signing in; sign in as `admin` to edit. There is no `grafana.<site>.5am.cloud` name any more.

### Datasource Provisioning

`files/grafana/provisioning/datasources/datasources.yml` provisions one Prometheus datasource per site:

| Name | uid | URL |
|------|-----|-----|
| Prometheus (wil) | `prometheus-wil` (default) | `http://10.2.20.30:9090` |
| Prometheus (ldn) | `prometheus-ldn` | `http://10.3.20.30:9090` |

The uids are fixed because the provisioned dashboards bind to them. Grafana reads datasources at start; the playbook restarts it when the file changes.

### Dashboard Provisioning

Dashboards are provisioned from files — any JSON dropped into `playbooks/infrastructure/dashboard/files/grafana/dashboards/` is deployed and picked up automatically (the file provider rescans every 30 s; UI edits to provisioned dashboards do not persist):

| Dashboard | File | Data |
|-----------|------|------|
| Chrony Detail | `chrony_grafana_dashboard.json` | `chrony` + `node` jobs (PTP grandmaster), from `prometheus-ldn` |
| GPSD | `gpsd_grafana_dashboard.json` | `gpsd` job (PTP grandmaster), from `prometheus-ldn` |
| Node Exporter Full | `node_exporter_full.json` | All `node-exporter`/`node` targets, site picked with the Datasource variable ([grafana.com 1860](https://grafana.com/grafana/dashboards/1860)) |
| System Activity | `system_activity.json` | CPU, memory, network and disk I/O per `node-exporter` target, site picked with the Site variable (`?var-ds=prometheus-wil` or `prometheus-ldn`); Homepage embeds its four panels |

A new dashboard either binds to one site's uid or gets a datasource variable (type `datasource`, query `prometheus`) and uses `${<variable>}` as each panel's datasource uid.

### Alerting

Grafana checks both sites once a minute and sends mail when something is wrong. It runs on the VPS, outside both sites, so it also notices when a whole site stops answering. Nothing watches the VPS itself, by choice (it is hosted at OVH): while it is down, no alert is sent.

The rules, the contact point and the notification policy are provisioned from one file, `files/grafana/provisioning/alerting/alerting.yml`. They show in Grafana under **Alerting** (**http://dashboard:3000/alerting/list** lists what is firing) and can't be edited there: change the file and deploy. Grafana stops at start when it can't read the file (a misspelt duration is enough; its log says `Failed to provision alerting`), so open that page after a deploy.

| Rule | Fires when |
|------|------------|
| Prometheus unreachable | Grafana has not been able to query the site's Prometheus for 5 minutes: the site, its tailnet link or the monitoring VM is down |
| Target down | A scrape target has not answered Prometheus for 5 minutes |
| Disk almost full | A filesystem (ext4, xfs, btrfs, zfs or NFS) has been more than 85% full for 15 minutes |
| Memory almost full | A host has used more than 90% of its memory for 15 minutes |
| Out-of-memory kills | The kernel killed a process that ran out of memory in the last 15 minutes |
| Clock not synchronised | A host's clock has not been synchronised to a time server for 15 minutes |
| Name not answering | A name the site's Caddy serves has given no answer, or a `5xx` status, for 5 minutes (see [Checks through the proxy](#checks-through-the-proxy)) |
| Certificate expiring | A certificate runs out in less than 7 days. Caddy renews weeks before that, so renewal has been failing |

A rule reads one datasource, so every rule is written twice in the file: in the group `wil` (datasource `prometheus-wil`) and in the group `ldn` (`prometheus-ldn`). Change a rule in both groups. In a rule, `A` is the Prometheus query, which returns one number per host or target, and `B` is the test on it (`$A > 85`). The rule fires for every host or target where the test has held for as long as `for`.

While a site's Prometheus can't be reached, its other rules keep the state they had (`execErrState: KeepLast`), so a site that goes down sends one mail, not one per rule.

**Mail.** One mail when an alert starts, one when it ends, and a reminder once a day while it lasts (`repeat_interval`). Alerts of the same rule share a mail. Grafana sends through Fastmail as `noreply@5am.cloud`, with the same login as Kanidm's mail sender (`GF_SMTP_*` in `compose.yaml.j2`), to `grafana_alert_email`. The contact point reads that address from the environment variable `ALERT_EMAIL`, so it is not in the repository. Links in a mail open `http://dashboard:3000`, so they work on the tailnet only.

### Container Configuration

- **Memory:** 1GB limit, 256MB reservation
- **Ports:** `127.0.0.1:3000` only
- **Provisioning:** mounted read-only at `/etc/grafana/provisioning`
- **Sign-up:** disabled (`GF_USERS_ALLOW_SIGN_UP=false`)
- **Embedding:** allowed, and anyone who is not signed in gets read-only access (`GF_SECURITY_ALLOW_EMBEDDING`, `GF_AUTH_ANONYMOUS_*`), so Homepage can show panels in iframes without a Grafana login

### Configuration Reference

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `grafana_image` | `string` | Docker image for Grafana | `grafana/grafana:13.3.0` |
| `grafana_admin_user` | `string` | Admin username for the web UI | `"admin"` |
| `grafana_admin_password` | `string` | Admin password (SOPS-encrypted, `site_ovh/secrets.sops.yml`); only applied when Grafana creates its database | (required) |
| `grafana_url` | `string` | Root URL for links in notifications and dashboards | `http://dashboard:3000` |
| `grafana_alert_email` | `string` | Address alerts are mailed to (SOPS-encrypted, `site_ovh/secrets.sops.yml`) | (required) |

<small>**Sources:** `ansible/inventory/group_vars/site_ovh/infra_dashboard/vars.yml` · [`ansible/playbooks/infrastructure/dashboard/files/grafana/provisioning/datasources/datasources.yml`](https://github.com/sfcal/homelab/blob/main/ansible/playbooks/infrastructure/dashboard/files/grafana/provisioning/datasources/datasources.yml)</small>

---

## Homepage

Homepage provides a service dashboard with status widgets, service health indicators, and quick links to all homelab services. One instance covers both sites and runs on an OVH VPS (`135.148.219.216`, Virginia), so it stays up when a site is down; its cards then show what is unreachable.

### Access

Tailnet only: **http://dashboard/** (needs Tailscale's DNS on the device, which adds the tailnet's search domain). Homepage listens on `127.0.0.1:3002`, and `tailscale serve` puts it on the tailnet's port 80. Besides SSH, the VPS's only public ports are 80 and 443, which serve Uptime Kuma's badges and nothing else (see [Uptime Kuma](#uptime-kuma)). Plain HTTP, because the System Activity panels load from Grafana at `http://dashboard:3000` and an HTTPS page would block them; the tailnet encrypts the traffic anyway. Use the short name: for the full name `dashboard.tail1e494e.ts.net`, Chrome tries HTTPS first and warns or blocks, since the tailnet has HTTPS certificates off (single-label names are exempt).

`tailscale serve` cannot proxy to the sites' subnets itself (tailscaled's own connections don't use the subnet routes), so anything the browser needs from a site must be reachable from the browser directly. Grafana's panels don't need that: Grafana runs on the VPS and queries the sites from its container, which does use the routes.

The VPS joins the tailnet as a client named `dashboard` that accepts the sites' subnet routes, which is how its widgets reach `10.2.x.x` and `10.3.x.x`. Its Tailscale values are in `site_ovh/infra_dashboard/tailscale.yml`. The VPS is its own site, `ovh`, so it inherits nothing from the lab sites (in `site_wil` it would pick up wil-gateway's subnet-router settings).

### Container Configuration

- **Memory:** 512MB limit, 256MB reservation
- **Ports:** `127.0.0.1:3002` only
- **Environment:** receives API keys for service widgets (Sonarr, Radarr, Bazarr, Prowlarr, SABnzbd, Plex); `compose.yaml` is root-only (`0600`)

### Configuration Reference

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `homepage_image` | `string` | Docker image for Homepage | `ghcr.io/gethomepage/homepage:latest` |
| `homepage_allowed_hosts` | `string` | Comma-separated hostnames Homepage responds to | `dashboard.tail1e494e.ts.net,dashboard` |

### Dashboard Configuration

Homepage is configured via four YAML template files and a stylesheet:

| File | Purpose |
|----------|---------|
| `services.yaml.j2` | Service cards: a small card per service for the Overview tab, and the full cards with widgets for the site tabs (Grafana graphs, media, apps, infrastructure, monitoring) |
| `bookmarks.yaml.j2` | Empty: every link is a card on the Overview tab. The file stays, because Homepage writes its example bookmarks when it is missing |
| `settings.yaml.j2` | Theme (light, gray), status dots, tabs (Overview, wil, ldn, ovh), group icons, layout (row style, column counts) |
| `widgets.yaml.j2` | Global widgets (the VPS's resources, search bar, datetime) |
| `files/homepage/custom.css` | The look: the layout of a dashboard shared in [Homepage's "Share your homepage" thread](https://github.com/gethomepage/homepage/discussions/473#discussioncomment-18831380) in the colours of [samuel.computer](https://samuel.computer) (sky page, frosted-glass header, white cards, olive accents, Inter) |

The dashboard has four tabs:

| Tab | Shows |
|-----|-------|
| Overview | Every service of all three sites as a small card (icon, link, status dot), in the groups Media, Apps, Infrastructure and Monitoring. Opens first |
| wil | wil in full: System Activity graphs, the media stack's cards with their widgets, apps, infrastructure, Prometheus and the node exporters |
| ldn | The same for ldn |
| ovh | The VPS's own services: Grafana, Uptime Kuma, Kanidm |

`services.yaml.j2` is plain Homepage YAML; edit it directly. These parts are less obvious:

- **Two cards per service:** Homepage shows a group on one tab only, so each service is written twice: a small card (`icon`, `href`, `siteMonitor`) in an Overview group, and its full card (with `description` and widgets) in its site's group. Change a link or a status URL in both.
- **Links:** a small card's `href` ends in `/` and its full card's doesn't. Quick launch (start typing on the page) lists both cards, and two entries with the same name and the same link make it show results that no longer match what was typed.
- **Group names** are unique across the file, because Homepage finds a card by its group's name. That is why most groups on the site tabs carry their site: `Infrastructure (wil)`, `Apps (ldn)`, `Services (ovh)`. A new group needs a matching entry in the `layout` of `settings.yaml.j2`, with the `tab` it belongs on; a group left out of `layout` shows on every tab.
- **Status dots:** `siteMonitor` requests the URL from the VPS and counts any answer up to 403 as up. KOSync's small card has none: it answers 412 to a request without KOReader's `Accept` header, so only its full card checks it, with a `customapi` widget that sends the header.
- **Tile colours:** a widget's `highlight` rules mark tiles good, warn or danger, and `custom.css` tints them lime, orange or pink (Homepage's own tints lose to the tile background). Used for Prometheus targets down, Uptime Kuma sites down, Tdarr errors, Prowlarr failed grabs and KOSync health.
- **System Activity** shows the four panels of the System Activity Grafana dashboard on each site's tab, in iframes from `http://dashboard:3000/d-solo/system-activity?var-ds=prometheus-<site>&panelId=1` to `4`, in Grafana's light theme (`theme=light`). `var-ds` picks the site's Prometheus. Grafana allows anonymous viewing and embedding. The time range and refresh interval come from the dashboard JSON.
- **Node exporters** follow Prometheus in each site's Monitoring group: a few VMs per site, listed by hand in `services.yaml.j2`. Prometheus itself scrapes every host of the site (`prometheus_node_targets`); a new VM gets a tile only when it is added to that list.
- **Five cards in a row** (`columns: 5`: the Overview groups and the Monitoring groups) become four in a window 1024px to 1279px wide, where five are too narrow (`custom.css`). Narrower windows get Homepage's own two in a row, then one.
- **SABnzbd** has two widgets: Homepage's `sabnzbd` widget (speed, queue) and a `customapi` widget that reads the download totals for today, this week, this month and all time from SABnzbd's `server_stats` API once a minute.

<small>**Sources:** `ansible/inventory/group_vars/site_ovh/infra_dashboard/vars.yml` · [`ansible/playbooks/infrastructure/dashboard/templates/homepage/services.yaml.j2`](https://github.com/sfcal/homelab/blob/main/ansible/playbooks/infrastructure/dashboard/templates/homepage/services.yaml.j2)</small>

---

## Uptime Kuma

Uptime Kuma runs next to Homepage on the OVH VPS, in the same compose project (`/opt/dashboard`, state in `/var/lib/dashboard/uptime-kuma`), so its checks keep running when a site is down. It reaches the sites over the tailnet like Homepage's widgets, and the internet directly. The status badges in the repository's README come from it.

### Access

- **Admin page:** tailnet only, **http://dashboard:3001**. Uptime Kuma listens on `127.0.0.1:3001` and `tailscale serve` puts it on the tailnet's port 3001. The first visit asks for the admin account. `UPTIME_KUMA_DB_TYPE=sqlite` skips the database question that Uptime Kuma 2 asks first.
- **Badges:** public, **https://uptime.ext.5am.cloud/api/badge/...**. Caddy (`files/Caddyfile`) passes `/api/badge/*` to Uptime Kuma and answers 404 for everything else, the login and status pages included. It gets its certificate from Let's Encrypt, so ports 80 and 443 are open on the VPS's public address (only there: `tailscale serve` holds port 80 on the tailnet address).
- **DNS:** `uptime.ext.5am.cloud` is a DNS-only A record in Cloudflare pointing at `135.148.219.216`, and wil's BIND serves the same address to the lab (`site_wil/proxy/ext.5am.cloud.yml`, applied by a wil networking deploy).

Monitors and status pages live in Uptime Kuma's database, not in Ansible: add them on the admin page.

### Badges

Uptime Kuma only draws a badge for a monitor that is on a published status page; any other monitor ID returns a grey `N/A`. Every monitor with a badge goes on the status page with the slug `default`, which Homepage's Uptime Kuma widget reads too. The page itself isn't reachable from the internet; publishing it only lets the badges show.

| Badge | URL |
|-------|-----|
| Up / Down | `https://uptime.ext.5am.cloud/api/badge/<id>/status?label=<name>` |
| Uptime % | `https://uptime.ext.5am.cloud/api/badge/<id>/uptime/<duration>?label=<name>` (`24h`, `7d`, `30d`; set `label`, the default one reads `Uptime (30h)` for `30d`) |
| Response time | `https://uptime.ext.5am.cloud/api/badge/<id>/ping/<duration>` |
| Certificate expiry | `https://uptime.ext.5am.cloud/api/badge/<id>/cert-exp` |

The monitor ID is the number at the end of its URL on the admin page (`/dashboard/<id>`). Badges are sent with `Cache-Control: no-store`, so GitHub's image proxy shows the current state (Uptime Kuma caches each badge for 5 minutes itself).

### Configuration Reference

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `uptime_kuma_image` | `string` | Docker image for Uptime Kuma | `louislam/uptime-kuma:2.5.9` |

The badge proxy is Caddy built from `networking/templates/Dockerfile.j2` (the sites' build, with the Cloudflare DNS plugin that Kanidm's `auth.5am.cloud` certificate needs), and its version is pinned there.

<small>**Sources:** `ansible/inventory/group_vars/site_ovh/infra_dashboard/vars.yml` · [`ansible/playbooks/infrastructure/dashboard/files/Caddyfile`](https://github.com/sfcal/homelab/blob/main/ansible/playbooks/infrastructure/dashboard/files/Caddyfile)</small>

---

## Shared Configuration

These variables apply to all monitoring containers:

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `monitoring_uid` | `string` | Container file ownership UID | `"1000"` |
| `monitoring_gid` | `string` | Container file ownership GID | `"1000"` |

## Common Tasks

### Add a new Prometheus scrape target

Node exporter targets come from the inventory: every host under `[site_<env>]` in `ansible/inventory/hosts.ini` is scraped on `:9100` (the Packer template installs node-exporter on every clone). A host that is in the inventory but down shows as a target that is down.

1. Add the host to `[site_<env>]` (and to its role group) in `ansible/inventory/hosts.ini`. For an exporter that is not node-exporter, add its endpoint to the matching list in `ansible/inventory/group_vars/site_<env>/infra_monitoring/prometheus.yml` instead.

2. Deploy:

    ```bash
    task ansible:deploy-monitoring ENV=wil
    ```

### Change metrics retention

1. Edit `ansible/inventory/group_vars/site_<env>/infra_monitoring/prometheus.yml`:

    ```yaml
    prometheus_retention: "90d"
    ```

2. Deploy:

    ```bash
    task ansible:deploy-monitoring ENV=wil
    ```

### Add or change an alert rule

1. Edit `ansible/playbooks/infrastructure/dashboard/files/grafana/provisioning/alerting/alerting.yml`. For a new rule, copy an existing one in the group `wil`, give it a new `uid` and `title`, and set its query (`expr`), its test (`expression`) and `for`. Then make the same change in the group `ldn`.
2. Deploy; the playbook restarts Grafana, which reads the file when it starts:

    ```bash
    task ansible:deploy-dashboard ENV=ovh
    ```

3. Check that the page http://dashboard:3000/alerting/list loads and lists the rule with health `ok`. If Grafana doesn't answer, the file has a mistake: `sudo docker logs grafana` on the VPS names the rule and the field.

### Add a service to Homepage

1. Edit `ansible/playbooks/infrastructure/dashboard/templates/homepage/services.yaml.j2`
2. Add the service twice: its full card (description, widget) to a group of its site, and a small card (`icon`, `href` ending in `/`, `siteMonitor`) to the matching Overview group
3. If the service requires an API key, add the key to the `infra_dashboard` section of `group_vars/site_ovh/secrets.sops.yml` and pass it through `dashboard/templates/compose.yaml.j2`
4. Deploy:

    ```bash
    task ansible:deploy-dashboard ENV=ovh
    ```

### Add a README badge

1. On http://dashboard:3001, add the monitor and put it on the `default` status page (Edit Status Page → add the monitor → Save)
2. Note its ID from the address bar (`/dashboard/<id>`)
3. Add the badge to `README.md`:

    ```markdown
    ![wil](https://uptime.ext.5am.cloud/api/badge/<id>/status?label=wil)
    ```

No deploy needed: monitors live in Uptime Kuma's database.
