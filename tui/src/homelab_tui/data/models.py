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
    tags: str = "application"


@dataclass
class VMState:
    config: VMConfig
    status: VMStatus


@dataclass
class TaskInfo:
    name: str
    description: str
    namespace: str
    short_name: str


@dataclass
class PackerTemplate:
    name: str
    filename: str
    path: str


@dataclass
class HostGroup:
    name: str
    hosts: list[str] = field(default_factory=list)
    category: str = ""


@dataclass
class Environment:
    name: str
    vms: dict[str, VMState] = field(default_factory=dict)
    host_groups: dict[str, HostGroup] = field(default_factory=dict)
