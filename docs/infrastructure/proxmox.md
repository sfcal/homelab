# Proxmox Hosts (SR-IOV GPU)

The hypervisors are managed by `ansible/playbooks/infrastructure/proxmox/deploy.yml`, group `infra_proxmox`: wil's host (`10.2.20.7`) and pve-ldn (`10.3.20.10`), both reached as `root`. The play does two things:

- **On both hosts** it installs node-exporter (Debian's package `prometheus-node-exporter`, which enables and starts its own service on port 9100), so the site's Prometheus has the host's CPU, memory and disks and the alert rules cover it (see [Monitoring](monitoring/index.md#node-exporters)). Deploy the site's monitoring afterwards; the host is a scrape target because it is in `[site_<env>]`.
- **On pve-ldn only** it creates the Intel Arc Pro B50's SR-IOV virtual functions (VFs) at every boot, before Proxmox starts the VMs that use them. These tasks run where `b50_num_vfs` is set, and the rest of this page is about them.

```bash
task ansible:deploy-proxmox ENV=wil
task ansible:deploy-proxmox ENV=ldn
```

## Why

A GPU VM references its VF through a resource mapping (`hostpci0: mapping=b50-vf1`, `pci_mapping` in Terraform). At VM start Proxmox resolves the mapping against sysfs and refuses to start if the device is missing or its IOMMU group changed:

```
PCI device mapping invalid (hardware probably changed): pci device '0000:0b:00.1' not found
```

VFs exist only after something writes to `sriov_numvfs`, and they vanish on reboot.

## What the play installs

| Path on pve-ldn | Purpose |
|-----------------|---------|
| `/usr/local/sbin/sriov-b50` | Finds the PF by PCI id (`lspci -d 8086:e212`), waits for the `xe` driver, writes `sriov_numvfs`, binds the VFs to `vfio-pci` |
| `/etc/systemd/system/sriov-b50.service` | Oneshot, `Before=pve-guests.service`, runs the script |

Then it runs `pvesh get /cluster/mapping/pci --check-node pve-ldn`, the same validation `qm start` performs, and fails if a mapping no longer matches the hardware.

Configuration (`ansible/inventory/group_vars/site_ldn/infra_proxmox/vars.yml`):

```yaml
b50_num_vfs: 3
```

The card itself (PCI id `8086:e212`, unit and mapping names) is hardcoded in the play and templates.

## Facts worth knowing

- Kernel 7.0 (Proxmox VE 9.2) supports Battlemage SR-IOV out of the box: no module option, DKMS or `force_probe`. 6.17 (PVE 9.1) did too; 7.0 adds per-VF debugfs quotas (`/sys/kernel/debug/dri/<PF>/sriov/vfN/tile0/vram_quota`) for an uneven VRAM split, unused here.
- The card's firmware data (`igsc fw-data version -d /dev/mei0`) sets `sriov_totalvfs`: Intel's current image (203.41) allows 2 VFs, the launch image (203.31, from driver package 32.0.101.6979, flashed on 2026-11-03) allows 12. Each VF's BAR is 16 GB divided by the VF count, rounded up to a power of two (8 GB with 2 or 3 VFs, 4 GB with 4), and the VRAM is split evenly between the VFs (about 5.2 GiB each with 3).
- Mapping IDs are `b50-vf1` (VM 3005 gaming), `b50-vf2` (VM 121 ubuntu-desktop-kasmvnc, moved from VM 3004 work on 2026-11-05) and `b50-vf3` (VM 118 windows-gpu). They are created once in Datacenter > Resource Mappings, or with `pvesh create /cluster/mapping/pci --id b50-vfN --map node=pve-ldn,path=<VF address>,id=8086:e212,subsystem-id=8086:1114,iommugroup=<group>`. If a kernel or BIOS change moves a VF's IOMMU group, the play fails and names the mapping; fix it in Datacenter > Resource Mappings.
- Never add `options vfio-pci ids=8086:e212` or `blacklist xe`: vfio-pci would claim the physical function and no VF could exist.
- To change `b50_num_vfs`, edit the variable, re-run the play, and reboot the host: the count can only change while no VM holds a VF. With the GPU VMs stopped, `systemctl restart sriov-b50` does the same without a reboot.
- Never run an Intel Windows installer against the bare PF, and never `fwupdmgr update` on the host: both re-flash the 2-VF firmware data. Guests holding a VF cannot flash anything. Both config-data images are kept in `/root` on pve-ldn (`b50fw-6979` is the 12-VF one, `b50fw` the 2-VF rollback).
- A guest needs kernel 6.17 or newer for a Battlemage VF (Ubuntu 25.10 qualifies; Ubuntu 24.04 needs `linux-generic-hwe-24.04`, its 6.8 kernel has no driver for the card). VFs are render-only, no display outputs.

## Verify

```bash
ssh root@10.3.20.10 'systemctl status sriov-b50; lspci -nnks 0b:00; pvesh get /cluster/mapping/pci --check-node pve-ldn'
```

Expect `0b:00.0` on `xe`, `0b:00.1` to `0b:00.3` on `vfio-pci`, and no `checks` on the mappings. After a reboot `qm status 3005` should be `running` without manual action.

## Terraform notes

The GPU VM `game_server` is defined in `terraform/environments/ldn/vms.auto.tfvars` with `bios = "ovmf"`, `machine = "q35"` and `pci_mapping`. `work_server` keeps `bios` and `machine` but no longer maps a VF; VMs 118 and 121 are hand-made clones outside Terraform, given their VF with `qm set <vmid> --hostpci0 mapping=b50-vfN,pcie=1`. The provider is bpg/proxmox (`proxmox_virtual_environment_vm`). The module sets `rombar = true` on the mapped device because bpg sends `rombar=0` when it is left out. On apply the provider also starts a stopped VM (`started` defaults to true), so a stopped GPU VM is started and needs its VF free.

Since November 2026 the ldn state holds all eight ldn VMs as `proxmox_virtual_environment_vm` (imported when the provider changed from telmate), and the wil state holds wil's three (`networking`, `ca_server`, `monitoring_server`; wil's node is named `proxmox`). A VM made outside Terraform is imported with `<node>/<vmid>` as the ID. The import needs the site's variables, decrypted for the one command the way the tasks do it:

```bash
cd terraform/environments/ldn
sops exec-file --filename terraform.tfvars terraform.tfvars.sops \
  'terraform import -var-file={} "module.infrastructure.module.vms[\"<key>\"].proxmox_virtual_environment_vm.vm" pve-ldn/<vmid>'
```

Then read the plan from the repo root: `task terraform:plan ENV=ldn`. An import changes only the state file, never the VM.

The VM module ignores `clone` changes so an imported VM does not plan as a replacement, and changes to the login keys (`ssh_public_key`): on an existing VM the provider would rewrite the cloud-init drive and reboot the VM, which then sets itself up as a new instance (new SSH host keys). wil's three VMs were made with one key and have the second in `authorized_keys`. Always read the plan before applying (`task terraform:deploy ENV=ldn` applies with `-auto-approve`): anything marked `forces replacement` would destroy the VM.
