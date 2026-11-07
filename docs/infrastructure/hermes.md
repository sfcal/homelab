# Hermes Agent

[Hermes Agent](https://hermes-agent.nousresearch.com/docs/) runs on its own VM in ldn, `hermes` (`10.3.20.80`, VM 3008), from the official Docker image. It uses your Claude subscription through Nous Research's [Claude Subscription DirectSDK plugin](https://github.com/NousResearch/hermes-official-plugins/tree/main/claude-subscription-directsdk), which runs the official Claude Code CLI, so it needs no API key.

```bash
task terraform:deploy-vm ENV=ldn VM=hermes_server   # The VM
task ansible:deploy-hermes ENV=ldn                  # Hermes, Claude Code and the plugin
```

## Sign in to Claude

Do this once, by hand. Open the URL it prints, sign in and paste the code back:

```bash
ssh sfcal@10.3.20.80
docker exec -it -u hermes hermes claude auth login
```

The login stays in the data directory, so it survives redeploys and new images. Keep `-u hermes`: without it the command runs as root and saves the login where Hermes doesn't look.

## Use

```bash
docker exec -it hermes hermes                 # Chat
docker exec -it hermes hermes model           # Change the model (the first deploy sets Opus 5.5)
docker exec -it hermes hermes gateway setup   # Connect Telegram, Discord and so on
```

No ports are published, so there is no web UI and no DNS or Caddy entry. The agent's terminal and file tools run inside the container as UID 10000, with no access to the Docker socket.

## Telegram

Hermes polls Telegram, so this opens no ports. Create a bot with @BotFather (`/newbot`) and get your numeric user ID from @userinfobot. Then run the wizard on the VM, choose Telegram and **Manual**, and enter the token and your ID when asked. Only the IDs you list can use the bot.

```bash
docker exec -it hermes hermes gateway setup
docker restart hermes
```

Always run the `docker restart` afterwards: in this container the wizard's own restart only stops the gateway, and Telegram stays disconnected until the container restarts.

The token stays in `/var/lib/hermes/data/.env` on the VM, not in the repo, so a rebuilt VM needs this again. The wizard's Automatic option is less work, but the token then comes through a service Nous Research hosts.

## Fix Plex problems

Text the bot about something on Plex, such as a failed download, bad sound or the wrong HDR format. The `plex-fix` skill checks the file and how Plex is playing it, suggests a replacement and asks before grabbing it. The old file stays until the new one imports, and Hermes checks back about 30 minutes later. `/plex-fix` also starts it.

Hermes reaches Radarr, Sonarr and Plex on `10.2.0.5` over the site tunnel, using the keys in `group_vars/app_hermes/secrets.sops.yml`. These are copies of the keys Homepage uses in wil, so update both if you rotate one.

- **Format preference:** SDR or HDR10 first, and no Dolby Vision-only files. Change this in `SKILL.md`.
- **Limits:** Hermes can't hear or see a file, so sound fixes are best guesses. If a replacement ranks lower than the current file, Radarr or Sonarr refuses the import and the old file stays. Hermes can't finish a manual import either.
- **Safety:** the keys can delete anything. An `approvals.deny` rule blocks `DELETE` calls to the media server from the terminal, but it's a seat belt rather than a hard limit.
- **Recycle bin:** Radarr and Sonarr move replaced files to `/data/recycle/<app>` on the NAS and remove them after 7 days. This is set in each app under Settings > Media Management, not in this repo.

## Sort email

The `fastmail-triage` skill sorts what the Fastmail sieve leaves in the Inbox into Receipts, Finance, Subscriptions, Notifications and Newsletters. It runs on Mondays. At 08:00 London time a model with no tools classifies senders and subject lines, and at 08:30 a script checks those answers, moves the mail and sends a report to Telegram. Message bodies are never read.

A deploy installs the skill and both jobs. Create the token by hand, once: in Fastmail, go to Settings > Privacy & Security > Connected apps & API tokens > Manage API tokens, and make a JMAP token with only **Email** ticked. Then paste it at the hidden prompt:

```bash
ssh -t sfcal@10.3.20.80 docker exec -it -u hermes hermes python3 /opt/data/skills/email/fastmail-triage/scripts/fastmail_triage.py set-token
```

The token stays on the VM, not in the repo, so a rebuilt VM needs this again. Keep `-u hermes`, or Hermes can't read the file.

A new install only reports what it would move. Check the setup, try a run, and turn on moving when the report looks right:

```bash
ssh sfcal@10.3.20.80
docker exec -u hermes hermes python3 /opt/data/skills/email/fastmail-triage/scripts/fastmail_triage.py check
docker exec -u hermes hermes hermes cron run fastmail-triage-decide
docker exec -u hermes hermes hermes cron run fastmail-triage-apply
docker exec -u hermes hermes python3 /opt/data/skills/email/fastmail-triage/scripts/fastmail_triage.py mode apply
```

After that, text the bot to sort now, show the last report, undo a sort, or always file a sender somewhere.

- **What it can do:** move mail out of the Inbox into those five folders, up to 150 messages a run and 40 per sender. Every move can be undone. It holds back people, conversations, flagged mail and subjects about payments, security and other matters on its protected lists.
- **Personal settings:** your addresses, protected senders and the phrases that say something about your life are in `group_vars/app_hermes/fastmail.sops.yml`, because this repo is public. Keep them out of `default-config.json`. The scan refuses to run if they're missing.
- **Safety:** mail text only reaches a model with no tools, so a hostile subject line has nothing to act with. Reports carry counts and short sender addresses, never subject lines. Fastmail's Email scope can also delete mail, and the agent's terminal could read the token file, so don't ask Hermes to read mail text in chat.
- **History:** Hermes saves each job's prompt, and a chat search can find it. The 08:30 job deletes those prompts, and the report says if that fails, so subject lines are searchable for about 30 minutes each week.

The design notes are in `references/design.md`, and `python3 -I ansible/playbooks/apps/hermes/tests/test_fastmail_triage.py` runs the offline tests.

## Usage limits

Hermes [draws from your subscription's usage limits](https://support.claude.com/en/articles/15036540-use-the-claude-agent-sdk-with-your-claude-plan), the same limits as your other Claude use. Turn off extra usage in your Claude account if you don't want overage billing.

Nous Research labels the plugin experimental. Hermes' built-in `anthropic` provider isn't used because its Claude sign-in only spends extra-usage credits on a Max plan.

## Updates

Run `task ansible:deploy-hermes ENV=ldn` to update everything:

- **Hermes** — Renovate bumps `hermes_image`, but `app_hermes` isn't on the [auto-deploy allowlist](../guides/gitops.md#auto-deploy-allowlist), so the VM doesn't change until you deploy.
- **Skills** — each deploy copies the repo's skills over the VM's. Hermes can edit its own skills as it learns, and a deploy overwrites those edits, so copy any you want to keep into the repo first. `docker exec hermes hermes curator ledger` lists them, and earlier versions are in `/var/lib/hermes/data/.curator_backups/blobs`. `fastmail-triage` is locked, so Hermes can't edit it.
- **Claude Code and the plugin** — each deploy moves both to their current release. They live in the data directory, so a new image keeps them. Claude Code doesn't update itself here, because the plugin turns that off.

## Files

| Path | Purpose |
|------|---------|
| `ansible/playbooks/apps/hermes/deploy.yml` | Playbook (group `app_hermes`) |
| `ansible/playbooks/apps/hermes/templates/compose.yaml.j2` | Hermes container |
| `ansible/playbooks/apps/hermes/files/plex-fix/` | The `plex-fix` skill and its helper script |
| `ansible/playbooks/apps/hermes/files/fastmail-triage/` | The `fastmail-triage` skill, its public defaults and design notes |
| `ansible/playbooks/apps/hermes/tests/` | Offline tests for `fastmail-triage` |
| `ansible/environments/ldn/group_vars/app_hermes/vars.yml` | Hermes image and where the email report goes |
| `ansible/environments/ldn/group_vars/app_hermes/secrets.sops.yml` | Radarr, Sonarr and Plex keys |
| `ansible/environments/ldn/group_vars/app_hermes/fastmail.sops.yml` | Your addresses and private protection lists for `fastmail-triage` |
| `terraform/environments/ldn/vms.auto.tfvars` | VM definition (`hermes_server`) |
| `/opt/hermes` on the VM | `compose.yaml` |
| `/var/lib/hermes/data` on the VM | Hermes config, chats and memory, Claude Code, the plugin and the Claude login |
| `/var/lib/hermes/data/data/fastmail-triage` on the VM | The Fastmail token, private settings, undo journals and last report |
