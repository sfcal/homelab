# Monitoring

The monitoring stack provides metrics collection, visualization, a service dashboard, and external uptime monitoring. It runs as Docker containers on a dedicated VM in each environment.

!!! note "Deployment order"
    Monitoring deploys after [Networking](../networking/index.md), [Step-CA](../ca/index.md), and [NTP](../ntp/index.md). It is the last infrastructure service to deploy before applications.

## Architecture

```mermaid
graph TD
    subgraph Monitoring VM
        Prometheus[Prometheus]
        Grafana[Grafana]
        Homepage[Homepage]
    end

    subgraph Targets
        NE1[Node Exporter\nmonitoring VM]
        NE2[Node Exporter\nmedia-stack]
        NE3[Node Exporter\nnetworking]
        NE4[Node Exporter\nwebsite]
    end

    subgraph External VPS
        UptimeKuma[Uptime Kuma]
    end

    NE1 & NE2 & NE3 & NE4 -->|metrics| Prometheus
    Prometheus -->|datasource| Grafana
    UptimeKuma -->|health checks| Prometheus
```

- **Prometheus** scrapes node exporters across all VMs for system metrics
- **Grafana** visualizes metrics from Prometheus with dashboards
- **Homepage** provides a service dashboard with status widgets and quick links
- **Uptime Kuma** runs on an external VPS for independent uptime monitoring via [Tailscale](../networking/tailscale.md)

## Components

| Component | Image | Port | Purpose |
|-----------|-------|------|---------|
| Prometheus | `prom/prometheus` | 9090 | Metrics collection and storage |
| Grafana | `grafana/grafana` | 3000 | Metrics visualization |
| Homepage | `ghcr.io/gethomepage/homepage` | 3002 | Service dashboard |
| Uptime Kuma | `louislam/uptime-kuma` | 3001 | External uptime monitoring |

## Hosts

| Environment | VM | IP |
|-------------|----|----|
| WIL | Monitoring | `10.2.20.30` |
| LDN | Monitoring | `10.3.20.30` |
| External | VPS | `178.156.190.134` |

## File Locations

### Monitoring Stack

| File | Purpose |
|------|---------|
| `playbooks/infrastructure/monitoring/deploy.yml` | Main playbook |
| `playbooks/infrastructure/monitoring/tasks/monitoring-stack.yml` | Deployment task |
| `playbooks/infrastructure/monitoring/templates/compose.yaml.j2` | Docker Compose definition |
| `playbooks/infrastructure/monitoring/templates/prometheus.yml.j2` | Prometheus scrape config |
| `playbooks/infrastructure/monitoring/templates/grafana-datasources.yml.j2` | Grafana datasource provisioning |
| `playbooks/infrastructure/monitoring/templates/services.yaml.j2` | Homepage services dashboard |
| `playbooks/infrastructure/monitoring/templates/bookmarks.yaml.j2` | Homepage bookmarks |
| `playbooks/infrastructure/monitoring/templates/settings.yaml.j2` | Homepage theme and layout |
| `playbooks/infrastructure/monitoring/templates/widgets.yaml.j2` | Homepage widgets |
| `playbooks/infrastructure/monitoring/handlers/main.yml` | Container lifecycle handlers |
| `environments/<env>/group_vars/infra_monitoring/` | Per-environment variables |

### External Monitoring

| File | Purpose |
|------|---------|
| `playbooks/infrastructure/external-monitoring/deploy.yml` | Main playbook |
| `playbooks/infrastructure/external-monitoring/templates/compose.yaml.j2` | Docker Compose definition |
| `environments/external/group_vars/infra_externalmonitoring/vars.yml` | External monitoring variables |

## Deployment

```bash
# Deploy internal monitoring stack
task ansible:deploy-monitoring ENV=wil

# Deploy external uptime monitoring
task ansible:deploy-external-monitoring ENV=external
```

### Monitoring Stack Deployment

The task file:

1. Creates directory structure under `/opt/monitoring/`
2. Sets ownership to `monitoring_uid:monitoring_gid`
3. Deploys Prometheus configuration
4. Deploys Grafana datasource provisioning
5. Deploys Homepage configuration files (services, bookmarks, settings, widgets)
6. Deploys Docker Compose file
7. Starts all containers

### External Monitoring Deployment

The external monitoring playbook:

1. Runs the `common` role (timezone, apt cache)
2. Installs and configures [Tailscale](../networking/tailscale.md) as a client (to reach internal services)
3. Deploys Uptime Kuma via the `docker_service` role

---

## Prometheus

Prometheus scrapes metrics from node exporters running on infrastructure and application VMs.

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
          - 'localhost:9100'
          - '10.2.0.5:9100'
          # ... all node targets
