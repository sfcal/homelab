# Proxmox Hosts (SR-IOV GPU)

The hypervisor is managed by `ansible/playbooks/infrastructure/proxmox/deploy.yml`, group `infra_proxmox`. Its one job: create the Intel Arc Pro B50's SR-IOV virtual functions (VFs) at every boot, before Proxmox starts the VMs that use them.

```bash
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

Configuration (`ansible/environments/ldn/group_vars/infra_proxmox/vars.yml`):

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

The GPU VM `game_server` is defined in `terraform/environments/ldn/vms.auto.tfvars` with `bios = "ovmf"`, `machine = "q35"` and `pci_mapping`. `work_server` keeps `bios` and `machine` but no longer maps a VF; VMs 118 and 121 are hand-made clones outside Terraform, given their VF with `qm set <vmid> --hostpci0 mapping=b50-vfN,pcie=1`. The provider (telmate 3.0.2-rc07) only format-checks the mapping ID; whether the VF exists is discovered at VM start. On apply the provider also starts a stopped VM.

As of October 2026 the ldn state holds only `web_server`; every other ldn VM has to be imported before `task terraform:deploy ENV=ldn` (which applies with `-auto-approve`) is safe to run:

```bash
cd terraform/environments/ldn
for pair in networking_server:3000 ca_server:3003 monitoring_server:3002 work_server:3004 game_server:3005 netboot_server:3006; do
  terraform import "module.infrastructure.module.vms[\"${pair%%:*}\"].proxmox_vm_qemu.vm" "pve-ldn/qemu/${pair##*:}"
done
terraform plan
```

The VM module ignores `clone` and `full_clone` changes so an imported VM does not plan as a replacement. Always read the plan before applying: anything marked `forces replacement` would destroy the VM.
