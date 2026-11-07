# Single Sign-On (Authelia)

[Authelia](https://www.authelia.com) is the one login page of a site. A proxied service opts in with `auth: true` in its [service definition](proxy.md#auth), on any domain. Authelia and a small helper, [oauth2-proxy](https://oauth2-proxy.github.io/oauth2-proxy/), run as containers next to Caddy on each site's networking VM.

## How It Works

1. Caddy asks oauth2-proxy before proxying a flagged service.
2. No session for that domain: the browser is sent to the site's login page and comes back to the page it asked for.
3. oauth2-proxy then sets a cookie for the service's domain, so the other flagged services on that domain open directly.
4. The first visit to a flagged service on another domain passes through the login page without asking for the password again.

Authelia is a gate in front of a service, not a replacement for its login: a service that has its own (the NAS, for example) still asks for it. [Kasm](#kasm) and [Proxmox](#proxmox) are the exceptions: they log in through Authelia themselves.

The login page is the service entry named `auth` in the site's proxy file:

```yaml
- name: auth
  backend_host: authelia   # container name on the Caddy docker network
  backend_port: 9091
  proxied: true
```

| Site | Login page |
|------|------------|
| WIL | `auth.wil.5am.cloud` |
| LDN | `auth.ldn.5am.cloud` |

Each site runs its own Authelia, so you log in once per site.

## File Locations

| File | Purpose |
|------|---------|
| `ansible/playbooks/infrastructure/networking/tasks/authelia.yml` | Deployment task |
| `ansible/playbooks/infrastructure/networking/templates/authelia-configuration.yml.j2` | Authelia configuration |
| `ansible/playbooks/infrastructure/networking/templates/authelia-users.yml.j2` | User and password hash |
| `ansible/playbooks/infrastructure/networking/templates/authelia-oauth2-proxy.env.j2` | oauth2-proxy settings |
| `ansible/playbooks/infrastructure/networking/templates/authelia-compose.yaml.j2` | Docker Compose definition of both containers |
| `ansible/playbooks/infrastructure/networking/templates/Caddyfile.j2` | The `(login)` block every flagged service uses |
| `ansible/inventory/group_vars/site_<env>/infra_networking/authelia.yml` | Images and user name |
| `ansible/inventory/group_vars/site_<env>/secrets.sops.yml` | Password hash and generated keys (section `infra_networking`) |

On the VM: config in `/opt/authelia`, database in `/var/lib/authelia`.

## Set the Password

Generate a hash (it asks for the password twice and prints a `Digest:` line):

```bash
docker run --rm -it authelia/authelia:4.39.28 authelia crypto hash generate argon2
```

Store the digest in the environment's secrets, then deploy networking:

```bash
sops set ansible/inventory/group_vars/site_wil/secrets.sops.yml '["authelia_password_hash"]' '"$argon2id$..."'
```

Use single quotes as shown: in double quotes the shell eats the `$` parts of the digest. After the deploy, `docker ps` on the networking VM should show `authelia` as `(healthy)` and `oauth2-proxy` as up.

The password cannot be changed in Authelia itself; repeat these steps to change it.

## Protect a Service

Add `auth: true` to the service entry (for registry apps, inside the `proxy:` block), then deploy networking:

```yaml
- name: grafana
  backend_host: 10.2.20.30
  backend_port: 3000
  proxied: true
  auth: true
```

```bash
task ansible:deploy-networking ENV=wil
```

Only browsers can log in. Leave `auth` off services that apps, devices or scripts talk to through the hostname (KOSync and MicroBin, for example). Anything else can still use a protected service's IP and port directly.

Homepage (on the dashboard VPS, tailnet only, no Authelia) loads its Grafana panels from each monitoring VM's IP and port, so `auth` on `grafana` doesn't affect it.

## Kasm

Kasm has no `auth: true`, so a desktop left open does not depend on a cookie that runs out. It logs in through LDN's Authelia as a second OpenID Connect client: the client is in `authelia-configuration.yml.j2`, and the settings on Kasm's side live in Kasm's database, not in this repository.

Generate the client secret (it prints a `Random Password` and a `Digest:` line):

```bash
docker run --rm authelia/authelia:4.39.28 authelia crypto hash generate pbkdf2 --variant sha512 --random --random.length 72 --random.charset rfc3986
```

Store the digest, then deploy networking:

```bash
sops set ansible/inventory/group_vars/site_ldn/secrets.sops.yml '["authelia_oidc_kasm_client_secret_hash"]' '"$pbkdf2-sha512$..."'
```

```bash
task ansible:deploy-networking ENV=ldn
```

In Kasm, add a config under **Access Management > Authentication > OpenID**:

| Field | Value |
|-------|-------|
| Enabled | On |
| Display Name | `Authelia` |
| Auto Login | Off until the first login works, then on |
| Hostname | `kasm.ldn.5am.cloud` |
| Default | Off |
| Client ID | `kasm` |
| Client Secret | The `Random Password` |
| Authorization URL | `https://auth.ldn.5am.cloud/api/oidc/authorization` |
| Token URL | `https://auth.ldn.5am.cloud/api/oidc/token` |
| User Info URL | `https://auth.ldn.5am.cloud/api/oidc/userinfo` |
| Scope | `openid` and `profile`, one per line |
| Username Attribute | `preferred_username` |
| Groups Attribute | Empty: the Authelia user has no groups, and the login fails if this is set |
| Debug | Off: it turns off TLS checks and writes tokens to the logs |
| Redirect URL | Kasm fills this in: `https://kasm.ldn.5am.cloud/api/oidc_callback` |

The first login creates a new Kasm user named after the Authelia user, in the default group. Add it to Administrators with the existing admin account; the membership stays as long as the group has no SSO mapping for this provider. Kasm does not link accounts: remove or rename a local user with the same name first, or the login is refused with `OIDC login rejected: Non OIDC user`.

With Auto Login on, Kasm's own login page is at `https://kasm.ldn.5am.cloud/#/staticlogin`, which is also the way in when Authelia is down.

## Proxmox

Each site's Proxmox logs in through that site's Authelia as a client of its own: the client is in `authelia-configuration.yml.j2`, and the realm's settings live in Proxmox, not in this repository. Unlike Kasm, `vm` keeps `auth: true`: WIL's Caddy answers from the internet, and the gate keeps Proxmox's login page off it. The first visit therefore passes through the login page twice, the second time without asking for the password.

Generate a client secret per site, using the same command as for [Kasm](#kasm). Store both values, because Proxmox's realm needs the password itself, then deploy networking:

```bash
sops set ansible/inventory/group_vars/site_wil/secrets.sops.yml '["authelia_oidc_proxmox_client_secret"]' '"<Random Password>"'
```

```bash
sops set ansible/inventory/group_vars/site_wil/secrets.sops.yml '["authelia_oidc_proxmox_client_secret_hash"]' '"$pbkdf2-sha512$..."'
```

Proxmox fetches Authelia's settings itself, so the host must resolve the login page, which is not in public DNS. Check from the host:

```bash
getent hosts auth.wil.5am.cloud
```

If that prints nothing, as on both sites' hosts when this was set up, point the name at the site's networking VM (WIL `10.2.20.53`, LDN `10.3.20.53`) in the host's `/etc/hosts`:

```bash
echo "10.2.20.53 auth.wil.5am.cloud" >> /etc/hosts
```

Add the realm under **Datacenter > Permissions > Realms > Add > OpenID Connect Server**:

| Field | Value |
|-------|-------|
| Issuer URL | `https://auth.wil.5am.cloud` |
| Realm | `authelia` |
| Client ID | `proxmox` |
| Client Key | `authelia_oidc_proxmox_client_secret` from the site's secrets |
| Default | On, so the realm is preselected at login |
| Autocreate Users | Off |
| Username Claim | Type `preferred_username`. It cannot be changed later, and the default gives a user named after an opaque ID |

Then, on the host, create the user and make it an admin:

```bash
pveum user add sfcal@authelia
```

```bash
pveum acl modify / --users sfcal@authelia --roles Administrator
```

Keep `root@pam`. It is the way in through `https://<host-ip>:8006` when Authelia or Caddy is down, and a few settings stay root-only, such as raw `args` or PCI passthrough without a mapping. The `authelia` realm only works on the `vm` name, because that is its only registered redirect URL.

## Good to Know

- A login lasts 12 hours, or a month if you tick **Remember me**. Each domain's cookie also lasts 12 hours and is renewed without asking while the login lasts.
- When a cookie has ended, an open app does not renew it by itself: it shows errors or its own login box (Proxmox says "Login failed"). Reload the page.
- To log out of a domain, open `/oauth2/sign_out` on any flagged name of that domain. Logging out on the login page only stops new domains from being opened.
- Three wrong passwords lock out the address they came from for 5 minutes.
- If oauth2-proxy is down, flagged services answer `502`. If only Authelia is down, domains that already have a cookie keep working. Unflagged services are not affected.
- To require a second factor, change `authorization_policy` to `two_factor` in `authelia-configuration.yml.j2`. There is no mail server, so the one-time code Authelia asks for when you add a device is written to `/var/lib/authelia/notification.txt` on the networking VM.

## Troubleshooting

**Deploy stops with `'authelia_password_hash' is undefined`** — the password has not been set for that environment. See [Set the Password](#set-the-password).

**Deploy stops with `'authelia_oidc_kasm_client_secret_hash' is undefined`** — the Kasm client secret has not been set for LDN. See [Kasm](#kasm).

**Deploy stops with `'authelia_oidc_proxmox_client_secret_hash' is undefined`** — the Proxmox client secret has not been set for that environment. See [Proxmox](#proxmox).

**Kasm's login ends in `Internal Error`** — Kasm's log has the reason: `ssh 10.3.20.50 'docker exec kasm docker logs --since 10m kasm_api 2>&1' | grep -E 'Failed to find|\(invalid_'`. `Failed to find groups attribute` means Groups Attribute is not empty. `invalid_client` means the Client Secret does not match. `The authorization code has already been used` means the error page was reloaded: start again from the login page.

**Every flagged service answers `502` after a deploy** — one of the two containers is not running: `ssh <networking-ip> docker ps`, then `docker logs authelia` (usually a malformed password hash) or `docker logs oauth2-proxy` (it restarts until it can reach the login page, which takes up to a minute after the first deploy).

**A new password is not accepted** — Authelia reads its files only when it starts. If the deploy that changed the password failed part-way, restart it: `ssh <networking-ip> docker restart authelia`.
