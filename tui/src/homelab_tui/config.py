from pathlib import Path


def find_project_root() -> Path:
    """Walk up from tui/ to find the homelab project root (contains Taskfile.yaml)."""
    current = Path(__file__).resolve().parent
    while current != current.parent:
        if (current / "Taskfile.yaml").exists():
            return current
        current = current.parent
    raise FileNotFoundError("Could not find project root with Taskfile.yaml")


PROJECT_ROOT = find_project_root()
TERRAFORM_DIR = PROJECT_ROOT / "terraform"
ANSIBLE_DIR = PROJECT_ROOT / "ansible"
PACKER_DIR = PROJECT_ROOT / "packer"

DEFAULT_VM_VALUES = {
    "proxmox_node": "proxmox",
    "template_name": "ubuntu-server-wil-base",
    "gateway": "10.2.20.1",
    "nameserver": "10.2.20.53",
    "cores": 2,
    "memory": 2048,
    "disk_size": "20G",
    "storage_pool": "local-lvm",
    "network_bridge": "vmbr0",
    "ssh_user": "sfcal",
    "tags": "application",
}
