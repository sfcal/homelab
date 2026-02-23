from pathlib import Path

from textual.app import ComposeResult
from textual.containers import Horizontal, Vertical, VerticalScroll
from textual.screen import ModalScreen
from textual.widgets import Button, Input, Label

from ..config import DEFAULT_VM_VALUES, ENVIRONMENTS, VM_TO_ANSIBLE_GROUP
from ..data.hcl_parser import parse_vms_tfvars, write_vms_tfvars
from ..data.inventory_parser import parse_hosts_ini, write_hosts_ini
from ..data.models import VMConfig


class VMEditModal(ModalScreen[bool]):
    DEFAULT_CSS = """
    VMEditModal {
        align: center middle;
    }
    #edit-form {
        width: 80;
        max-height: 90%;
        border: thick $accent;
        background: $surface;
        padding: 1 2;
    }
    #edit-title {
        text-style: bold;
        width: 100%;
        content-align: center middle;
        margin-bottom: 1;
    }
    .field-row {
        height: 3;
        margin-bottom: 0;
    }
    .field-label {
        width: 20;
        padding: 1 1 0 0;
    }
    .field-input {
        width: 1fr;
    }
    #edit-buttons {
        width: 100%;
        align-horizontal: center;
        margin-top: 1;
    }
    #edit-buttons Button {
        margin: 0 1;
    }
    """

    FIELDS = [
        ("key", "VM Key", "e.g. web_server"),
        ("name", "Name", "e.g. web"),
        ("description", "Description", "e.g. Web Server"),
        ("proxmox_node", "Proxmox Node", ""),
        ("vmid", "VMID", "e.g. 1200"),
        ("template_name", "Template", ""),
        ("ip_address", "IP Address", "e.g. 10.2.20.100"),
        ("gateway", "Gateway", ""),
        ("nameserver", "Nameserver", ""),
        ("cores", "Cores", ""),
        ("memory", "Memory (MB)", ""),
        ("disk_size", "Disk Size", "e.g. 20G"),
        ("storage_pool", "Storage Pool", ""),
        ("network_bridge", "Network Bridge", ""),
        ("ssh_user", "SSH User", ""),
    ]

    def __init__(self, env_name: str, vm: VMConfig | None = None):
        super().__init__()
        self._env_name = env_name
        self._vm = vm

    def compose(self) -> ComposeResult:
        title = f"Edit VM: {self._vm.key}" if self._vm else "Create New VM"
        with Vertical(id="edit-form"):
            yield Label(title, id="edit-title")
            with VerticalScroll():
                for field_id, label, placeholder in self.FIELDS:
                    value = self._get_field_value(field_id)
                    disabled = field_id == "key" and self._vm is not None
                    with Horizontal(classes="field-row"):
                        yield Label(label, classes="field-label")
                        yield Input(
                            value=str(value),
                            placeholder=placeholder,
                            id=f"input-{field_id}",
                            classes="field-input",
                            disabled=disabled,
                        )
            with Horizontal(id="edit-buttons"):
                yield Button("Save", variant="primary", id="btn-save")
                yield Button("Cancel", variant="default", id="btn-cancel")

    def _get_field_value(self, field_id: str) -> str:
        if self._vm:
            return str(getattr(self._vm, field_id, ""))
        return str(DEFAULT_VM_VALUES.get(field_id, ""))

    def _get_input(self, field_id: str) -> str:
        return self.query_one(f"#input-{field_id}", Input).value.strip()

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "btn-cancel":
            self.dismiss(False)
            return

        if event.button.id == "btn-save":
            self._save()

    def _save(self) -> None:
        try:
            vm = VMConfig(
                key=self._get_input("key"),
                name=self._get_input("name"),
                description=self._get_input("description"),
                proxmox_node=self._get_input("proxmox_node"),
                vmid=int(self._get_input("vmid")),
                template_name=self._get_input("template_name"),
                ip_address=self._get_input("ip_address"),
                gateway=self._get_input("gateway"),
                nameserver=self._get_input("nameserver"),
                cores=int(self._get_input("cores")),
                memory=int(self._get_input("memory")),
                disk_size=self._get_input("disk_size"),
                storage_pool=self._get_input("storage_pool"),
                network_bridge=self._get_input("network_bridge"),
                ssh_user=self._get_input("ssh_user"),
            )
        except ValueError as e:
            self.notify(f"Invalid input: {e}", severity="error")
            return

        if not vm.key:
            self.notify("VM Key is required", severity="error")
            return

        env_cfg = ENVIRONMENTS[self._env_name]
        tfvars_path: Path = env_cfg["terraform_dir"] / "vms.auto.tfvars"

        # Read existing VMs, update/add, write back
        existing = parse_vms_tfvars(tfvars_path) if tfvars_path.exists() else {}
        old_ip = existing[vm.key].ip_address if vm.key in existing else None
        existing[vm.key] = vm
        write_vms_tfvars(tfvars_path, existing)

        # Update hosts.ini if this VM has an ansible group mapping
        ansible_group = VM_TO_ANSIBLE_GROUP.get(vm.key)
        if ansible_group:
            hosts_path: Path = env_cfg["ansible_dir"] / "hosts.ini"
            groups = parse_hosts_ini(hosts_path) if hosts_path.exists() else {}
            if ansible_group in groups:
                # Replace old IP with new IP
                hosts = groups[ansible_group]
                if old_ip and old_ip in hosts:
                    groups[ansible_group] = [vm.ip_address if h == old_ip else h for h in hosts]
                elif vm.ip_address not in hosts:
                    groups[ansible_group].append(vm.ip_address)
            else:
                groups[ansible_group] = [vm.ip_address]
            write_hosts_ini(hosts_path, groups)

        self.dismiss(True)
