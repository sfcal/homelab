# Homelab TUI — Build Prompt

## Overview

Build a terminal UI (TUI) application for managing a homelab infrastructure-as-code project. The TUI runs inside a Docker container and provides a unified interface for managing VMs, services, and infrastructure across multiple environments. It uses **Textual** (Python TUI framework), **UV** for dependency management, and shells out to **go-task** (`task` CLI) for executing operations.

The project manages a Proxmox-based homelab with:
- **Terraform** for VM provisioning
- **Ansible** for service configuration/deployment
- **Packer** for VM template building
- **go-task (Taskfile)** as the task runner that wraps all CLI operations

## Critical Design Principle

**The TUI must never require code changes when new apps, services, tasks, or environments are added.** All data must be dynamically discovered at runtime from:
- `task --list-all --json` for available tasks
- Ansible inventory files (`hosts.ini`) for hosts and groups
- Ansible playbook directory structure (`playbooks/apps/*/`, `playbooks/infrastructure/*/`) for available services
- Terraform `vms.auto.tfvars` (HCL format) for VM definitions
- Terraform `terraform.tfstate` (JSON) for provisioning status
- Packer template files (`packer/templates/*.pkr.hcl`) for available templates
- Environment directories (`ansible/environments/*/`) for available environments

## Tech Stack

- **Python 3.12+** with **Textual** (`textual>=0.89.0`)
- **python-hcl2** (`python-hcl2>=4.3.0`) for parsing/writing Terraform HCL variable files
- **UV** for dependency management (pyproject.toml + uv.lock)
- **Hatchling** as build backend
- **Docker** container based on `ghcr.io/astral-sh/uv:python3.12-bookworm-slim`
- Entry point: `homelab-tui = "homelab_tui.app:main"` via `[project.scripts]`
- Package layout: `src/homelab_tui/`

## Project Directory Structure (for context)

The TUI lives at `<project_root>/tui/` and the project root contains:

```
<project_root>/
├── ansible/
│   ├── environments/
│   │   ├── wil/                          # Environment: wil
│   │   │   ├── hosts.ini                 # Ansible inventory (INI format)
│   │   │   └── group_vars/              # Per-group variables
│   │   │       ├── all/                  # Global vars
│   │   │       ├── infra_networking/
│   │   │       ├── infra_ca/
│   │   │       ├── infra_ntp/
│   │   │       ├── infra_monitoring/
│   │   │       ├── app_mediastack/
│   │   │       └── ...                   # One dir per ansible group
│   │   ├── external/                     # Another environment
│   │   └── ldn/                          # Another environment
│   └── playbooks/
│       ├── site.yml                      # Master orchestration playbook
│       ├── infrastructure/
│       │   ├── networking/deploy.yml
│       │   ├── ca/deploy.yml
│       │   ├── ntp/deploy.yml
│       │   ├── monitoring/deploy.yml
│       │   └── external-monitoring/deploy.yml
│       ├── apps/
│       │   ├── media/deploy.yml
│       │   ├── games-server/deploy.yml
│       │   ├── website/deploy.yml
│       │   ├── birdle/deploy.yml
│       │   ├── bookstack/deploy.yml
│       │   ├── convertx/deploy.yml
│       │   ├── cyberchef/deploy.yml
│       │   ├── homeassistant/deploy.yml
│       │   ├── it-tools/deploy.yml
│       │   ├── kasm/deploy.yml
│       │   ├── openbooks/deploy.yml
│       │   ├── restreamer/deploy.yml
│       │   └── stirling-pdf/deploy.yml
│       └── roles/
│           ├── common/
│           ├── docker_service/
│           └── tailscale/
├── terraform/
│   ├── environments/
│   │   ├── wil/
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   ├── vms.auto.tfvars           # VM definitions (HCL)
│   │   │   └── terraform.tfstate         # State file (JSON)
│   │   └── ...
│   └── modules/
│       └── vm/main.tf                    # Generic VM module
├── packer/
│   ├── environments/                     # Per-env packer vars
│   └── templates/
│       ├── ubuntu-server-base.pkr.hcl
│       └── debian-bookworm-base.pkr.hcl
├── .taskfiles/
│   ├── ansible/Taskfile.yaml
│   ├── terraform/Taskfile.yaml
│   ├── packer/Taskfile.yaml
│   ├── ca/Taskfile.yaml
│   └── docker/Taskfile.yaml
├── Taskfile.yaml                          # Root taskfile (includes all above)
└── tui/                                   # THIS PROJECT
    ├── src/homelab_tui/
    ├── pyproject.toml
    ├── uv.lock
    ├── Dockerfile
    └── compose.yml
```