```

### Container Configuration

- **Memory:** 2GB limit, 1GB reservation
- **Retention:** configurable via `prometheus_retention`
- **Storage:** persistent volume at `/prometheus`
- **User:** runs as `monitoring_uid:monitoring_gid`

### Configuration Reference

---

#### `prometheus_version`

Docker image tag for Prometheus.

**Type:** `string`

```yaml
prometheus_version: "v3.3.0"
```

---

#### `prometheus_retention`

How long to retain metrics data.

**Type:** `string`

**Default:** `"30d"`

```yaml
prometheus_retention: "30d"
```

---

#### `prometheus_node_targets`

List of node exporter endpoints to scrape. Each entry is a `host:port` string.

**Type:** `list[string]`

=== "WIL"

    ```yaml
    prometheus_node_targets:
      - "localhost:9100"
      - "10.2.0.5:9100"
      - "10.2.20.53:9100"
      - "10.2.20.45:9100"
    ```

=== "LDN"

    ```yaml
    prometheus_node_targets:
      - "localhost:9100"
      - "10.3.0.53:9100"
    ```

---

#### `node_exporter_version`

Docker image tag for the Node Exporter sidecar.

**Type:** `string`

```yaml
node_exporter_version: "v1.9.1"
```

---

## Grafana

Grafana connects to Prometheus as its default datasource and provides metric visualization dashboards.

### Datasource Provisioning

Grafana auto-provisions a Prometheus datasource on startup via `grafana-datasources.yml.j2`:

```yaml
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
```

### Container Configuration

- **Memory:** 2GB limit, 1GB reservation
- **Depends on:** Prometheus
- **Provisioning:** mounted read-only at `/etc/grafana/provisioning`
- **Sign-up:** disabled (`GF_USERS_ALLOW_SIGN_UP=false`)

### Configuration Reference

---

#### `grafana_version`

Docker image tag for Grafana.

**Type:** `string`

```yaml
grafana_version: "11.6.0"
```

---

#### `grafana_admin_user`

Admin username for the Grafana web UI.

**Type:** `string`

**Default:** `"admin"`

```yaml
grafana_admin_user: admin
```

---

#### `grafana_admin_password`

Admin password for the Grafana web UI.

**Type:** `string`

!!! warning
    Stored in SOPS-encrypted `secrets.sops.yml`, never in plaintext.

---

#### `grafana_url`

Root URL for Grafana. Used for links in notifications and provisioned dashboards.

**Type:** `string`

```yaml
grafana_url: "https://grafana.5am.video"
```

---

## Homepage

Homepage provides a service dashboard with status widgets, service health indicators, and quick links to all homelab services.

### Container Configuration

- **Memory:** 512MB limit, 256MB reservation
- **Docker socket:** mounted read-only for container status widgets
- **Environment:** receives API keys for service widgets (Sonarr, Radarr, Bazarr, Prowlarr, SABnzbd, Plex)

### Configuration Reference

---

#### `homepage_version`

Docker image tag for Homepage.

**Type:** `string`

**Default:** `"latest"`

```yaml
homepage_version: "latest"
```

---

#### `homepage_allowed_hosts`

Comma-separated list of hostnames Homepage will respond to. Required for security.

**Type:** `string`

=== "WIL"

    ```yaml
    homepage_allowed_hosts: "homepage.wil.5am.cloud"
    ```

=== "LDN"

    ```yaml
    homepage_allowed_hosts: "homepage.ldn.5am.cloud"
    ```

### Dashboard Configuration

Homepage is configured via four YAML template files:

| Template | Purpose |
|----------|---------|
| `services.yaml.j2` | Service cards with status widgets (media, monitoring, node exporters) |
| `bookmarks.yaml.j2` | Quick links (TrueNAS, Proxmox) |
| `settings.yaml.j2` | Theme (dark, slate), layout (row style, column counts) |
| `widgets.yaml.j2` | Global widgets (search bar, datetime) |

---

## External Monitoring (Uptime Kuma)

Uptime Kuma runs on an external VPS to provide independent uptime monitoring. It connects to the internal network via Tailscale to monitor services that are not publicly exposed.

### Configuration Reference

---

#### `uptime_kuma_version`

Docker image tag for Uptime Kuma.

**Type:** `string`

```yaml
uptime_kuma_version: "2"
```

---

#### `external_monitoring_uptime_kuma_listen`

Port Uptime Kuma listens on.

**Type:** `string`

**Default:** `"3001"`

```yaml
external_monitoring_uptime_kuma_listen: "3001"
```

### Tailscale Integration

The external VPS runs Tailscale as a client with route acceptance enabled:

```yaml
tailscale_mode: "client"
tailscale_hostname: "external-monitor"
tailscale_accept_routes: true
```

This allows Uptime Kuma to reach internal services (e.g., `10.2.20.53`) through the Tailscale mesh without exposing them publicly. See [VPN (Tailscale)](../networking/tailscale.md) for details.

---

## Shared Configuration

These variables apply to all monitoring containers:

---

### `monitoring_uid` / `monitoring_gid`

UID and GID for file ownership and container user.

**Type:** `string`

**Default:** `"1000"`

```yaml
monitoring_uid: "1000"
monitoring_gid: "1000"
```

---

### `backup_targets`

List of service directories under `/opt/monitoring/` to include in backups.

**Type:** `list[string]`

```yaml
backup_targets:
  - prometheus
  - grafana
  - uptime-kuma
  - homepage
```

## Common Tasks

### Add a new Prometheus scrape target

1. Edit `ansible/environments/<env>/group_vars/infra_monitoring/prometheus.yml`:

    ```yaml
    prometheus_node_targets:
      # ... existing targets
      - "10.2.20.60:9100"   # new VM
    ```

2. Deploy:

    ```bash
    task ansible:deploy-monitoring ENV=wil
    ```

### Change metrics retention

1. Edit `ansible/environments/<env>/group_vars/infra_monitoring/prometheus.yml`:

    ```yaml
    prometheus_retention: "90d"
    ```

2. Deploy:

    ```bash
    task ansible:deploy-monitoring ENV=wil
    ```

### Add a Homepage service widget

1. Edit `ansible/playbooks/infrastructure/monitoring/templates/services.yaml.j2`
2. Add a new service entry under the appropriate section
3. If the service requires an API key, add the key to `secrets.sops.yml` and pass it through `compose.yaml.j2`
4. Deploy:

    ```bash
    task ansible:deploy-monitoring ENV=wil
    ```
