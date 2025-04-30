# Kubernetes Configuration for Homelab

This directory contains the Kubernetes configuration for a GitOps-managed Kubernetes cluster using FluxCD. The infrastructure is designed to be declarative, versioned, and self-healing, with support for multiple environments (homelab and production).

## Table of Contents
- [Architecture Overview](#architecture-overview)
- [Directory Structure](#directory-structure)
- [Key Components](#key-components)
- [Deployment Flow](#deployment-flow)
- [Configuration Guide](#configuration-guide)
- [Adding Applications](#adding-applications)
- [Multi-Environment Deployment](#multi-environment-deployment)

## Architecture Overview

This Kubernetes configuration implements a GitOps approach using FluxCD, where:

1. All configuration is stored in Git (this repository)
2. FluxCD continuously monitors the repository for changes
3. When changes are detected, they are automatically applied to the cluster
4. The actual state of the cluster is reconciled with the desired state

The setup includes a complete infrastructure layer (networking, storage, monitoring, certs) and an application layer, organized using Kustomize overlays.

## Directory Structure

```
kubernetes/
├── .gitignore                 # Ignores sensitive files like secrets
├── apps/                      # Application deployments
│   ├── base/                  # Base application configurations
│   │   └── nginx/             # Example base application (nginx)
│   └── homelab/               # Environment-specific application overlays
│       └── nginx/             # Environment-specific nginx config
├── cluster/                   # Cluster-specific configurations
│   └── homelab/               # Homelab cluster settings
│       ├── apps.yaml          # Application layer definition
│       ├── cluster-settings.yaml  # Cluster variables as ConfigMap
│       ├── flux-system-automation.yaml # Flux image automation
│       ├── infrastructure.yaml # Infrastructure layer definition
│       └── kustomization.yaml  # Cluster kustomization
├── flux-system/               # Flux system configurations
│   ├── gotk-sync.yaml         # Git repository sync definition
│   └── kustomization.yaml     # Flux system kustomization
└── infrastructure/            # Infrastructure components
    ├── cert-manager/          # Certificate management
    ├── external-secrets/      # External secrets management
    ├── kube-prometheus-stack/ # Monitoring stack
    ├── longhorn/              # Distributed storage
    ├── sources/               # Helm repositories and Git sources
    ├── traefik/               # Ingress controller
    └── kustomization.yaml     # Infrastructure kustomization
```

## Key Components

### Infrastructure Layer

1. **Traefik** (infrastructure/traefik/)
   - Ingress controller for routing external traffic to services
   - Configured with automatic HTTPS and middleware support
   - Includes security headers and dashboard access

2. **Cert-Manager** (infrastructure/cert-manager/)
   - Manages TLS certificates automatically
   - Configured with Let's Encrypt issuers (staging and production)
   - Uses DNS01 challenge with Cloudflare integration

3. **Longhorn** (infrastructure/longhorn/)
   - Distributed block storage for persistent volumes
   - Provides replicated storage across nodes
   - Includes UI for storage management

4. **Kube-Prometheus-Stack** (infrastructure/kube-prometheus-stack/)
   - Comprehensive monitoring solution
   - Includes Prometheus, Grafana, and Alertmanager
   - Pre-configured dashboards and alerts

5. **External-Secrets** (infrastructure/external-secrets/)
   - Synchronizes secrets from external sources
   - Configured with Kubernetes backend in this setup
   - Enables secure secret management

### Application Layer

The application layer is structured with:

1. **Base configurations** (apps/base/)
   - Contains the common configuration for applications
   - Example: nginx deployment and service definitions

2. **Environment overlays** (apps/homelab/)
   - Environment-specific customizations
   - Example: nginx ingress routes for specific domains

### GitOps Automation

The GitOps pipeline is managed by FluxCD:

1. **Git Repository Source** (flux-system/gotk-sync.yaml)
   - Configures the Git repository to monitor
   - Set to sync from the main branch every minute

2. **Kustomizations** (cluster/homelab/)
   - Defines what parts of the repo to deploy
   - Sets dependencies between infrastructure and apps

## Deployment Flow

The deployment follows this sequence:

1. FluxCD is installed on the cluster and pointed to this repository
2. FluxCD deploys the infrastructure components first
   - Sources (Helm repositories)
   - Cert-Manager
   - Traefik
   - External-Secrets
   - Longhorn
   - Kube-Prometheus-Stack
3. Once infrastructure is ready, applications are deployed
   - Currently configured: nginx example app

## Configuration Guide

### Cluster Settings

The file `cluster/homelab/cluster-settings.yaml` contains key cluster-wide settings:

```yaml
# Example settings
TIMEZONE: "America/Los_Angeles"
DOMAIN: "local.samuelcalvert.com"
METALLB_LB_RANGE: "10.1.10.140-10.1.10.150"
CLUSTER_CIDR: "10.42.0.0/16"
SERVICE_CIDR: "10.43.0.0/16"
```

Modify these values to match your environment.

### TLS Certificates

TLS certificates are managed through cert-manager:

1. Update the domain in `infrastructure/cert-manager/certificates/production/local-samuelcalvert-com.yaml`
2. Configure Cloudflare API token in `infrastructure/cert-manager/issuers/cloudflare-token-externalsecret.yaml`

### Ingress Routes

All ingress routes use the Traefik CRD format. Example from nginx:

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: nginx
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`nginx.local.samuelcalvert.com`)
      kind: Rule
      services:
        - name: nginx
          port: 80
  tls:
    secretName: local-samuelcalvert-com-tls
```

## Adding Applications

To add a new application:

1. Create a base configuration in `apps/base/<app-name>/`:
   - deployment.yaml
   - service.yaml
   - kustomization.yaml

2. Create an environment overlay in `apps/homelab/<app-name>/`:
   - ingress.yaml (if needed)
   - kustomization.yaml (referencing the base)

3. Update `apps/homelab/kustomization.yaml` to include your new application

### Example: Adding a New App

1. Create base files in `apps/base/myapp/`:

```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: myapp
        image: myapp:latest
```

```yaml
# service.yaml
apiVersion: v1
kind: Service
metadata:
  name: myapp
  namespace: default
spec:
  selector:
    app: myapp
  ports:
  - port: 80
    targetPort: 8080
```

```yaml
# kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- deployment.yaml
- service.yaml
```

2. Create overlay files in `apps/homelab/myapp/`:

```yaml
# ingress.yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: myapp
  namespace: default
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`myapp.local.samuelcalvert.com`)
      kind: Rule
      services:
        - name: myapp
          port: 80
  tls:
    secretName: local-samuelcalvert-com-tls
```

```yaml
# kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- ../../base/myapp
- ingress.yaml
```

3. Add to `apps/homelab/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- nginx
- myapp  # Add this line
```

Once committed to the repository, FluxCD will automatically deploy the new application.

## Multi-Environment Deployment

This configuration can be extended to support multiple environments, such as adding a production environment alongside the existing homelab setup. Here's how the directory structure would expand to accommodate a production environment:

```
kubernetes/
├── .gitignore
├── apps/
│   ├── base/                  # Shared base configurations (unchanged)
│   │   └── nginx/
│   ├── homelab/               # Homelab environment overlays (unchanged)
│   │   └── nginx/
│   └── production/            # New production environment overlays
│       ├── kustomization.yaml # References all production apps
│       ├── nginx/             # Production-specific nginx overlay
│       │   ├── ingress.yaml   # Production ingress (example.com vs local domain)
│       │   ├── kustomization.yaml # References base with production patches
│       │   └── deployment-patch.yaml # Patch for higher replica count/resources
│       └── other-apps/        # Other production applications
├── cluster/
│   ├── homelab/               # Homelab cluster settings (unchanged)
│   └── production/            # New production cluster settings
│       ├── apps.yaml          # Points to ./kubernetes/apps/production
│       ├── cluster-settings.yaml  # Production environment variables
│       ├── flux-system-automation.yaml # Production image automation
│       ├── infrastructure.yaml # Points to production infrastructure components
│       └── kustomization.yaml  # Production cluster kustomization
├── flux-system/               # Remains largely unchanged
└── infrastructure/
    ├── base/                  # New shared infrastructure base configurations
    │   ├── cert-manager/      # Base cert-manager configuration
    │   ├── external-secrets/  # Base external-secrets configuration
    │   └── ...
    ├── homelab/               # Homelab-specific infrastructure overlays
    │   ├── kustomization.yaml # References all homelab infrastructure
    │   ├── cert-manager/      # Homelab cert-manager overlay
    │   ├── traefik/           # Homelab traefik configuration
    │   └── ...
    └── production/            # Production-specific infrastructure
        ├── kustomization.yaml # References all production infrastructure
        ├── cert-manager/      # Production cert-manager overlay
        │   ├── certificates/  # Production domain certificates
        │   └── kustomization.yaml
        ├── traefik/           # Production traefik configuration
        │   ├── middleware/    # Production-specific security policies
        │   └── values.yaml    # Higher replica count, resources, etc.
        └── ...
```

### Key Differences in Production Environment

The production environment would typically differ from homelab in several important ways:

1. **Domain Names**: Using your actual domain instead of local domains
   ```yaml
   # Production ingress example
   - match: Host(`www.example.com`)
     # Instead of Host(`www.nginx.local.samuelcalvert.com`)
   ```

2. **Resource Requirements**: Higher replica counts and resource allocations
   ```yaml
   # Production deployment patches
   spec:
     replicas: 3  # Instead of 1 in dev
     resources:
       requests:
         memory: "512Mi"  # Higher than dev
         cpu: "250m"      # Higher than dev
   ```

3. **TLS Configuration**: Using production certificates and stricter security
   ```yaml
   # Production TLS configuration  
   tls:
     secretName: example-com-tls  # Production certificate
   ```

4. **Network Configuration**: Different IP ranges and possibly external load balancers
   ```yaml
   # In production cluster-settings.yaml
   METALLB_LB_RANGE: "10.1.20.140-10.1.20.150"  # Production IP range
   ```

5. **Monitoring and Alerts**: More comprehensive monitoring with production alerts
   ```yaml
   # In production prometheus values
   alertmanager:
     receivers:
       - name: 'production-team'
         email_configs:
           - to: 'oncall@example.com'
   ```

### Setting Up a Production Environment

To add a production environment:

1. Create the directory structure shown above
2. Configure the cluster resources in `cluster/production/`
3. Create production-specific application overlays in `apps/production/`
4. Set up production infrastructure configurations in `infrastructure/production/`
5. Optionally refactor shared configurations into `infrastructure/base/`

This structure provides a clean separation between environments while allowing you to reuse common configurations. The infrastructure is also refactored to have base components that can be customized per environment, giving you more flexibility in how you configure each environment.