## Hosts Inventory Format (hosts.ini)

The TUI must parse this format to discover hosts and groups:

```ini
# --- Infrastructure ---

[infra_networking]
10.2.20.53

[infra_ca]
10.2.20.9

[infra_ntp]
10.2.20.123

[infra_monitoring]
10.2.20.30

# --- Apps ---

[app_mediastack]
10.2.0.5

[app_gamesserver]
10.2.20.50

# ... more groups ...

# --- Parent groups ---

[infrastructure:children]
infra_networking
infra_ca
infra_ntp
infra_monitoring

[apps:children]
app_mediastack
app_gamesserver
# ... more children ...
```

## VM Definition Format (vms.auto.tfvars)

The TUI must parse and write this HCL format for VM CRUD:

```hcl
vms = {
  networking = {
    name           = "networking"
    description    = "Networking (DNS, Reverse Proxy, Tailscale)"
    proxmox_node   = "proxmox"
    vmid           = 1000
    template_name  = "ubuntu-server-wil-base"
    ip_address     = "10.2.20.53"
    gateway        = "10.2.20.1"
    nameserver     = "10.2.20.1"
    cores          = 2
    memory         = 4096
    disk_size      = "50G"
    storage_pool   = "local-lvm"
    network_bridge = "vmbr0"
    tags           = "infrastructure"
    ssh_user       = "sfcal"
  }

  # ... more VMs ...
}
```

VM fields: `name`, `description`, `proxmox_node`, `vmid`, `template_name`, `ip_address`, `gateway`, `nameserver`, `cores`, `memory`, `disk_size`, `storage_pool`, `network_bridge`, `tags`, `ssh_user`.

## Application Architecture

### Navigation Model

- **Top-level tab bar** across the top of the screen for major sections
- **Global header** showing: app title, current environment name, keybinding hints
- **Global footer** showing: available keybindings for the current context
- **Global environment switcher** accessible from any screen (affects all tabs/data)
- Each tab is a full **Screen** (not inline `TabbedContent` — use screen-level switching with a persistent tab bar)

### Screens/Tabs

1. **Dashboard** — Overview of infrastructure
2. **DNS** — Live DNS query results
3. **NTP** — Chrony tracking and sources
4. **CA** — Certificate Authority management
5. **Docker** — Aggregated container view across VMs
6. **Tasks** — Auto-discovered task execution (Taskfiles)
7. **Terraform** — VM CRUD and deployment
8. **Packer** — Template building
9. **Output** — Multi-pane concurrent command output viewer

### Screen Details

#### 1. Dashboard Screen
- Summary view of the current environment
- VM table showing all VMs with: key, name, IP, status (defined/provisioned/unknown)
  - VM status determined by cross-referencing `vms.auto.tfvars` (defined) with `terraform.tfstate` (provisioned)
- Quick-action buttons: Deploy All (Terraform), Deploy All (Ansible), Ping All
- Host count, service count

#### 2. DNS Screen (Read-Only, Auto-Refresh)
- Runs live DNS queries against the environment's DNS server (the `infra_networking` host IP)
- Discover domains to query from the ansible group_vars (or allow the user to configure a list of domains to check)
- Shows a DataTable with: domain, record type, resolved value, response time
- Auto-refreshes on a configurable interval (default: every 2 seconds)
- Read-only — no editing of DNS records

