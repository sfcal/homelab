from ..config import ENVIRONMENTS
from .hcl_parser import parse_vms_tfvars
from .inventory_parser import parse_hosts_ini
from .models import AnsiblePlaybook, Environment, VMState, VMStatus
from .tfstate_reader import get_provisioned_vm_keys

ANSIBLE_TASKS = [
    AnsiblePlaybook("ansible:deploy-all", "Deploy All", "Deploy entire infrastructure"),
    AnsiblePlaybook("ansible:deploy-services", "Deploy Services", "Deploy DNS + reverse proxy", "services"),
    AnsiblePlaybook("ansible:deploy-media", "Deploy Media Stack", "Deploy media stack", "media-stack"),
    AnsiblePlaybook("ansible:deploy-monitoring", "Deploy Monitoring", "Deploy monitoring stack", "monitoring"),
    AnsiblePlaybook("ansible:deploy-games", "Deploy Games Server", "Deploy games server", "games-server"),
    AnsiblePlaybook("ansible:deploy-website", "Deploy Website", "Deploy personal website", "website"),
    AnsiblePlaybook("ansible:deploy-tailscale", "Deploy Tailscale", "Deploy tailscale"),
    AnsiblePlaybook("ansible:deploy-external-monitoring", "Deploy Ext Monitoring", "Deploy external monitoring", "external_monitoring"),
    AnsiblePlaybook("ansible:ping", "Ping All Hosts", "Ping all hosts in inventory"),
    AnsiblePlaybook("ansible:backup-media", "Backup Media", "Backup media stack", "media-stack"),
    AnsiblePlaybook("ansible:restore-media", "Restore Media", "Restore media stack backup", "media-stack"),
]


def load_environment(env_name: str) -> Environment:
    """Load full state for an environment by merging HCL config with tfstate."""
    env_cfg = ENVIRONMENTS[env_name]
    tf_dir = env_cfg["terraform_dir"]
    ansible_dir = env_cfg["ansible_dir"]

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

    return Environment(name=env_name, vms=vms, playbooks=list(ANSIBLE_TASKS))
