# Packer

Packer builds cloud-init-enabled VM templates on Proxmox.

## Quick Start

```bash
# Build Ubuntu Server template
task packer:build-ubuntu ENV=wil

# Build Ubuntu Desktop template
task packer:build-ubuntu-desktop ENV=wil

# Build Debian Bookworm template
task packer:build-debian ENV=wil

# Build Netboot VM template
task packer:build-netboot ENV=wil

# Build Windows template (needs the Windows and virtio-win ISOs on Proxmox, see below)
task packer:build-windows ENV=ldn

# Clean up logs and ISOs
task packer:clean
```

## Templates

| Template | File | Description |
|----------|------|-------------|
| Ubuntu Server | `ubuntu-server-base.pkr.hcl` | Ubuntu Server with Docker, Node Exporter, Lazydocker, mDNS (avahi) |
| Ubuntu Desktop | `ubuntu-desktop-base.pkr.hcl` | Ubuntu Server install with `ubuntu-desktop-minimal` on top (GNOME, Firefox), mDNS (avahi); no Docker or Node Exporter |
| Debian Bookworm | `debian-bookworm-base.pkr.hcl` | Debian base with Docker |
| Netboot | — | PXE boot template |
| Windows | `windows-base.pkr.hcl` | Windows 11 (or Server) for one-off VMs: UEFI + TPM 2.0, unattended install, virtio-win guest tools (drivers, QEMU and SPICE agents), Remote Desktop on, console clipboard |

Templates produce images named `<template>-<env>-base` (e.g., `ubuntu-server-wil-base`).

## What Templates Include

The Ubuntu Server template (primary) installs:

1. Cloud-init configuration for Proxmox
2. Docker and Docker Compose
3. Lazydocker (terminal UI for Docker)
4. Node Exporter v1.9.1 (Prometheus metrics)
5. avahi-daemon (mDNS, IPv4 only) — every clone answers to `<hostname>.local`; the gateway's [mDNS reflector](../infrastructure/networking/unifi.md#mdns) carries that to client VLANs
6. Cleanup (remove SSH keys, machine ID, apt cache)

## File Structure

```
packer/
├── templates/
│   ├── ubuntu-server-base.pkr.hcl      # Ubuntu template definition
│   ├── ubuntu-desktop-base.pkr.hcl     # Ubuntu Desktop template definition
│   ├── debian-bookworm-base.pkr.hcl    # Debian template definition
│   └── windows-base.pkr.hcl            # Windows template definition
├── files/windows/
│   ├── autounattend.xml.pkrtpl         # Windows answer file (rendered by the template)
│   ├── setup.ps1                       # First-logon bootstrap: WinRM, VirtIO drivers, guest agent
│   └── smb-share.ps1                   # Optional: NAS share as a persistent Z: drive
└── environments/
    ├── wil/
    │   ├── ubuntu-variables.pkrvars.hcl     # Ubuntu build variables
    │   ├── ubuntu-desktop-variables.pkrvars.hcl  # Ubuntu Desktop build variables
    │   ├── debian-variables.pkrvars.hcl     # Debian build variables
    │   ├── windows-variables.pkrvars.hcl    # Windows build variables
    │   └── credentials.wil.pkrvars.hcl      # Proxmox API tokens (encrypted)
    └── ldn/
```

## Ubuntu Desktop Template

Built the same way as the Ubuntu Server template: same ISO, same autoinstall (`http/user-data`), same mDNS setup. Instead of Docker and Node Exporter the build then installs `ubuntu-desktop-minimal`, the default selection of the Ubuntu Desktop installer (GNOME, Firefox, basic utilities). No separate Desktop ISO is needed.

