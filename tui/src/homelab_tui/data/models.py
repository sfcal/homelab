from dataclasses import dataclass, field
from enum import Enum


class VMStatus(Enum):
    DEFINED = "defined"
    PROVISIONED = "provisioned"
    UNKNOWN = "unknown"


@dataclass
class VMConfig:
    key: str
    name: str
    description: str
    proxmox_node: str
    vmid: int
    template_name: str
    ip_address: str
    gateway: str
    nameserver: str
    cores: int
    memory: int
    disk_size: str
    storage_pool: str
    network_bridge: str
    ssh_user: str


@dataclass
class VMState:
    config: VMConfig
    status: VMStatus


@dataclass
class AnsiblePlaybook:
    task_name: str
    display_name: str
    description: str
    hosts_group: str | None = None


@dataclass
class Environment:
    name: str
    vms: dict[str, VMState] = field(default_factory=dict)
    playbooks: list[AnsiblePlaybook] = field(default_factory=list)
