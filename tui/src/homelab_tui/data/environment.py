"""Load environment state by merging terraform config with state."""

from __future__ import annotations

from pathlib import Path

from ..config import ANSIBLE_DIR, TERRAFORM_DIR
from .hcl_parser import parse_vms_tfvars
from .inventory_parser import parse_hosts_ini
from .models import Environment, HostGroup, VMState, VMStatus
from .tfstate_reader import get_provisioned_vm_keys


def get_env_terraform_dir(env_name: str) -> Path:
    return TERRAFORM_DIR / "environments" / env_name


def get_env_ansible_dir(env_name: str) -> Path:
    return ANSIBLE_DIR / "environments" / env_name


def load_environment(env_name: str) -> Environment:
    """Load full state for an environment by merging HCL config with tfstate."""
    tf_dir = get_env_terraform_dir(env_name)
    ansible_dir = get_env_ansible_dir(env_name)

    # Parse VM definitions
    tfvars_path = tf_dir / "vms.auto.tfvars"
    vm_configs = parse_vms_tfvars(tfvars_path) if tfvars_path.exists() else {}

    # Read provisioned state
    state_path = tf_dir / "terraform.tfstate"
    provisioned_keys = get_provisioned_vm_keys(state_path)

    # Merge into VMState
    vms: dict[str, VMState] = {}
    for key, config in vm_configs.items():
        status = VMStatus.PROVISIONED if key in provisioned_keys else VMStatus.DEFINED
        vms[key] = VMState(config=config, status=status)

    # Parse host groups
    hosts_path = ansible_dir / "hosts.ini"
    raw_groups = parse_hosts_ini(hosts_path) if hosts_path.exists() else {}
    host_groups: dict[str, HostGroup] = {}
    for group_name, hosts in raw_groups.items():
        if ":children" in group_name:
            continue
        category = "infrastructure" if group_name.startswith("infra_") else "apps"
        host_groups[group_name] = HostGroup(
            name=group_name,
            hosts=hosts,
            category=category,
        )

    return Environment(name=env_name, vms=vms, host_groups=host_groups)


def get_infra_host_ip(env_name: str, group_prefix: str) -> str | None:
    """Get the first host IP from an infrastructure group."""
    ansible_dir = get_env_ansible_dir(env_name)
    hosts_path = ansible_dir / "hosts.ini"
    if not hosts_path.exists():
        return None
    groups = parse_hosts_ini(hosts_path)
    for group_name, hosts in groups.items():
        if group_name.startswith(group_prefix) and hosts:
            return hosts[0]
    return None


def get_all_host_ips(env_name: str) -> list[str]:
    """Get all unique host IPs from the environment inventory."""
    ansible_dir = get_env_ansible_dir(env_name)
    hosts_path = ansible_dir / "hosts.ini"
    if not hosts_path.exists():
        return []
    groups = parse_hosts_ini(hosts_path)
    ips: set[str] = set()
    for group_name, hosts in groups.items():
        if ":children" in group_name:
            continue
        for h in hosts:
            stripped = h.strip().split()[0]
            ips.add(stripped)
    return sorted(ips)


def get_ssh_user(env_name: str) -> str:
    """Get the SSH user for the environment from VM configs."""
    tf_dir = get_env_terraform_dir(env_name)
    tfvars_path = tf_dir / "vms.auto.tfvars"
    if tfvars_path.exists():
        vms = parse_vms_tfvars(tfvars_path)
        for vm in vms.values():
            return vm.ssh_user
    return "sfcal"
