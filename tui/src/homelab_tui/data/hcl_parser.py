from pathlib import Path

import hcl2

from .models import VMConfig


def parse_vms_tfvars(tfvars_path: Path) -> dict[str, VMConfig]:
    """Parse vms.auto.tfvars and return a dict of VMConfig keyed by VM key."""
    with open(tfvars_path) as f:
        data = hcl2.load(f)

    vms: dict[str, VMConfig] = {}
    raw_vms = data.get("vms", [{}])
    if isinstance(raw_vms, list):
        raw_vms = raw_vms[0] if raw_vms else {}

    for key, attrs in raw_vms.items():
        vms[key] = VMConfig(
            key=key,
            name=attrs["name"],
            description=attrs.get("description", "Virtual Machine"),
            proxmox_node=attrs["proxmox_node"],
            vmid=int(attrs["vmid"]),
            template_name=attrs["template_name"],
            ip_address=attrs["ip_address"],
            gateway=attrs["gateway"],
            nameserver=attrs["nameserver"],
            cores=int(attrs.get("cores", 2)),
            memory=int(attrs.get("memory", 2048)),
            disk_size=attrs.get("disk_size", "20G"),
            storage_pool=attrs["storage_pool"],
            network_bridge=attrs.get("network_bridge", "vmbr0"),
            ssh_user=attrs["ssh_user"],
        )
    return vms


def write_vms_tfvars(tfvars_path: Path, vms: dict[str, VMConfig]) -> None:
    """Write vms.auto.tfvars from VMConfig dict using template generation."""
    lines = ["# VMs to create", "vms = {"]
    for key, vm in vms.items():
        lines.append(f"  {key} = {{")
        lines.append(f'    name           = "{vm.name}"')
        lines.append(f'    description    = "{vm.description}"')
        lines.append(f'    proxmox_node   = "{vm.proxmox_node}"')
        lines.append(f"    vmid           = {vm.vmid}")
        lines.append(f'    template_name  = "{vm.template_name}"')
        lines.append(f'    ip_address     = "{vm.ip_address}"')
        lines.append(f'    gateway        = "{vm.gateway}"')
        lines.append(f'    nameserver     = "{vm.nameserver}"')
        lines.append(f"    cores          = {vm.cores}")
        lines.append(f"    memory         = {vm.memory}")
        lines.append(f'    disk_size      = "{vm.disk_size}"')
        lines.append(f'    storage_pool   = "{vm.storage_pool}"')
        lines.append(f'    network_bridge = "{vm.network_bridge}"')
        lines.append(f'    ssh_user       = "{vm.ssh_user}"')
        lines.append("  }")
        lines.append("")
    lines.append("}")
    lines.append("")
    tfvars_path.write_text("\n".join(lines))
