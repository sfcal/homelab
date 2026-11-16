# Hermes Agent

[Hermes Agent](https://hermes-agent.nousresearch.com/docs/) runs on the Mac mini in wil (`10.2.0.10`, user `smithers`), installed directly on macOS so it can send and receive iMessages. It uses your Claude subscription through Nous Research's [Claude Subscription DirectSDK plugin](https://github.com/NousResearch/hermes-official-plugins/tree/main/claude-subscription-directsdk), which runs the official Claude Code CLI, so it needs no API key.

```bash
task ansible:deploy-hermes ENV=wil   # Updates Hermes, the web UI, Claude Code and the plugin; installs the skills and services
```

The agent's terminal and file tools run as `smithers`. They can reach everything that user can: its files, the wil network and the Mac's own Apple ID. They can't reach your Apple ID, which is never signed in on this Mac.

## Set up the Mac

Do this once, by hand, at the Mac's desktop (through Kasm or the PiKVM). The playbook stops with a pointer to this page if Hermes or Claude Code is missing.

1. **Developer tools:** run `xcode-select --install` and click Install. This gives the Mac `git` and `python3`.
2. **Apple ID:** create one for the Mac mini and sign in under System Settings, with iCloud Drive and Messages on. Hermes ignores messages sent from the Mac's own account, so it can't share yours.
3. **Power:** keep it awake and have it start again after a power cut.

    ```bash
    sudo pmset -a sleep 0 disksleep 0 autorestart 1
    ```

4. **The `/opt/data` link:** Hermes ran in a container before, where its folder was `/opt/data`. Its own scheduled jobs and scripts still use that path.

    ```bash
    sudo mkdir -p /opt && sudo ln -s /Users/smithers/.hermes /opt/data
    ```

5. **Hermes and Claude Code:**

    ```bash
    curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --skip-setup
    curl -fsSL https://claude.ai/install.sh | bash
    ```

6. **Sign in to Claude:** run this in Terminal on the Mac's desktop, not over SSH. The login is kept in the Keychain, which an SSH session can't unlock.

    ```bash
    claude auth login
    ```

Then run the deploy.

If every chat fails with "Claude Code is installed but has no usable login", the gateway is running outside the desktop session, where it can't open the Keychain. This happens when the service is started over SSH. Run the deploy: it moves the gateway, the web UI and node-exporter into the desktop session.

## Use

```bash
ssh smithers@10.2.0.10
hermes                   # Chat
hermes model             # Change the model (the first deploy sets Opus 5.5)
hermes gateway setup     # Connect Telegram, iMessage and so on
hermes gateway restart   # After changing a connection
hermes status
```

## Web UI

[Hermes WebUI](https://github.com/nesquena/hermes-webui) runs next to the agent, at <https://hermes.wil.5am.cloud> behind the [login](networking/sso.md). It shows the same chats, skills, scheduled jobs and memory as the agent, because both read `~/.hermes`.

A chat typed in the browser runs in the agent, not in the web UI (`HERMES_WEBUI_CHAT_BACKEND=gateway`): the web UI passes it to the agent's API server on port 8642, which only the Mac itself can reach. So browser chats use the same Claude login, plugin, skills and tools as Telegram and iMessage, and draw from the same usage limits. The API server's key is the `API_SERVER_KEY` line in `~/.hermes/.env`.

- **Login:** the web UI has no password of its own. Caddy's login check covers the name, but port 8787 on the Mac answers anyone on the wil network without it. Set a password under Settings > System if that matters.
- **Service:** the LaunchAgent `cloud.5am.hermes-webui` runs `~/hermes-webui/start.sh`. Its logs are `launchd-stdout.log` and `launchd-stderr.log` in `~/.hermes/webui`.
- **Versions:** each deploy moves the web UI to its newest release, in the same run that updates Hermes, because the two have to keep pace.

## Telegram

Hermes polls Telegram, so this opens no ports. Create a bot with @BotFather (`/newbot`) and get your numeric user ID from @userinfobot. Then run the wizard on the Mac, choose Telegram and **Manual**, and enter the token and your ID when asked. Only the IDs you list can use the bot.

```bash
hermes gateway setup
hermes gateway restart
```

The token stays in `~/.hermes/.env` on the Mac, not in the repo, so a rebuilt Mac needs this again. The wizard's Automatic option is less work, but the token then comes through a service Nous Research hosts.

## iMessage

[BlueBubbles Server](https://bluebubbles.app) runs on the Mac next to Messages and gives Hermes an address to send and receive through. Install it by hand:

1. Download `BlueBubbles-<version>-arm64.dmg` from its [releases](https://github.com/BlueBubblesApp/bluebubbles-server/releases) (1.9.10 or newer) and open it.
2. Grant it Full Disk Access, and Accessibility if it asks.
3. For the connection, choose the local network address with no proxy service, and set a password. Skip the Private API.
4. In its settings, turn on start at login and keep macOS awake.
5. On the **API & Webhooks** page, turn on **Allow API webhooks to reach local network addresses**. Hermes registers its own webhook, and without this switch BlueBubbles refuses it.

Then connect Hermes: run the wizard, choose BlueBubbles, and enter `http://127.0.0.1:1234`, the password, and your own number or address as the allowed user.

```bash
hermes gateway setup
hermes gateway restart
```

Text the Mac mini's Apple ID from your phone to try it.

- **Password:** it stays in `~/.hermes/.env` on the Mac, not in the repo.
- **Texts arrive but get no answer:** BlueBubbles posts each new message to `http://localhost:8645`, which on this Mac is the IPv6 address `::1`. The deploy sets `BLUEBUBBLES_WEBHOOK_HOST=localhost` so Hermes listens on both loopback addresses. BlueBubbles' log (`~/Library/Logs/bluebubbles-server/main.log`) shows `ECONNREFUSED ::1:8645` when this is missing.
- **Private API:** it adds typing indicators, tapbacks and read receipts, but needs System Integrity Protection turned off and has open bugs on macOS 26 and 27. Text, pictures and files work without it.
- **Who can text it:** only the users you list. Anyone else gets a pairing code, which you approve with `hermes pairing approve bluebubbles <code>`.

## iCloud Drive folders

Hermes sees only the folders you share with the Mac mini's Apple ID. In Finder on your own Mac, Control-click a folder in iCloud Drive, choose to share it with that Apple ID as invite-only, and pick **Can edit** or **Can view or download**. Accept the invitation on the Mac mini. The folder then appears there under `~/Library/Mobile Documents/com~apple~CloudDocs/`.

- **Limits:** the permission covers everything in the folder. With **Can edit**, Hermes can also overwrite or delete what's in it.
- **Take it back:** Control-click the folder and choose Manage Shared Folder. Copies Hermes already made stay on the Mac.
- **First use:** macOS may ask on the Mac's screen whether Hermes may read iCloud Drive. Allow it once.

## Fix Plex problems

Text the bot about something on Plex, such as a failed download, bad sound or the wrong HDR format. The `plex-fix` skill checks the file and how Plex is playing it, suggests a replacement and asks before grabbing it. The old file stays until the new one imports, and Hermes checks back about 30 minutes later. `/plex-fix` also starts it.

Hermes reaches Radarr, Sonarr and Plex on `10.2.0.5`, on the same network, using the keys in `group_vars/site_wil/secrets.sops.yml` (section `app_hermes`). These are copies of the keys Homepage uses, so update both if you rotate one.

- **Format preference:** SDR or HDR10 first, and no Dolby Vision-only files. Change this in `SKILL.md`.
- **Limits:** Hermes can't hear or see a file, so sound fixes are best guesses. If a replacement ranks lower than the current file, Radarr or Sonarr refuses the import and the old file stays. Hermes can't finish a manual import either.
- **Safety:** the keys can delete anything. An `approvals.deny` rule blocks `DELETE` calls to the media server from the terminal, but it's a seat belt rather than a hard limit.
- **Recycle bin:** Radarr and Sonarr move replaced files to `/data/recycle/<app>` on the NAS and remove them after 7 days. This is set in each app under Settings > Media Management, not in this repo.

## Sort email

The `fastmail-triage` skill sorts what the Fastmail sieve leaves in the Inbox into Receipts, Finance, Subscriptions, Notifications and Newsletters. It runs on Mondays. At 08:00 London time a model with no tools classifies senders and subject lines, and at 08:30 a script checks those answers, moves the mail and sends a report to Telegram. Message bodies are never read.

A deploy installs the skill and both jobs. Create the token by hand, once: in Fastmail, go to Settings > Privacy & Security > Connected apps & API tokens > Manage API tokens, and make a JMAP token with only **Email** ticked. Then paste it at the hidden prompt:

```bash
ssh -t smithers@10.2.0.10 '~/.local/bin/python3 ~/.hermes/skills/email/fastmail-triage/scripts/fastmail_triage.py set-token'
```

The token stays on the Mac, not in the repo, so a rebuilt Mac needs this again.

A new install only reports what it would move. Check the setup, try a run, and turn on moving when the report looks right:

```bash
ssh smithers@10.2.0.10
python3 ~/.hermes/skills/email/fastmail-triage/scripts/fastmail_triage.py check
hermes cron run fastmail-triage-decide
hermes cron run fastmail-triage-apply
python3 ~/.hermes/skills/email/fastmail-triage/scripts/fastmail_triage.py mode apply
```

After that, text the bot to sort now, show the last report, undo a sort, or always file a sender somewhere.

- **What it can do:** move mail out of the Inbox into those five folders, up to 150 messages a run and 40 per sender. Every move can be undone. It holds back people, conversations, flagged mail and subjects about payments, security and other matters on its protected lists.
- **Personal settings:** your addresses, protected senders and the phrases that say something about your life are in `hermes_fastmail_site_config` in `group_vars/site_wil/secrets.sops.yml` (section `app_hermes`), because this repo is public. Keep them out of `default-config.json`. The scan refuses to run if they're missing.
- **Safety:** mail text only reaches a model with no tools, so a hostile subject line has nothing to act with. Reports carry counts and short sender addresses, never subject lines. Fastmail's Email scope can also delete mail, and the agent's terminal could read the token file, so don't ask Hermes to read mail text in chat.
- **History:** Hermes saves each job's prompt, and a chat search can find it. The 08:30 job deletes those prompts, and the report says if that fails, so subject lines are searchable for about 30 minutes each week.

The design notes are in `references/design.md`, and `python3 -I ansible/playbooks/apps/hermes/tests/test_fastmail_triage.py` runs the offline tests.

## Update Grist

The `grist` skill lets Hermes read and update tables in [Grist](docker.md#grist), for example a finance tracker: "add 54.20 groceries from checking to Finance in Grist". It looks at the table's columns first, then adds rows or changes one row, and tells you what Grist stored, calculated columns such as a balance included. Each value is checked against its column before anything is sent: a date must be a date, a number a number, a choice one of the column's choices. If one value doesn't fit, nothing is written.

Hermes talks to Grist's own port on ldn's `work` VM over the link between the sites (`GRIST_URL` in its `.env`), because the name has the Kanidm login in front, which a script can't pass. The port is `hermes_grist_port` in `group_vars/site_wil/app_hermes/vars.yml`, a copy of the one in ldn's registry. It logs in with your account's API key. A deploy installs the skill; make the key by hand, once: open <https://grist.ldn.5am.cloud/account/developer> and click **Create** under API Key. Then give it to Hermes at a hidden prompt:

```bash
ssh -t smithers@10.2.0.10 '~/.local/bin/python3 ~/.hermes/skills/productivity/grist/scripts/grist.py set-token'
```

The key stays on the Mac, not in the repo, so a rebuilt Mac needs this again. A Grist account has one key: **Remove** on that page cuts Hermes off, and a new key has to be given to Hermes again.

- **Limits:** rows only. Hermes can't make documents, tables or columns, and can't delete rows: set the table up in Grist yourself. It reads the rows added most recently, not the table in the order you sorted it.
- **Safety:** the key can do everything your Grist account can, in every document, deleting included. The skill has no delete command and is told to add, not rearrange, which is a seat belt rather than a hard limit.

## Usage limits

Hermes [draws from your subscription's usage limits](https://support.claude.com/en/articles/15036540-use-the-claude-agent-sdk-with-your-claude-plan), the same limits as your other Claude use. Turn off extra usage in your Claude account if you don't want overage billing.

Nous Research labels the plugin experimental. Hermes' built-in `anthropic` provider isn't used because its Claude sign-in only spends extra-usage credits on a Max plan.

## After a restart

The Mac's disk is encrypted (FileVault), so after a restart it waits for the `smithers` password. Type it through the PiKVM. Unlocking the disk also logs `smithers` in, and the gateway, the web UI, BlueBubbles and node-exporter then start by themselves.

Until someone unlocks it, Hermes answers nothing. wil's Prometheus scrapes the Mac's node-exporter on port 9100, so a Mac that is off, asleep or waiting at the unlock screen raises the [Target down alert](monitoring/index.md) after 5 minutes.

## Updates

Run `task ansible:deploy-hermes ENV=wil` to update everything. Nothing is pinned, so Renovate has nothing to bump here, and `app_hermes` isn't on the [auto-deploy allowlist](../guides/gitops.md#auto-deploy-allowlist).

- **Hermes, the web UI, Claude Code and the plugin:** each deploy moves all four to their current release. Claude Code doesn't update itself here, because the plugin turns that off.
- **Skills:** each deploy copies the repo's skills over the Mac's. Hermes can edit its own skills as it learns, and a deploy overwrites those edits, so copy any you want to keep into the repo first. `hermes curator ledger` lists them, and earlier versions are in `~/.hermes/.curator_backups/blobs`. `fastmail-triage` is locked, so Hermes can't edit it.
- **macOS and BlueBubbles:** update these by hand. BlueBubbles can install its own updates from its tray menu.

## Files

| Path | Purpose |
|------|---------|
| `ansible/playbooks/apps/hermes/deploy.yml` | Playbook (group `app_hermes`); runs as `smithers`, without root |
| `ansible/playbooks/apps/hermes/files/plex-fix/` | The `plex-fix` skill and its helper script |
| `ansible/playbooks/apps/hermes/files/fastmail-triage/` | The `fastmail-triage` skill, its public defaults and design notes |
| `ansible/playbooks/apps/hermes/files/grist/` | The `grist` skill and its helper script |
| `ansible/playbooks/apps/hermes/files/*.plist` | The web UI and node-exporter services |
| `ansible/playbooks/apps/hermes/tests/` | Offline tests for `fastmail-triage` |
| `ansible/inventory/group_vars/site_wil/app_hermes/vars.yml` | Where the email report goes, Grist's port and the node-exporter release |
| `ansible/inventory/group_vars/site_wil/proxy/wil.5am.cloud.yml` | DNS and Caddy entry `hermes` for the web UI |
| `ansible/inventory/group_vars/site_wil/secrets.sops.yml` | Section `app_hermes`: Radarr, Sonarr and Plex keys, and your addresses and private protection lists for `fastmail-triage` (`hermes_fastmail_site_config`) |
| `~/.hermes` on the Mac (also `/opt/data`) | Hermes's code, config, chats, memory, skills and its own scripts |
| `~/.hermes/data/fastmail-triage` on the Mac | The Fastmail token, private settings, undo journals and last report |
| `~/hermes-webui` on the Mac | The web UI's code |
| `~/Library/LaunchAgents` on the Mac | `ai.hermes.gateway`, `cloud.5am.hermes-webui` and `cloud.5am.node-exporter` |