#### 3. NTP Screen (Auto-Refresh)
- Connects to the NTP server host (the `infra_ntp` host IP) via SSH
- Displays two panels:
  - **Tracking**: output of `chronyc tracking` — shows current sync status, stratum, offset, etc.
  - **Sources**: output of `chronyc sources -v` — shows upstream NTP peers with status
- Auto-refreshes every 1-2 seconds (configurable)
- SSH command: `ssh <user>@<ntp_host_ip> chronyc tracking` and `ssh <user>@<ntp_host_ip> chronyc sources -v`

#### 4. CA Screen
- **Health Status**: poll Step-CA health endpoint (`curl -sk https://<ca_host_ip>:9000/health`)
- **Root CA Info**: display root CA certificate details (subject, issuer, expiry)
- **Issued Certificates**: list certificates with expiry dates (if queryable via Step-CA API)
- **Actions**:
  - Sign CSR: trigger `task ca:sign CSR=<path> ENV=<env>`
  - Fetch root cert: trigger `task ca:root ENV=<env>`
  - Check health: trigger `task ca:health ENV=<env>`
- Auto-refresh health status on configurable interval

#### 5. Docker Screen
- **Aggregated view**: show containers across ALL VMs in the environment
- For each unique host IP discovered from `hosts.ini`, SSH in and run `docker ps --format json` (or similar)
- Display a DataTable with: host IP, container name, image, status, ports, uptime
- Group by host or show flat list with host column
- **Launch lazydocker**: action to open lazydocker on a selected VM in a separate terminal pane
  - Use `ssh -t <user>@<host_ip> lazydocker` spawned in the terminal
- Auto-refresh on configurable interval

#### 6. Tasks Screen (Fully Dynamic)
- Run `task --list-all --json` at startup (and on refresh) to discover all tasks
- The JSON format returns:
  ```json
  {
    "tasks": [
      {
        "name": "ansible:deploy-media",
        "desc": "Deploy media stack",
        "location": { "taskfile": "..." }
      }
    ]
  }
  ```
- Group tasks by namespace prefix (everything before the first `:`):
  - `ansible:*` — Ansible tasks
  - `terraform:*` — Terraform tasks
  - `packer:*` — Packer tasks
  - `ca:*` — CA tasks
  - `docker:*` — Docker tasks
  - Root tasks (no namespace)
- Display as a tree or grouped DataTable with: namespace, task name, description
- On selection + Enter: execute the task with `ENV=<current_env>` passed
- For tasks requiring extra vars (like `VM=`, `CSR=`), prompt the user with an input dialog
- Task output streams to the **Output** screen

#### 7. Terraform Screen
- **VM Table**: DataTable of all VMs from `vms.auto.tfvars` with status from `terraform.tfstate`
  - Columns: key, name, description, IP, cores, memory, disk, status (defined/provisioned/unknown)
- **VM CRUD**:
  - **Create**: modal form with all VM fields, writes to `vms.auto.tfvars` (HCL format) and updates `hosts.ini`
  - **Edit**: modal form pre-filled with existing values, updates both files
  - **Delete**: confirmation dialog, removes from `vms.auto.tfvars` and `hosts.ini`
- **Actions**:
  - Deploy All: `task terraform:deploy ENV=<env>`
  - Deploy VM: `task terraform:deploy-vm ENV=<env> VM=<key>`
  - Destroy VM: `task terraform:destroy-vm ENV=<env> VM=<key>` (with confirmation dialog)
  - Destroy All: `task terraform:destroy ENV=<env>` (with confirmation dialog)
  - Clean: `task terraform:clean ENV=<env>`
