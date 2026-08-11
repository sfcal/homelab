# Deploy a Service

Add a new application to the homelab. Most apps use a shared data-driven pattern — define the app in `apps.yml` and provide a Docker Compose template.

## Data-Driven Apps (Recommended)

Most applications follow this pattern. The shared `deploy-app.yml` playbook handles everything.

### 1. Add the App to `apps.yml`

Add an entry to `ansible/environments/<env>/group_vars/all/apps.yml`:

```yaml
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

There is no `images:` list — the pre-pull list is derived from every key ending in `image`. Keep the `# renovate: datasource=docker` comment directly above the image key and double-quote the value so Renovate can update it. Omit the `proxy:` block if the app needs no DNS or proxy entry.

### 2. Create the Compose Template

Create `ansible/playbooks/apps/myapp/templates/compose.yaml.j2`:

```yaml
services:
  myapp:
    image: {{ apps.myapp.image }}
    container_name: myapp
    restart: unless-stopped
    ports:
      - "{{ apps.myapp.port }}:8080"
    environment:
      PUID: "{{ puid }}"
      PGID: "{{ pgid }}"
```

### 3. Add to Ansible Inventory

Add a host group to `ansible/environments/<env>/hosts.ini`:

```ini
[app_myapp]
10.2.20.60

[apps:children]
# ... existing groups ...
app_myapp
```

### 4. Add the Import to `site.yml`

Add the app to `ansible/playbooks/site.yml`:

```yaml
- ansible.builtin.import_playbook: deploy-app.yml
  vars:
    app_name: myapp
```

### 5. Task Command

No new task is needed — the shared `deploy-app` task in `.taskfiles/ansible/Taskfile.yaml` deploys any registry app by name:

```yaml
deploy-app:
  desc: "Deploy an app by name (APP=<name>)"
  cmds:
    - task: _deploy
      vars: { PLAYBOOK_PATH: deploy-app.yml, EXTRA_ARGS: '-e app_name={{.APP}} -e @{{.APPS_FILE}}' }
```

Dedicated tasks (e.g., `deploy-media`) exist only for apps with custom playbooks.

### 6. DNS/Proxy Entry

The `proxy:` block from step 1 already covers this — `backend_host` and `backend_port` are derived from the app's `host_group` and `port`, and the entry is generated when networking is deployed. Manual entries in `group_vars/all/proxy/<domain>.yml` are only for services outside the app registry (third-party devices, media stack, monitoring).

### 7. Deploy

```bash
task ansible:deploy-app ENV=wil APP=myapp
task ansible:deploy-networking ENV=wil  # Updates DNS and proxy
```

## Custom Playbooks

For apps that need more than Docker Compose (e.g., media stack with backup/restore), create a full playbook at `ansible/playbooks/apps/<service>/deploy.yml`:

```yaml
---
- name: Deploy My Service
  hosts: app_myservice
  become: true

  handlers:
    - name: Include handlers
      ansible.builtin.import_tasks: handlers/main.yml

  pre_tasks:
    - name: Include common prerequisites
      ansible.builtin.include_role:
        name: common

  tasks:
    - name: Deploy service
      ansible.builtin.include_tasks: tasks/deploy.yml
```

## If You Need a New VM

See [Add a New VM](add-vm.md) first, then come back here after the VM is provisioned.

## Troubleshooting

**App not accessible** — Check the app's `proxy:` block has `proxied: true` and redeploy networking. Verify the container is running: `ssh <host> docker ps`.

**Container won't start** — Check logs: `ssh <host> docker logs myapp`. Common issues: port conflicts, missing environment variables, image pull failures.

**DNS not resolving** — Ensure the app has a `proxy:` block in `apps.yml` (or, for non-catalog services, an entry in the correct domain file) and redeploy networking: `task ansible:deploy-networking ENV=wil`.
