# Task Commands

<!-- TODO: expand with full command reference -->

Available commands via the [Task](https://taskfile.dev/) runner.

## Ansible Tasks

| Command | Description |
|---------|-------------|
| `task ansible:deploy-all` | Deploy entire infrastructure |
| `task ansible:deploy-services` | Deploy DNS and reverse proxy |
| `task ansible:deploy-media` | Deploy media stack |
| `task ansible:deploy-monitoring` | Deploy Prometheus + Grafana |
| `task ansible:deploy-games` | Deploy Terraria server |
| `task ansible:deploy-website` | Deploy personal website |
| `task ansible:deploy-birdle` | Deploy Birdle game |
| `task ansible:ping` | Test connectivity to all hosts |
| `task ansible:backup-media` | Backup media stack configs |
| `task ansible:restore-media` | Restore media stack from backup |

## Terraform Tasks

| Command | Description |
|---------|-------------|
| `task terraform:deploy` | Apply infrastructure changes |
| `task terraform:destroy` | Tear down infrastructure |
| `task terraform:clean` | Clean up Terraform state |

## Packer Tasks

| Command | Description |
|---------|-------------|
| `task packer:build` | Build VM templates |

## Other

| Command | Description |
|---------|-------------|
| `task tui` | Launch the homelab management TUI |
