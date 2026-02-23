import json
from pathlib import Path


def get_provisioned_vm_keys(state_path: Path) -> set[str]:
    """Read terraform.tfstate and return the set of provisioned VM keys."""
    if not state_path.exists():
        return set()

    with open(state_path) as f:
        state = json.load(f)

    keys: set[str] = set()
    for resource in state.get("resources", []):
        module = resource.get("module", "")
        # Module paths look like: module.infrastructure.module.vms["dns_server"]
        if 'module.vms[' in module:
            # Extract the key from module.infrastructure.module.vms["dns_server"]
            start = module.index('["') + 2
            end = module.index('"]')
            keys.add(module[start:end])

    return keys