It is still a cloud-init template, so clone it with the Terraform VM module (`template_name = "ubuntu-desktop-<env>-base"`, `memory` of 4096 or more, `disk_size` no smaller than the template's 32G) or by hand from the Proxmox UI. Clones boot to the GNOME login screen on the Proxmox console; log in with `ssh_username` / `ssh_password` from the environment and credentials var files.

Two things differ from the server template on clones:

- The password keeps working, at the console only. cloud-init normally locks its default user's password on a clone's first boot, which would leave no way to log in at the GNOME screen, so the template sets `lock_passwd: false` for that user. The same file (`/etc/cloud/cloud.cfg.d/99-default-user.cfg`) sets `ssh_pwauth: false`, so SSH takes keys only: Terraform clones get their key as usual, a clone made by hand needs one in its Cloud-Init tab.
- NetworkManager runs the network instead of systemd-networkd (the desktop packages make it the netplan renderer). It is fed by the same Proxmox cloud-init settings, so `ip_address`, `gateway` and `nameserver` work as usual. The build disables `systemd-networkd-wait-online`, which would otherwise hold every boot for two minutes waiting for an interface systemd-networkd no longer has.

The build also sets `MUTTER_DEBUG_KMS_THREAD_TYPE=user` in `/etc/environment`. Without it GNOME Shell is killed about two seconds after starting on Proxmox's default display whenever its display thread runs with realtime priority, and the login screen restarts six times on every boot before it stays up.

## Windows Template

For one-off Windows VMs: build the template once, then clone it from the Proxmox UI (right-click → Clone, full clone) or with `qm clone <template-vmid> <new-vmid> --name win-test --full 1`. Clones boot straight to the login screen, get an address by DHCP (shown on the VM's Summary page via the guest agent) and have Remote Desktop enabled. Log in with `ssh_username` / `ssh_password` from the environment and credentials var files. Copy and paste works over Remote Desktop and, via the clipboard panel, in the Proxmox noVNC console.

**Before the first build**, upload two ISOs to the node's ISO storage (`local` → ISO Images) and point `iso_file` / `virtio_iso_file` in `environments/<env>/windows-variables.pkrvars.hcl` at them:

| ISO | Source |
|-----|--------|
| Windows installer | [Windows 11 x64 ISO](https://www.microsoft.com/software-download/windows11) (the link expires, so download in a browser and upload); Windows Server evaluation ISOs work too |
| virtio-win | [stable-virtio/virtio-win.iso](https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso) (disk/network drivers, QEMU guest agent) |

How the build works: Packer generates a small ISO with the answer file (`files/windows/autounattend.xml.pkrtpl`) and `files/windows/setup.ps1`, attaches it next to the two ISOs above and presses a key at "Press any key to boot from CD or DVD". Setup runs unattended (VirtIO drivers from the virtio-win ISO, GPT/UEFI layout, local admin account, OOBE skipped). At the first automatic logon `setup.ps1` enables WinRM, installs the virtio-win guest tools (drivers, QEMU guest agent, SPICE agent) and turns the autologon off again; Packer then connects over WinRM, runs a short check and converts the VM to `windows-<env>-base`. The generated ISO is deleted from Proxmox afterwards. Expect 10–15 minutes.

Packer cannot set the display's clipboard option, so after a build enable it on the template by hand: Hardware → Display → Edit → Advanced → Clipboard: VNC (or `qm set <vmid> --vga std,clipboard=vnc` on the node). Clones inherit it, and together with the SPICE agent that `setup.ps1` installs it gives the noVNC console its clipboard panel.

Secure Boot certificates: on a node with `pve-edk2-firmware` 4.2025.05-1 or newer, Proxmox fills a new EFI disk with both the 2011 and the 2023 Microsoft UEFI certificates and marks it `ms-cert=2023k` in the VM config (visible in `qm config <vmid>`), so a fresh build and its clones are correct from the start. The Packer Proxmox plugin (1.2.3) has no option for this and needs none. A template built before that firmware version, and every clone of it, lacks the marker and the node warns at VM start that the 2011 certificates expired in June 2026. Rebuild such a template, and fix an existing clone while it is shut down with `qm enroll-efi-keys <vmid>` (UI: Hardware → EFI Disk → Disk Action → Enroll Updated Certificates); if BitLocker protectors are active in the guest, suspend them first or Windows asks for the recovery key.

Things to know:

- `windows_image_name` selects the edition inside the ISO (`Windows 11 Pro` by default; `Windows 11 Enterprise Evaluation`, `Windows Server 2025 SERVERSTANDARD`, …). Set `virtio_driver_os` to the matching driver folder (`w11`, `2k25`, …) and `windows_language` to the ISO's language.
- No sysprep: clones share hostname and SID. Fine for throwaway instances; the template is not meant for domain joins.
- No cloud-init: Windows ignores the Proxmox cloud-init drive, so clones are not managed by the Terraform VM module (which is cloud-init shaped). Clone by hand.
- `setup.ps1` leaves its logs at `C:\Windows\Temp\packer-setup.log` and `C:\Windows\Temp\virtio-win-guest-tools.log` on the template.
- NAS share: set `smb_server`, `smb_share` and `smb_username` in `windows-variables.pkrvars.hcl` and `smb_password` in the credentials file, and every clone has `\\<server>\<share>` as a persistent `Z:` drive for the local administrator. `smb-share.ps1` stores the login in Credential Manager and runs `net use /persistent:yes`, so Windows reconnects the drive at logon on its own (SMB rather than NFS: no UID/GID mapping, no extra client). The NAS must be reachable from the build VM. Leave `smb_server` empty for no share.

## Key Variables

| Variable | Description |
|----------|-------------|
| `proxmox_api_url` | Proxmox API endpoint (e.g., `https://proxmox:8006/api2/json`) |
| `proxmox_api_token_id` | API token ID (e.g., `packer@pve!packer`) |
| `proxmox_api_token_secret` | API token secret (encrypted) |
| `proxmox_node` | Target Proxmox node |
| `environment` | Environment name (used in template naming) |
| `template_prefix` | Template name prefix (e.g., `ubuntu-server`) |
| `cores` | CPU cores for build VM |
| `memory` | RAM for build VM |
| `disk_size` | Disk size for template |
| `iso_file` | ISO path on Proxmox storage |

## Credentials

Proxmox API credentials (and, for the Windows template, the `ssh_password` of the local administrator and the optional `smb_password` NAS password) are stored in SOPS-encrypted files:

```bash
# Edit credentials
sops packer/environments/wil/credentials.wil.pkrvars.hcl
```

## Troubleshooting

**401 Unauthorized** — The Proxmox API token is invalid or lacks permissions. Verify the token in `credentials.<env>.pkrvars.hcl` (decrypt with `sops`). The token needs `VM.Allocate`, `VM.Clone`, `Datastore.AllocateSpace`, and related permissions.

**Template name conflict** — A template with the same name already exists. Delete the old template from Proxmox first: `qm destroy <vmid>`.

**ISO not found** — The `iso_file` path must match an ISO uploaded to Proxmox storage. Check with `pvesm list <storage>` on the Proxmox host.

**Build hangs at SSH** — The VM can't reach the internet for package installation, or cloud-init hasn't configured networking. Check Proxmox network bridge and VLAN settings.

**Windows build never connects over WinRM** — Open the VM console in Proxmox. If it still shows the firmware or a boot menu, the "Press any key" prompt was missed: raise `boot_wait` or the number of `<spacebar>` presses in `windows-base.pkr.hcl`. If Setup is asking for a product key, set `windows_product_key` to the generic key for the edition. If Setup says it cannot find a disk, `virtio_driver_os` does not match the Windows version (folders on the virtio-win ISO). If Windows is at the desktop, read `C:\Windows\Temp\packer-setup.log` for the failing step in `setup.ps1`.
