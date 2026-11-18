# Docker Services

All homelab services run as Docker Compose stacks deployed by Ansible. The `docker_service` role handles directory creation, compose template rendering, image pulling, and container lifecycle.

## Media Stack

The media stack provides automated media management and streaming on a dedicated host (`app_mediastack`):

| Service | Purpose |
|---------|---------|
| Plex | Media streaming server |
| Sonarr | TV show management |
| Radarr | Movie management |
| Prowlarr | Indexer management |
| Sabnzbd | Download client |
| Bazarr | Subtitle management |
| Tdarr | Media transcoding |
| Pulsarr | Request management |
| Frigate | Camera/NVR integration |

Deploy with `task ansible:deploy-media ENV=wil`.

## Gaming

Steam Headless and RomM (ldn) share one playbook on the `app_gaming` host; an environment gets the stacks its group_vars define. Deploy with `task ansible:deploy-gaming ENV=<env>`; see [Gaming](gaming.md).

## Hermes Agent

Hermes Agent runs in two containers on the Mac mini in wil, in OrbStack, with its own playbook. Deploy with `task ansible:deploy-hermes ENV=wil`; see [Hermes Agent](hermes.md).

## Ignis

[Ignis](https://github.com/Nystik-gh/ignis) runs Obsidian in the browser at `https://ignis.wil.5am.cloud`, behind the Kanidm login: it has no login of its own. It is a container on the Mac mini in wil, in OrbStack next to [Hermes](hermes.md), with its own playbook. Deploy with `task ansible:deploy-ignis ENV=wil`.

- **Vaults:** every folder under `/Users/smithers/ignis/vaults` on the Mac is a vault, plain Markdown. `Documents` is the `Documents` folder of the Mac's iCloud Drive, mounted writable: what Ignis changes there syncs to iCloud.
- **Other files:** `data/` (Ignis settings) and `obsidian-app/` (the Obsidian download, fetched again when missing), next to `vaults/`.
- **iCloud:** what holds for Hermes's mount holds here too (see [Files on the Mac](hermes.md#files-on-the-mac)): macOS asks once on the Mac's screen, and a file still in iCloud is slow the first time it is read. A vault opens slowly until the Mac has downloaded its files.
- **Vault root:** the compose file sets `VAULT_ROOT=/mnt/vaults`. At each start the image changes the owner of everything under its own `/vaults`, which would walk the whole iCloud folder.
- **The port:** 8082 on the Mac answers anyone on the wil network without the login.
- **Updates:** Renovate opens a PR for `ignis_image` and never merges it itself, because CI can't deploy to the Mac. Merge it when you deploy.

## Calibre-Web Automated

[Calibre-Web Automated](https://github.com/crocodilestick/Calibre-Web-Automated) is the e-book library at `https://books.ldn.5am.cloud`: browse, read and download in the browser, with Calibre inside the image for imports and conversions. It is a container on the Mac mini in wil, in OrbStack next to [Hermes](hermes.md), with its own playbook. Deploy with `task ansible:deploy-calibre ENV=wil`.

- **The name:** `books` is on ldn's Caddy, which reaches the Mac over the site link (the entry is in `site_ldn/proxy/ldn.5am.cloud.yml`). Only the LANs and the tailnet reach ldn's Caddy. wil's answers from the internet, and this service has no Kanidm login in front. A change of the port needs a networking deploy at ldn.
- **Login:** its own, with no `auth: true`, so e-readers can use the name: the OPDS catalog at `/opds` takes an account's username and password, and so do KOReader sync and Kobo sync (both off until turned on in its settings).
- **The port:** 8083 on the Mac answers on the wil network and the tailnet without Caddy, at `http://10.2.0.10:8083`, with the same login.
- **Shared folders:** its folders are the Mac's own, shared into the container, so the compose file sets `NETWORK_SHARE_MODE=true`: the SQLite files stay out of WAL mode, nothing changes owner at start, and the drop folder is looked into every few seconds.
- **iCloud Books:** the `Documents/Books` folder of the Mac's iCloud Drive is mounted read-only at `/books` in the container. Calibre-Web Automated shows only its own library, so a book from there appears once a copy of it is put into `ingest/`. Never make `/books` the drop folder: that one deletes what it imports.
- **Updates:** Renovate opens a PR for `calibre_image` and never merges it itself, because CI can't deploy to the Mac. Merge it when you deploy.

Everything is under `/Users/smithers/calibre/` on the Mac's own disk:

| Folder | Holds |
|--------|-------|
| `config/` | `app.db` (users and settings), `cwa.db`, logs, and `processed_books/`, a copy of every file it has imported |
| `library/` | The Calibre library: `metadata.db` and one folder per author |
| `ingest/` | Drop folder: a book copied here is imported within about 15 seconds, then deleted from here |

To add books, use the upload button in the web page or copy files into `ingest/` (`scp book.epub smithers@10.2.0.10:calibre/ingest/`). Other formats are converted to EPUB on the way in.

A new install has one account, `admin`, with the image's default password `admin123`: change it at the first login, under the account's profile. A password needs 8 characters with upper and lower case, a digit and a special character.

Once a mail server is set up in its settings, the login form gains a **Forgot Password?** button, and in v4.0.8 pressing Enter in the form then sends that in place of **Login** ([upstream issue 1585](https://github.com/crocodilestick/Calibre-Web-Automated/issues/1585)): the account's password is replaced with a random one and mailed to its address. From then on click the Login button, and give `admin` a real address first (it starts as `admin@example.org`). Without a mail server the button is not there and Enter logs in. To set a password from the command line, for a locked-out account too:

```bash
ssh smithers@10.2.0.10 "~/.orbstack/bin/docker exec -e CALIBRE_DBPATH=/config -w /app/calibre-web-automated calibre-web-automated s6-setuidgid abc python3 cps.py -s '<user>:<new password>'"
```

## Kasm

Kasm (ldn, on the `work` VM, `https://kasm.ldn.5am.cloud`) is the LinuxServer image, which runs Kasm's own Docker daemon inside the container. Its state is under `/var/lib/kasm/`. Deploy with `task ansible:deploy-kasm ENV=ldn`.

Custom workspace images live in `ansible/playbooks/apps/kasm/files/`, one folder per image with a `Dockerfile` (folder names lowercase: they become the image name). Each image is built on one machine only, the one whose agent runs its workspace, listed in `kasm_workspace_images`:

| Machine | List | Built by | Agent |
|---------|------|----------|-------|
| work VM | `site_ldn/app_kasm/vars.yml` (none now) | `task ansible:deploy-kasm ENV=ldn`, inside Kasm's Docker | `85a6c3` |
| OVH VPS | `site_ovh/app_kasm_agent/vars.yml` (`deluge`) | `task ansible:deploy-kasm-agent ENV=ovh`, in the VPS's Docker ([Kasm Agent](kasm-agent.md)) | `a67ee6` |

Each deploy copies the build files over and builds `localhost/<folder>:latest`, pulling newer base images first. To use one, add a workspace with that image name and restrict it to that machine's agent: the other agent doesn't have the image. To move one, move its name to the other list, change the workspace's agent, then deploy the machine that now builds it. Agents prune images in Aggressive mode: within 30 s they delete any image no workspace of theirs uses, so save the workspace first, then deploy.

### Deluge

The Deluge workspace runs `localhost/deluge:latest` (`files/deluge/`) on the OVH VPS agent, so torrent traffic leaves from the VPS's IP, with no volume mappings. When a torrent finishes, Deluge's Execute plugin runs `torrent-archive`, which writes it as one uncompressed `<torrent name>.zip` into `~/Downloads`, so Kasm's download panel can fetch it in one go (written as `.zip.part` first, then renamed; `zip -0`, since media doesn't compress). Torrents download to `~/torrents`. Both folders, and Deluge's settings, last only as long as the session: fetch the archives before ending it. The settings come from the image (`core.conf`, `execute.conf`), which Kasm copies into each new session's home; mapping `~/.config` to a host folder would overwrite what's saved there each time. The base stays on the Kasm server's version. Deluge 2.0.3 with libtorrent 2.0 logs a harmless `KeyError: 'disk.num_blocks_cache_hits'` every few seconds.

Workspace settings (Kasm's admin, not this repo): Docker Image `localhost/deluge:latest`, Docker Registry empty, Restrict Image to Kasm Agent `a67ee6` (the VPS), Volume Mappings `{}`.

## Data-Driven Apps

Most applications use the shared `deploy-app.yml` playbook and are defined in the registry of the site that hosts them, `ansible/inventory/group_vars/site_<env>/apps.yml`. See [Deploy a Service](../guides/deploy-service.md) for the full workflow.

| App | Image | Port |
|-----|-------|------|
| Grist | `gristlabs/grist-oss` | 8484 |
| iSponsorBlockTV | `ghcr.io/dmunozv04/isponsorblocktv` | — |
| KOReader Sync | `koreader/kosync` | 17200 |
| MicroBin | `danielszabo99/microbin` | 8081 |
| Restreamer | `datarhei/restreamer` | 8710 |
| Squid | `ubuntu/squid` | 3128 |

### Grist

[Grist](https://www.getgrist.com/) (ldn, on the `work` VM) is a spreadsheet kept as a small database, at `https://grist.ldn.5am.cloud`. It runs the free Community edition, which has no login of its own here: the Kanidm login is in front (`auth: true`), and whoever gets through is the one Grist account, `admin@grist.ldn.5am.cloud`, owner of the one team site, `home`. Logging in to Grist with Kanidm itself (OIDC) is part of Grist's full edition, which needs an activation key.

- **Files:** everything is under `/var/lib/work/grist/` on the VM, owned by uid 1000 (`sfcal`): `docs/` holds one SQLite file per document (`<document id>.grist`), `home.sqlite3` the list of documents and workspaces, `grist-sessions.db` the browser sessions.
- **Formulas:** they are Python and run in a gVisor sandbox (`GRIST_SANDBOX_FLAVOR`), which keeps them away from the VM's files and the network.
- **Settings:** all of them are in the compose file, and `GRIST_IN_SERVICE` skips Grist's first-run wizard, so a rebuilt VM starts the same way, with no documents. The key that signs browser sessions is `grist_session_secret` in `site_ldn/secrets.sops.yml`.
- **Getting data out:** a document's share menu exports it to Excel or CSV, or downloads the whole document as its `.grist` file. An Excel export holds the values, not the formulas.
- **Scripts:** port 8484 on the VM answers Grist's [API](https://support.getgrist.com/rest-api/) without the Kanidm login, to a request that carries an API key (`Authorization: Bearer <key>`). Make the key in the web page: your picture → Account settings → Developer. It can do everything the account can. [Hermes](hermes.md#update-grist) updates tables this way.
- **The port:** it also lets anyone on the ldn network in as the one account, without the login.

### iSponsorBlockTV

[iSponsorBlockTV](https://github.com/dmunozv04/iSponsorBlockTV) (ldn, on the `web` VM) skips SponsorBlock segments and ads on YouTube TV apps. It has no web UI and only needs to reach youtube.com, so it has no port or proxy entry. Paired TVs and settings are in `/var/lib/isponsorblocktv/data/config.json` on the VM, written by the setup wizard, not by Ansible; a rebuilt VM needs its TVs paired again. Until a TV is paired the container exits every 10 seconds and restarts.

To pair a TV (also to add another one or change settings), open YouTube on the TV, go to Settings → Link with TV code, then on the VM:

```bash
cd /opt/isponsorblocktv
docker compose run --rm isponsorblocktv setup      # setup-cli for plain prompts
docker compose restart
```

## Infrastructure Services

Infrastructure services have dedicated playbooks rather than using the data-driven pattern:

| Service | Docs |
|---------|------|
| BIND9, Caddy, oauth2-proxy, DDNS, Tailscale | [Networking](networking/index.md) |
| Prometheus, Grafana, Homepage | [Monitoring](monitoring/index.md) (Grafana and Homepage on the OVH VPS) |
| Step-CA | [Certificate Authority](ca/index.md) |

## How It Works

1. **Compose templates** — Jinja2 templates at `ansible/playbooks/apps/<service>/templates/compose.yaml.j2`
2. **Rendering** — Ansible renders templates with environment-specific variables from `group_vars/`
3. **Deployment** — The `docker_service` role creates the service directory, renders the compose file, pulls images, and starts containers
4. **Restart policy** — All containers use `unless-stopped`
5. **LinuxServer images** — Use `PUID`, `PGID`, `UMASK` environment variables for file permissions

## Troubleshooting

**Container not starting** — Check logs: `ssh <host> docker logs <container>`. Common issues: port conflicts, missing environment variables, image not found.

**Image pull failed** — Verify network connectivity on the host. For GHCR images, ensure no rate limiting. Retry with `ssh <host> docker pull <image>`.

**Compose file not updating** — Ansible only re-renders the template when variables change. Force a redeploy by modifying a variable or deleting the deployed compose file on the host.
