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
| `/usr/local/sbin/sriov-b50` | Waits for the `xe` driver, writes `sriov_numvfs`, binds the VFs to `vfio-pci` |
| `/etc/systemd/system/sriov-b50.service` | Oneshot, `Before=pve-guests.service`, runs the script |

Then it runs `pvesh get /cluster/mapping/pci --check-node pve-ldn`, the same validation `qm start` performs, and fails if a mapping no longer matches the hardware.

Configuration (`ansible/environments/ldn/group_vars/infra_proxmox/vars.yml`):

```yaml
proxmox_sriov_devices:
  - name: b50
    pf: "0000:0b:00.0"
    num_vfs: 2
```

## Facts worth knowing

- Kernel 6.17 (Proxmox VE 9.1) supports Battlemage SR-IOV out of the box: no module option, DKMS or `force_probe`.
- Intel's current B50 firmware allows 2 VFs (`cat /sys/bus/pci/devices/0000:0b:00.0/sriov_totalvfs`); the Q3 2025 firmware allowed 12. Each VF gets `1/num_vfs` of the card's memory.
- Mapping IDs are `b50-vf1` (VM 3005 gaming) and `b50-vf2` (VM 3004 work), paths `0000:0b:00.1` and `0000:0b:00.2`. If a kernel or BIOS change moves their IOMMU groups, the play fails and names the mapping; fix it in Datacenter > Resource Mappings.
- Never add `options vfio-pci ids=8086:e212` or `blacklist xe`: vfio-pci would claim the physical function and no VF could exist.
- To change `num_vfs`, edit the variable, re-run the play, and reboot the host (the count can only change while no VM holds a VF).
- A guest needs kernel 6.17 or newer for a Battlemage VF (Ubuntu 25.10 qualifies). VFs are render-only, no display outputs.

## Verify

```bash
ssh root@10.3.20.10 'systemctl status sriov-b50; lspci -nnks 0b:00; pvesh get /cluster/mapping/pci --check-node pve-ldn'
```

Expect `0b:00.0` on `xe`, `0b:00.1` and `0b:00.2` on `vfio-pci`, and no `checks` on the mappings. After a reboot `qm status 3005` should be `running` without manual action.

## Terraform notes

The GPU VMs (`work_server`, `game_server`) are defined in `terraform/environments/ldn/vms.auto.tfvars` with `bios = "ovmf"`, `machine = "q35"` and `pci_mapping`. The provider (telmate 3.0.2-rc07) only format-checks the mapping ID; whether the VF exists is discovered at VM start. On apply the provider also starts a stopped VM.

As of October 2026 the ldn state holds only `web_server`; every other ldn VM has to be imported before `task terraform:deploy ENV=ldn` (which applies with `-auto-approve`) is safe to run:

```bash
cd terraform/environments/ldn
for pair in networking_server:3000 ca_server:3003 monitoring_server:3002 work_server:3004 game_server:3005 netboot_server:3006; do
  terraform import "module.infrastructure.module.vms[\"${pair%%:*}\"].proxmox_vm_qemu.vm" "pve-ldn/qemu/${pair##*:}"
done
terraform plan
```

The VM module ignores `clone` and `full_clone` changes so an imported VM does not plan as a replacement. Always read the plan before applying: anything marked `forces replacement` would destroy the VM.