- HCL parsing/writing via `python-hcl2` for reading, custom writer for output (python-hcl2 doesn't write)
- When creating/editing a VM, also update the ansible inventory (`hosts.ini`) if a group mapping is provided

#### 8. Packer Screen
- Auto-discover templates from `packer/templates/*.pkr.hcl` by scanning the directory
- Display available templates in a DataTable with: template name (derived from filename)
- On selection: execute `task packer:build TEMPLATE=<template> ENV=<env>`
  - Or the distro-specific variants: `task packer:build-ubuntu`, `task packer:build-debian`
- Output streams to the Output screen

#### 9. Output Screen (Multi-Pane)
- Support **multiple concurrent** command outputs
- Each running/completed command gets its own scrollable pane or tab
- Display: command description, status (running/completed/failed), return code, timestamps
- Use `RichLog` widget for streaming output
- Allow clearing individual output panes
- Show running command count in the tab bar badge

## Task Execution Engine

Build a robust async task runner:

```python
class TaskRunner:
    """Manages async subprocess execution."""
    - Execute commands as async subprocesses
    - Stream stdout/stderr line-by-line via callbacks
    - Track execution state: RUNNING, COMPLETED, FAILED, CANCELLED
    - Support multiple concurrent executions
    - Record: command, description, status, return_code, start_time, end_time
    - All task commands are executed via the `task` CLI
    - Always pass ENV=<current_environment> to task commands
```

All operations in the TUI should shell out to `task <taskname> ENV=<env> [EXTRA_VARS]`. The task binary is available in the container PATH. The task runner executes from the project root directory (where `Taskfile.yaml` lives).

## Environment Discovery and Switching

- **Discovery**: scan `ansible/environments/` for subdirectories. Each directory name is an environment.
- **Global switch**: changing the environment reloads ALL data across all screens (VMs, hosts, tasks, etc.)
- Environment paths:
  - Terraform: `<project_root>/terraform/environments/<env>/`
  - Ansible: `<project_root>/ansible/environments/<env>/`
  - Packer: `<project_root>/packer/environments/<env>/`
- The `find_project_root()` function walks up from `__file__` looking for `Taskfile.yaml`

## Confirmation Dialogs

Show a confirmation dialog before any destructive operation:
- `terraform:destroy` / `terraform:destroy-vm`
- `terraform:clean`
- VM deletion from `vms.auto.tfvars`
- Any task with "destroy" or "clean" in the name

The dialog should clearly state what will happen and require explicit confirmation.

## Auto-Refresh Configuration

- DNS, NTP, Docker, and CA screens should auto-refresh
- Default interval: ~2 seconds for NTP, configurable for others
- Auto-refresh should pause when the screen is not active/visible
- No visual staleness indicator needed
- Refresh interval should be configurable (via a settings mechanism or in-app control)

## Docker Container

### Dockerfile

Base image: `ghcr.io/astral-sh/uv:python3.12-bookworm-slim`

System dependencies to install:
- `curl`, `unzip`, `git`, `openssh-client`, `gnupg`, `software-properties-common`

Tools to install:
- **go-task**: `sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b /usr/local/bin`
- **Terraform**: via HashiCorp apt repo
- **Ansible**: `uv tool install ansible-core`

Workdir: `/homelab/tui`

Create a placeholder `Taskfile.yaml` at `/homelab/` so the image works standalone.

UV setup:
- `UV_COMPILE_BYTECODE=1` for faster startup
- `UV_LINK_MODE=copy` since it's a mounted volume
- Two-stage sync: deps first (cached), then project install

PATH: `/homelab/tui/.venv/bin:/root/.local/bin:$PATH`

Reset entrypoint (base image sets one for uv). CMD: `["homelab-tui"]`

### Docker Compose (compose.yml)

```yaml
services:
  tui:
    build:
      context: .
    image: homelab-tui
    stdin_open: true
    tty: true
    volumes:
      # Mount project root
      - ..:/homelab
      # Preserve container .venv
      - /homelab/tui/.venv
      # Mount SSH keys for accessing VMs
      - ~/.ssh:/root/.ssh:ro
    develop:
      watch:
        - action: rebuild
          path: pyproject.toml
        - action: rebuild
          path: uv.lock
        - action: sync
          path: ./src
          target: /homelab/tui/src
```

## pyproject.toml

```toml
[project]
name = "homelab-tui"
version = "0.1.0"
description = "Terminal UI for homelab infrastructure management"
requires-python = ">=3.12"
dependencies = [
    "textual>=0.89.0",
    "python-hcl2>=4.3.0",
]

[project.scripts]
homelab-tui = "homelab_tui.app:main"

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.hatch.build.targets.wheel]
packages = ["src/homelab_tui"]
```

## File/Module Structure

Suggested layout (adapt as needed):

```
src/homelab_tui/
├── __init__.py
├── app.py                    # Main App class, screen routing, global keybindings
├── config.py                 # Project root discovery, environment path resolution
├── css/
│   └── app.tcss              # Textual CSS styles
├── data/
│   ├── __init__.py
│   ├── discovery.py          # Dynamic discovery: tasks, environments, templates
│   ├── environment.py        # Load environment state (VMs, hosts, playbooks)
│   ├── hcl_parser.py         # Parse/write HCL terraform variables
│   ├── inventory_parser.py   # Parse/write Ansible hosts.ini
│   ├── tfstate_reader.py     # Read terraform.tfstate for VM status
│   └── models.py             # Dataclasses: VMConfig, VMState, Environment, etc.
├── screens/
│   ├── __init__.py
│   ├── dashboard.py          # Dashboard overview screen
│   ├── dns.py                # DNS query screen (auto-refresh)
│   ├── ntp.py                # NTP tracking/sources screen (auto-refresh)
│   ├── ca.py                 # Certificate Authority screen
│   ├── docker_view.py        # Docker aggregated view screen
│   ├── tasks.py              # Task browser/executor screen
│   ├── terraform.py          # VM CRUD + terraform operations
│   ├── packer.py             # Packer template builder screen
│   └── output.py             # Multi-pane command output viewer
├── widgets/
│   ├── __init__.py
│   ├── env_selector.py       # Global environment selector widget
│   ├── confirm_dialog.py     # Confirmation modal for destructive ops
│   ├── vm_edit_modal.py      # VM create/edit form modal
│   └── task_input_modal.py   # Modal for task variable input (VM=, CSR=, etc.)
└── task_runner/
    ├── __init__.py
    ├── runner.py              # Async subprocess execution engine
    └── registry.py            # Maps operations to task CLI commands
```

## Key Implementation Notes

1. **HCL Writing**: `python-hcl2` can parse HCL but cannot write it. You need a custom HCL writer that produces clean, formatted output matching the existing style in `vms.auto.tfvars`.

2. **Inventory Writing**: the `hosts.ini` parser/writer must preserve comments and the `[group:children]` structure when adding/removing hosts.

3. **SSH from Container**: the container mounts `~/.ssh:/root/.ssh:ro` so SSH to VMs works. The SSH user is typically `sfcal` (found in VM definitions). For NTP/DNS/Docker screens, use `asyncio.create_subprocess_exec` with `ssh`.

4. **Task Execution**: all operations go through `task <name> ENV=<env>`. The `task` binary is in `/usr/local/bin/`. Commands run from the project root (`/homelab/` inside the container).

5. **Auto-refresh**: use Textual's `set_interval` or `set_timer` for periodic data refresh. Pause timers when the screen is not active. The refresh interval should be user-configurable.

6. **Concurrent Output**: the Output screen must handle multiple simultaneous command executions. Each gets its own output pane with independent scrolling.

7. **Error Handling**: SSH connections may fail (host down), task commands may fail, terraform state may not exist yet. Handle all gracefully with user-visible error messages, never crash.

8. **Responsive Layout**: the TUI should work well in standard terminal sizes (80x24 minimum, optimized for larger terminals).
