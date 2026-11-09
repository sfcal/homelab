# Kasm Agent (OVH VPS)

ldn's Kasm (the LinuxServer image on the `work` VM, `10.3.20.50`) has a second Docker agent on the OVH VPS (site `ovh`, `135.148.219.216`, tailnet `100.116.40.99`). It was set up for the **Deluge** workspace, so its torrent traffic would leave from the VPS's IP. Since 2026-11-09 Deluge runs on the work VM instead, with a custom image ([Docker Services → Kasm](docker.md#deluge)); the agent and its Deluge folders on the VPS stay in place.

```bash
task ansible:deploy-kasm-agent ENV=ovh
```

The playbook (`playbooks/apps/kasm-agent/`) installs the official Kasm 1.18.1 agent, the same version as the work VM's Kasm, with its release checked against a pinned sha256. It runs the installer once, and Kasm's own `upgrade.sh` handles later versions. It also:

- creates a 2 GB swap file (`/mnt/Kasm.swap`), which the installer asks for;
- installs `kasm-agent-guard`, an nftables table that drops the agent's port (4443) on the public interface before Docker's port forwarding sees it, so only the tailnet reaches the agent;
- creates Deluge's folders under `/var/lib/kasm-agent/deluge/`.

Values: `group_vars/site_ovh/app_kasm_agent/vars.yml`. The manager token is in the `app_kasm_agent` section of `site_ovh/secrets.sops.yml` (a copy of the token the work VM's own agent uses).

## Network

- **Agent → Kasm:** `10.3.20.50:4443` over the tailnet (the VPS accepts ldn's subnet route).
- **Kasm → agent:** `100.116.40.99:4443`. The ldn UDM has a static route for `100.116.40.99/32` via ldn-gateway (`10.3.20.53`); without it, sessions don't start.
- **One port for both:** the installer uses its `--proxy-port` both for the agent's own port and for reaching Kasm, so the agent uses Kasm's port, 4443.

## Settings in Kasm's admin (not in this repo)

| Where | Setting | Why |
|-------|---------|-----|
| Infrastructure → Docker Agents | `100.116.40.99` enabled | The VPS agent |
| Infrastructure → Deployment Zones → default | Upstream Auth Address `10.3.20.50` (was `proxy`) | Each agent's proxy checks the login at this address. `proxy` only resolves inside the work VM's Kasm; on the VPS it is the agent's own proxy, so sessions there failed with a 404 on `/api/internal_auth/` |
| Workspaces → FileZilla, Tor-Browser | Restrict Image to Kasm Agent: `85a6c3` (the work VM) | Keeps them off the VPS. A new agent pulls the image of every unrestricted workspace, so restrict any new container workspace too |
| Access Management → Groups → All Users → Settings | `keepalive_expiration` 604800 (was 3600) | See Sessions below |
| Workspaces → Deluge (until 2026-11-09) | Restrict Image to Kasm Agent `a67ee6`, Memory 2048 MB, Volume Mappings `/var/lib/kasm-agent/deluge/downloads` → `/home/kasm-user/Downloads` and `/var/lib/kasm-agent/deluge/config` → `/home/kasm-user/.config` (uid/gid 1000) | How Deluge ran on the VPS. Map all of `~/.config`, not `~/.config/deluge`: Docker would create `~/.config` as root, and the image's startup script then fails copying its default profile there (the container exits at once). Not for the custom image, which keeps its settings in the image |

## Sessions

Deluge only downloads while its session exists. Kasm deletes a session `keepalive_expiration` seconds after its browser tab last sent a keepalive (`keepalive_expiration_action: delete`). Group **All Users** has it at **604800 (one week)**, raised from 3600 on 2026-11-07 so Deluge keeps downloading with the tab closed. Kasm group settings can't be limited to one workspace, so every session of the group lasts that long; your account falls back to All Users because Administrators sets nothing here. A session picks up a new value at its next keepalive, which reopening it sends.

With the custom image on the work VM, an expired Deluge session takes its torrents and archives with it (nothing is mapped to the host).
