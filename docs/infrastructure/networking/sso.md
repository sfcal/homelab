# Single Sign-On (Kanidm)

[Kanidm](https://kanidm.com) on the OVH VPS is the one login for both sites, at `https://auth.5am.cloud`. It is reachable only over the tailnet. A proxied service opts in with `auth: true` in its [service definition](proxy.md#auth), on any domain. On each site's networking VM, [oauth2-proxy](https://oauth2-proxy.github.io/oauth2-proxy/) runs next to Caddy as the login check.

## How It Works

1. Caddy asks oauth2-proxy before proxying a flagged service.
2. No session for that domain: the browser is sent to Kanidm and comes back to the page it asked for.
3. oauth2-proxy then sets a cookie for the service's domain, so the other flagged services on that domain open directly.
4. The first visit to a flagged service on another domain passes through Kanidm without asking for the password again.

The login is a gate in front of a service, not a replacement for its own login: a service that has its own (the NAS, for example) still asks for it. Sonarr, Radarr, Prowlarr, SABnzbd and Pulsarr have theirs turned off. [Proxmox](#proxmox), the [backup server](#proxmox-backup-server) and [Kasm](#kasm) log in to Kanidm themselves.

| Piece | Where |
|-------|-------|
| Kanidm | OVH VPS, in the dashboard compose project: config `/opt/dashboard/kanidm/server.toml`, state `/var/lib/dashboard/kanidm` |
| `auth.5am.cloud` | `100.116.40.99`, the VPS's tailnet address. `tailscale serve --tcp=443` passes it to the VPS's Caddy on `127.0.0.1:8443`, which proxies to Kanidm |
| oauth2-proxy | Each networking VM, `/opt/oauth2-proxy`, client `oauth2-proxy-<site>` |
| kanidm-mail-sender | OVH VPS, next to Kanidm: sends its mail through Fastmail as `noreply@5am.cloud` ([Password Reset by Email](#password-reset-by-email)) |

The name is in wil's BIND (zone `5am.cloud`, copied to ldn) and in the tailnet's split DNS, never in Cloudflare. The VPS's public address closes any connection for it.

## File Locations

| File | Purpose |
|------|---------|
| `ansible/playbooks/infrastructure/dashboard/tasks/kanidm.yml` | Kanidm on the VPS: folders, `server.toml`, backend certificate, tailnet address |
| `ansible/playbooks/infrastructure/dashboard/templates/kanidm-server.toml.j2` | Kanidm's settings: domain, backups |
| `ansible/playbooks/infrastructure/dashboard/templates/kanidm-mail-sender.toml.j2` | The mail sender's settings: sender address, Fastmail |
| `ansible/playbooks/infrastructure/dashboard/templates/kanidm-client.toml.j2` | How the mail sender reaches Kanidm |
| `ansible/playbooks/infrastructure/dashboard/files/Caddyfile` | The `auth.5am.cloud` site (Cloudflare DNS-01 certificate) |
| `ansible/inventory/group_vars/site_ovh/infra_dashboard/vars.yml` | `kanidm_image`, `kanidm_tools_image` |
| `ansible/inventory/group_vars/site_ovh/secrets.sops.yml` | The mail sender's token and Fastmail login (section `infra_kanidm_email`) |
| `ansible/playbooks/infrastructure/networking/tasks/oauth2-proxy.yml` | oauth2-proxy deployment |
| `ansible/playbooks/infrastructure/networking/templates/oauth2-proxy.env.j2` | oauth2-proxy settings |
| `ansible/playbooks/infrastructure/networking/tasks/kanidm_redirects.yml` | Registers each flagged service's login callback in Kanidm |
| `ansible/playbooks/infrastructure/networking/templates/Caddyfile.j2` | The `(login)` block every flagged service uses |
| `ansible/inventory/group_vars/site_<env>/infra_networking/oauth2-proxy.yml` | oauth2-proxy image and the names of its secrets |
| `ansible/inventory/group_vars/site_<env>/secrets.sops.yml` | Client secrets and the redirect-sync token (section `infra_networking`) |

People, groups and OAuth2 clients live in Kanidm's database, not in this repository.

## Admin Access

The admin account `idm_admin` has no stored password. Reset it when you need it (it prints a new one):

```bash
ssh -t ubuntu@dashboard sudo docker exec -it kanidm kanidmd recover-account idm_admin
```

Run the CLI from Kanidm's image, at the server's version (`kanidm_image`):

```bash
alias kanidm='docker run --rm -it -e KANIDM_URL=https://auth.5am.cloud -v kanidm-cli:/root/.cache kanidm/tools:1.12.0 kanidm'
```

```bash
kanidm login -D idm_admin
```

A session allows changes only for a while after login; `kanidm reauth -D idm_admin` renews it. Log out when done: `kanidm logout -D idm_admin`.

## Add a User

```bash
kanidm person create <user> "<Display Name>"
```

```bash
kanidm person update <user> --mail <address>
```

```bash
kanidm group add-members sso_users <user>
```

```bash
kanidm person credential create-reset-token <user> --ttl 86400
```

Send them the link or QR code. It lasts 24 hours and opens only from a site LAN or the tailnet. They set a password there, and a TOTP code or a passkey if they like. For a forgotten password they use **Recover Account** on the login page ([Password Reset by Email](#password-reset-by-email)), or you run the last command again.

A password alone is enough: `idm_all_persons` has `credential-type-minimum` set to `any`, where Kanidm's default asks for a second factor. To require one, set it back with `kanidm group account-policy credential-type-minimum idm_all_persons mfa`.

Every member of `sso_users` can open every flagged service; there are no per-user rules. Proxmox, PBS and Kasm keep their own permissions: create the Proxmox user and role on each host as in [Proxmox](#proxmox) and on WIL's backup server as in [Proxmox Backup Server](#proxmox-backup-server), and add the Kasm user to Administrators after their first login as in [Kasm](#kasm).

## Password Reset by Email

**Recover Account** on the login page asks for an email address. When it matches a person's address in Kanidm, Kanidm emails them a reset link from `noreply@5am.cloud`. The page answers the same either way, so it gives away no addresses. The link lasts an hour and, like the login, opens only from a site LAN or the tailnet. To email someone a link yourself (this one lasts 24 hours):

```bash
kanidm person credential send-reset-token <user> --ttl 86400
```

Kanidm only queues the mail. `kanidm-mail-sender`, next to Kanidm in the dashboard compose project, checks the queue every 5 seconds and sends through Fastmail (`smtps://smtp.fastmail.com`), logged in with an app password that has SMTP access only. `5am.cloud` is a domain in that Fastmail account, with `noreply@5am.cloud` as an alias and Fastmail's SPF and DKIM records in Cloudflare.

These parts live in Kanidm's database:

- each person's address: `kanidm person update <user> --mail <address>`
- service account `mail-sender`, a member of `idm_message_senders` and nothing else, with a read-write API token (`kanidm_mail_sender_token`): `kanidm service-account create mail-sender "Mail Sender" idm_admins`, `kanidm group add-members idm_message_senders mail-sender`, `kanidm service-account api-token generate mail-sender "mail sender" --readwrite`
- the **Recover Account** link: `kanidm system domain set-allow-account-recovery true`, as `admin`, because `idm_admin` can't change domain settings (`admin` has no stored password either: `kanidmd recover-account admin`, then `kanidm login -D admin`)

`kanidm system message-queue list` shows each message as `queued`, or with the time it went out. To test sending on its own, the mail sender can mail any address; it ends with `Success!` (`kanidm system message-queue send-test-message` is refused in 1.12.0, even for `admin`):

```bash
ssh ubuntu@dashboard sudo docker exec -e RUST_LOG=info kanidm-mail-sender /sbin/kanidm-mail-sender -c /etc/kanidm/config -m /etc/kanidm/mail-sender -t <address>
```

The sender logs only warnings and errors (`RUST_LOG=warn`), so its log stays empty while all is well.

## Protect a Service

Add `auth: true` to the service entry (for registry apps, inside the `proxy:` block), then deploy networking:

```yaml
- name: prometheus
  backend_host: 10.2.20.30
  backend_port: 9090
  proxied: true
  auth: true
```

```bash
task ansible:deploy-networking ENV=wil
```

Kanidm has no wildcard redirect URLs, so the deploy registers the service's `/oauth2/callback` with the `oauth2-proxy-<site>` client before Caddy starts sending users to the login. It does that from the machine running the deploy, which must reach `auth.5am.cloud` (the tailnet or a site LAN). When a service loses `auth: true`, its callback stays in Kanidm until you remove it:

```bash
kanidm system oauth2 remove-redirect-url oauth2-proxy-wil https://<name>.<domain>/oauth2/callback
```

Only browsers can log in. Leave `auth` off services that apps, devices or scripts talk to through the hostname (Plex, KOSync and MicroBin, for example). Anything else can still use a protected service's IP and port directly.

## Proxmox

Each site's Proxmox logs in to Kanidm with realm `sso` (the default realm), as client `proxmox-wil` or `proxmox-ldn`. The realm's settings live in Proxmox. `vm` keeps `auth: true`, so the first visit passes the gate and then Proxmox's own sign-in, the second time without a password.

The host must resolve `auth.5am.cloud`, which neither host's resolver does, so both have this in `/etc/hosts`:

```
100.116.40.99 auth.5am.cloud
```

The realm was added with this command (WIL shown; for LDN use `site_ldn`, `10.3.20.10` and `proxmox-ldn`). The client key comes from the site's secrets and is never printed:

```bash
sops decrypt --extract '["kanidm_proxmox_client_secret"]' ansible/inventory/group_vars/site_wil/secrets.sops.yml | ssh root@10.2.20.7 'key=$(cat); pveum realm add sso --type openid --issuer-url https://auth.5am.cloud/oauth2/openid/proxmox-wil --client-id proxmox-wil --client-key "$key" --username-claim preferred_username --autocreate 0 --default 1'
```

The username claim cannot be changed later. Then create each user and make it an admin:

```bash
pveum user add <user>@sso
```

```bash
pveum acl modify / --users <user>@sso --roles Administrator
```

Keep `root@pam`. It is the way in through `https://<host-ip>:8006` when Kanidm or Caddy is down, and a few settings stay root-only, such as raw `args` or PCI passthrough without a mapping. The realm only works on the `vm` name, because that is its only redirect URL.

## Proxmox Backup Server

WIL's backup server (`10.2.10.99`, a container on the NAS; `https://pbs.wil.5am.cloud`) logs in the same way: realm `sso` (the default realm), client `pbs-wil`, `pbs` keeps `auth: true`. Its resolver does not know `auth.5am.cloud` either, so it has the same `/etc/hosts` line as the Proxmox hosts. The client was created as `idm_admin`:

```bash
kanidm system oauth2 create pbs-wil "Proxmox Backup (wil)" https://pbs.wil.5am.cloud
```

```bash
kanidm system oauth2 add-redirect-url pbs-wil https://pbs.wil.5am.cloud
```

```bash
kanidm system oauth2 update-scope-map pbs-wil sso_users openid profile email
```

```bash
kanidm system oauth2 prefer-short-username pbs-wil
```

Its secret is `kanidm_pbs_client_secret` in WIL's secrets. The realm, with the key piped from there:

```bash
sops decrypt --extract '["kanidm_pbs_client_secret"]' ansible/inventory/group_vars/site_wil/secrets.sops.yml | ssh root@10.2.10.99 'key=$(cat); proxmox-backup-manager openid create sso --issuer-url https://auth.5am.cloud/oauth2/openid/pbs-wil --client-id pbs-wil --client-key "$key" --username-claim preferred_username --autocreate false --default true'
```

Then each user, made an admin:

```bash
ssh root@10.2.10.99 proxmox-backup-manager user create <user>@sso
```

```bash
ssh root@10.2.10.99 proxmox-backup-manager acl update / Admin --auth-id <user>@sso
```

Keep `root@pam`: it is the way in through `https://10.2.10.99:8007` when Kanidm or Caddy is down. Proxmox VE and backup clients reach PBS by IP and fingerprint, not through the `pbs` name, so the gate does not affect them.

## Kasm

Kasm has no `auth: true`, so a desktop left open does not depend on a cookie that runs out. It logs in to Kanidm as client `kasm`, with PKCE off because Kasm cannot send it. The settings on Kasm's side live in Kasm's database, under **Access Management > Authentication > OpenID**:

| Field | Value |
|-------|-------|
| Enabled | On |
| Display Name | `Kanidm` |
| Auto Login | On |
| Hostname | `kasm.ldn.5am.cloud` |
| Client ID | `kasm` |
| Client Secret | `kanidm_kasm_client_secret` from LDN's secrets |
| Authorization URL | `https://auth.5am.cloud/ui/oauth2` |
| Token URL | `https://auth.5am.cloud/oauth2/token` |
| User Info URL | `https://auth.5am.cloud/oauth2/openid/kasm/userinfo` |
| Scope | `openid` and `profile`, one per line |
| Username Attribute | `preferred_username` |
| Groups Attribute | Empty: the login fails if it is set |
| Debug | Off: it turns off TLS checks and writes tokens to the logs |
| Redirect URL | Kasm fills this in: `https://kasm.ldn.5am.cloud/api/oidc_callback` |

To copy the secret without showing it:

```bash
sops decrypt --extract '["kanidm_kasm_client_secret"]' ansible/inventory/group_vars/site_ldn/secrets.sops.yml | pbcopy
```

The first login creates a Kasm user in the default group; add it to Administrators as `admin@kasm.local`. A Kasm user created through one OpenID config cannot log in through another (`OIDC login rejected: different OIDC ID expected for user`), and a local user of the same name is refused (`Non OIDC user`): delete the old user first.

Kasm's own login page is at `https://kasm.ldn.5am.cloud/#/staticlogin`. It is the way in for `admin@kasm.local`, also when Kanidm is down.

## Upgrades and Backups

- Renovate opens one pull request for `kanidm/server` and `kanidm/tools` (the mail sender) but never merges it. Upgrade one minor version at a time and never back: run `ssh ubuntu@dashboard sudo docker exec kanidm kanidmd domain upgrade-check`, deploy the dashboard with the new tag (`task ansible:deploy-dashboard ENV=ovh`), and move the CLI alias to the same tag.
- Kanidm backs up its database every night at 22:00 UTC and keeps the last 7, in `/var/lib/dashboard/kanidm/backups` on the VPS. Nothing copies them elsewhere yet.
- Kanidm's domain, `auth.5am.cloud`, is permanent: changing it breaks passkeys and every client's tokens.

## Good to Know

- Each domain's cookie lasts 12 hours. When it has ended, an open app does not renew it by itself: it shows errors or its own login box (Proxmox says "Login failed"). Reload the page.
- To log out of a domain, open `/oauth2/sign_out` on any flagged name of that domain.
- If oauth2-proxy is down, flagged services answer `502`. If Kanidm is down, domains that already have a cookie keep working and new logins fail. Unflagged services are not affected.
- A site's LAN reaches `100.116.40.99` through a static route on its UDM to the site's networking VM. A tailnet device away from home finds the name through the tailnet's split DNS route for `auth.5am.cloud`.

## Troubleshooting

**Kanidm says the redirect URL is not valid** — the service's callback is not in the client's list yet. Run the networking deploy for that site.

**Every flagged service answers `502` after a deploy** — oauth2-proxy is not running: `ssh <networking-ip> docker ps`, then `docker logs oauth2-proxy`. It must reach `auth.5am.cloud`, which the container's `extra_hosts` pins to the VPS.

**`auth.5am.cloud` does not resolve** — on a LAN it comes from the site's BIND; away from home, from the tailnet's split DNS route. Hosts that use neither need a pin: the Proxmox hosts and the backup server have the `/etc/hosts` line, and oauth2-proxy's container has it in `extra_hosts`.

**Kasm's login ends in `Internal Error`** — Kasm's log has the reason: `ssh 10.3.20.50 'docker exec kasm docker logs --since 10m kasm_api 2>&1' | grep -E 'Failed to find|\(invalid_'`. `Failed to find groups attribute` means Groups Attribute is not empty. `The authorization code has already been used` means the error page was reloaded: start again from the login page.

**No reset email arrives** — `kanidm system message-queue list` shows whether Kanidm queued it. Nothing queued: the address typed is not the person's `mail`, or **Recover Account** is off. Still `queued`: the mail sender is down or Fastmail refused it: `ssh ubuntu@dashboard sudo docker logs kanidm-mail-sender`.

**Check a client secret without a login** — send Kanidm's token endpoint a fake code with the client's ID and secret. `401` means the secret is wrong; `400` with `invalid_request` means the secret is right and only the code was rejected.

**Kanidm's own log** — `ssh ubuntu@dashboard sudo docker logs kanidm`.
