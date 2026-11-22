# Hermes Agent

[Hermes Agent](https://hermes-agent.nousresearch.com/docs/) runs on the Mac mini in wil (`10.2.0.10`, user `smithers`) in two containers: the agent, from the official Docker image, and its web UI. [OrbStack](https://orbstack.dev) runs them. It uses your Claude subscription through Nous Research's [Claude Subscription DirectSDK plugin](https://github.com/NousResearch/hermes-official-plugins/tree/main/claude-subscription-directsdk), which runs the official Claude Code CLI, so it needs no API key.

```bash
task ansible:deploy-hermes ENV=wil   # Starts the containers, updates Claude Code and the plugin
```

The agent's terminal and file tools run inside the container as UID 10000, with no access to the Docker socket. Of the Mac's files they see one folder, `/Users/smithers/hermes/data` (`/opt/data` in the container). They reach the network as the Mac does.

## Set up the Mac

Do this once, by hand, at the Mac's desktop (through Kasm or the PiKVM). The playbook stops with a pointer to this page if OrbStack isn't running.

1. **Developer tools:** run `xcode-select --install` and click Install. This gives the Mac `python3`, which Ansible needs.
2. **Power:** keep it awake and have it start again after a power cut.

    ```bash
    sudo pmset -a sleep 0 disksleep 0 autorestart 1
    ```

3. **OrbStack:** download it from [orbstack.dev](https://orbstack.dev), drag it to Applications and open it. Choose Docker, and turn on **Start at login** in its settings. It is free for personal use.

Then run the deploy.

## Sign in to Claude

Do this once, by hand, after the first deploy. Open the URL it prints, sign in and paste the code back:

```bash
ssh -t smithers@10.2.0.10 '~/.orbstack/bin/docker exec -it -u hermes hermes claude auth login'
```

The login stays in the data folder, so it survives redeploys and new images. Keep `-u hermes`: without it the command runs as root and saves the login where Hermes doesn't look.

If every chat fails with "Claude Code is installed but has no usable login", sign in again.

## Use

```bash
ssh smithers@10.2.0.10
docker exec -it hermes hermes                 # Chat
docker exec -it hermes hermes model           # Change the model (the first deploy sets Opus 5.5)
docker exec -it hermes hermes gateway setup   # Connect Telegram, Discord and so on
docker exec hermes hermes status
```

## Web UI

[Hermes WebUI](https://github.com/nesquena/hermes-webui) is a second container in the same compose project, at <https://hermes.wil.5am.cloud> behind the [login](networking/sso.md). It shows the same chats, skills, scheduled jobs and memory as the agent, because both containers mount the data folder at `/opt/data`.

A chat typed in the browser runs in the `hermes` container, not in the web UI's (`HERMES_WEBUI_CHAT_BACKEND=gateway`): the web UI passes it to the agent's API server on port 8642, which only the compose network can reach. So browser chats use the same Claude login, plugin, skills and tools as Telegram, and draw from the same usage limits. The API server's key is the `API_SERVER_KEY` line in the data folder's `.env`; both containers read it from there.

- **Login:** the web UI has no password of its own. Caddy's login check covers the name, but port 8787 on the Mac answers anyone on the wil network without it. Set a password under Settings > System if that matters.
- **Agent code:** the web UI reads the agent's code from the agent image itself (an image mount in the compose file), so it follows `hermes_image`. Each time its container is created it copies that code and installs the agent's Python packages, which takes a few minutes; the page answers once that's done (`docker logs -f hermes-webui`).
- **Package overrides:** the agent's packages only install with the version overrides in its own `pyproject.toml` (`[tool.uv]`), which the web UI's installer doesn't read. The compose file's `command` copies that list to a file for `uv` (`UV_OVERRIDE`) before the web UI starts. Without it the container restarts in a loop with "No solution found when resolving dependencies".
- **Versions:** the web UI's authors test each release against the agent release of the same date, so merge Renovate's `hermes_image` and `hermes_webui_image` bumps together where you can.
- **Its own files:** `webui` in the data folder.

## Telegram

Hermes polls Telegram, so this opens no ports. Create a bot with @BotFather (`/newbot`) and get your numeric user ID from @userinfobot. Then run the wizard on the Mac, choose Telegram and **Manual**, and enter the token and your ID when asked. Only the IDs you list can use the bot.

```bash
docker exec -it hermes hermes gateway setup
docker restart hermes
```

Always run the `docker restart` afterwards: in this container the wizard's own restart only stops the gateway, and Telegram stays disconnected until the container restarts.

The token stays in the data folder's `.env` on the Mac, not in the repo, so a rebuilt Mac needs this again. The wizard's Automatic option is less work, but the token then comes through a service Nous Research hosts.

## Files on the Mac

Besides its data folder, Hermes sees one folder of the Mac: the `Documents` folder of the Mac's iCloud Drive, read-only, at `/mnt/icloud/Documents` in both containers. It can read what's there and can't change or delete it.

Two folders inside it are the exception: `Documents/Hermes` and `Documents/Projects/Homelab` are mounted a second time, writable, at `/mnt/icloud/Documents/Hermes` and `/mnt/icloud/Documents/Projects/Homelab`. Hermes can create, change and delete files there, and iCloud syncs them to your other devices. `Projects/Homelab` holds the checkout of this repo, so Hermes can change the playbooks you deploy from, its own included. Leave git to your own Mac: git run in the container on the same synced `.git` can leave iCloud conflict copies.

- **Another folder, or write access:** the folders are `volumes:` entries of both services in `templates/compose.yaml.j2`. Copy the `Documents` entry for another read-only folder or the `Documents/Hermes` entry for another writable one, and deploy.
- **File tools:** the image lets Hermes's file tools write under `/opt/data` only (`HERMES_WRITE_SAFE_ROOT`). The compose file sets it to `/opt/data` and the two writable folders; another writable folder has to be added to that list too, or Hermes can only write there from the shell.
- **Where to mount:** outside `/opt/data`. At each start the image fixes the ownership of everything under `/opt/data/home`; with a large folder mounted there it walks every file and the gateway doesn't start.
- **macOS asks first:** the first time OrbStack reads iCloud Drive, macOS shows a prompt on the Mac's screen. Until you click Allow, every read from a container hangs and can't be killed, and a container with a hung process can't be stopped: stop OrbStack itself (`orb stop`, then `orb start`).
- **Files still in iCloud:** a file or folder the Mac hasn't downloaded yet is fetched when Hermes first reads it. One file takes a second or two; a search through a large folder that has never been opened on this Mac can take very long.
- **Signed out of iCloud:** the folder disappears and the containers won't start until you sign in again or remove the entries. This is on purpose: Docker would otherwise create an empty folder inside iCloud Drive.

## Browser

Hermes has a Chromium with a window, for sites that need you to log in by hand. It runs next to Hermes as the container `tesco-chrome`, and its profile (logins, cookies) is the Docker volume `hermes_chrome-config`.

- **You:** open `https://10.2.0.10:3001` (the certificate is self-signed), user `hermes`, password `hermes_chrome_viewer_password` in wil's secrets. You see the same window Hermes uses, so log in to a site there and Hermes can use it afterwards.
- **Hermes:** drives it through `tesco-chrome-cdp-proxy` at `http://tesco-chrome:9223`, which is `browser.cdp_url` in its `config.yaml`. That port is not published: only the compose network reaches it.
- **Where it browses from:** ldn. Everything the browser loads goes through Squid on ldn's `web` VM (`apps.squid` in `site_ldn/apps.yml`, port 3128), because Tesco refuses wil's US address. Squid accepts only connections that arrive over the site link. If ldn or the link is down, the browser loads nothing.

## Skills

Hermes's skills aren't in this repo. They live in `skills` in the data folder on the Mac, and a deploy doesn't touch them. The playbook only gives them their keys and settings:

- **Radarr, Sonarr and Plex:** `RADARR_API_KEY`, `SONARR_API_KEY` and `PLEX_TOKEN` in the data folder's `.env`, from `group_vars/site_wil/secrets.sops.yml` (section `app_hermes`). These are copies of the keys Homepage uses, so update both if you rotate one. The keys can delete anything: an `approvals.deny` rule blocks `DELETE` calls to the media server from the terminal, but it's a seat belt rather than a hard limit.
- **Grist:** `GRIST_URL` in `.env` is Grist's own port on ldn's `work` VM, because the name has the Kanidm login in front, which a script can't pass. The port is `hermes_grist_port` in `group_vars/site_wil/app_hermes/vars.yml`, a copy of the one in ldn's registry.
- **Email sorting:** your addresses and protected senders, from `hermes_fastmail_site_config` in the same secrets file, because this repo is public. They go to `data/fastmail-triage/site-config.json` in the data folder.

The Fastmail token and the Grist API key were set by hand and stay on the Mac. A rebuilt Mac needs the skills and both of these again.

## Usage limits

Hermes [draws from your subscription's usage limits](https://support.claude.com/en/articles/15036540-use-the-claude-agent-sdk-with-your-claude-plan), the same limits as your other Claude use. Turn off extra usage in your Claude account if you don't want overage billing.

Nous Research labels the plugin experimental. Hermes' built-in `anthropic` provider isn't used because its Claude sign-in only spends extra-usage credits on a Max plan.

## After a restart

The Mac's disk is encrypted (FileVault), so after a restart it waits for the `smithers` password. Type it through the PiKVM. Unlocking the disk also logs `smithers` in, and OrbStack, both containers and node-exporter then start by themselves.

Until someone unlocks it, Hermes answers nothing. wil's Prometheus scrapes the Mac's node-exporter on port 9100, so a Mac that is off, asleep or waiting at the unlock screen raises the [Target down alert](monitoring/index.md) after 5 minutes.

## Updates

Run `task ansible:deploy-hermes ENV=wil` to update everything:

- **Hermes and the web UI:** Renovate opens a PR for each `hermes_image` and `hermes_webui_image` bump and never merges it itself, because `app_hermes` isn't on the [auto-deploy allowlist](../guides/gitops.md#auto-deploy-allowlist). Merge it when you deploy.
- **Claude Code and the plugin:** each deploy moves both to their current release. They live in the data folder, so a new image keeps them. Claude Code doesn't update itself here, because the plugin turns that off.
- **Skills:** not part of a deploy. Hermes edits its own skills as it learns. `docker exec hermes hermes curator ledger` lists them, and earlier versions are in `.curator_backups/blobs` in the data folder.
- **macOS and OrbStack:** update these by hand. OrbStack offers its own updates from its menu bar icon.

## Files

| Path | Purpose |
|------|---------|
| `ansible/playbooks/apps/hermes/deploy.yml` | Playbook (group `app_hermes`); runs as `smithers`, without root |
| `ansible/playbooks/apps/hermes/templates/compose.yaml.j2` | Hermes, web UI and browser containers |
| `ansible/playbooks/apps/hermes/files/cloud.5am.node-exporter.plist` | The node-exporter service |
| `ansible/inventory/group_vars/site_wil/app_hermes/vars.yml` | Hermes, web UI and browser images, Grist's port and the node-exporter release |
| `ansible/inventory/group_vars/site_wil/proxy/wil.5am.cloud.yml` | DNS and Caddy entry `hermes` for the web UI |
| `ansible/inventory/group_vars/site_wil/secrets.sops.yml` | Section `app_hermes`: Radarr, Sonarr and Plex keys, the password of the browser's viewer, and your addresses and private protection lists for `fastmail-triage` (`hermes_fastmail_site_config`) |
| `/Users/smithers/hermes` on the Mac | `compose.yaml` |
| `/Users/smithers/hermes/data` on the Mac | Hermes config, chats, memory, skills and its own scripts, Claude Code, the plugin and the Claude login |
| `/Users/smithers/hermes/data/data/fastmail-triage` on the Mac | The Fastmail token, private settings, undo journals and last report |
| `~/Library/LaunchAgents/cloud.5am.node-exporter.plist` on the Mac | node-exporter, which runs on macOS itself |
