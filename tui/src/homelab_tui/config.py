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

ENVIRONMENTS: dict[str, dict[str, Path | str]] = {
    "wil": {
        "terraform_dir": TERRAFORM_DIR / "environments" / "wil",
        "ansible_dir": ANSIBLE_DIR / "environments" / "wil",
        "env_var": "wil",
    },
    "nyc": {
        "terraform_dir": TERRAFORM_DIR / "environments" / "nyc",
        "ansible_dir": ANSIBLE_DIR / "environments" / "nyc",
        "env_var": "nyc",
    },
}

VM_TO_ANSIBLE_GROUP: dict[str, str] = {
    "dns_server": "dns_server",
    "reverse_proxy": "reverse_proxy",
    "monitoring_server": "monitoring",
    "games_server": "games-server",
}

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
}
