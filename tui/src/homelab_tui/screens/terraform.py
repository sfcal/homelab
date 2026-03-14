"""Terraform screen — VM CRUD and deployment operations."""

from textual.app import ComposeResult
from textual.binding import Binding
from textual.containers import Horizontal
from textual.screen import Screen
from textual.widgets import Button, DataTable, Footer, Header, Static

from ..data.environment import load_environment, get_env_terraform_dir, get_env_ansible_dir
from ..data.hcl_parser import parse_vms_tfvars, write_vms_tfvars
from ..data.inventory_parser import parse_hosts_ini, write_hosts_ini
from ..data.models import VMState
from ..task_runner.registry import (
    terraform_clean,
    terraform_deploy_all,
    terraform_deploy_vm,
    terraform_destroy_all,
    terraform_destroy_vm,
)
from ..widgets.confirm_dialog import ConfirmDialog
from ..widgets.vm_edit_modal import VMEditModal


class TerraformScreen(Screen):
    BINDINGS = [
        Binding("n", "new_vm", "New VM"),
        Binding("e", "edit_vm", "Edit"),
        Binding("d", "deploy_vm", "Deploy"),
        Binding("x", "destroy_vm", "Destroy"),
        Binding("r", "refresh", "Refresh"),
        Binding("delete", "delete_vm", "Delete"),
    ]

    DEFAULT_CSS = """
    #tf-title {
        padding: 0 1;
        text-style: bold;
    }
    #tf-table {
        height: 1fr;
        margin: 0 1;
    }
    #tf-actions {
        height: 3;
        padding: 0 1;
        align: center middle;
    }
    #tf-actions Button {
        margin: 0 1;
    }
    """

    def __init__(self) -> None:
        super().__init__()
        self._vms: dict[str, VMState] = {}

    def compose(self) -> ComposeResult:
        yield Header()
        yield Static("Terraform", id="tf-title")
        yield DataTable(id="tf-table", cursor_type="row")
        with Horizontal(id="tf-actions"):
            yield Button("New [n]", id="btn-new", variant="success")
            yield Button("Edit [e]", id="btn-edit", variant="primary")
            yield Button("Deploy [d]", id="btn-deploy", variant="warning")
            yield Button("Deploy All", id="btn-deploy-all", variant="warning")
            yield Button("Destroy [x]", id="btn-destroy", variant="error")
            yield Button("Clean", id="btn-clean", variant="error")
        yield Footer()

    def on_mount(self) -> None:
        table = self.query_one("#tf-table", DataTable)
        table.add_columns("Key", "Name", "Description", "IP", "Cores", "RAM", "Disk", "Status")
        self._load_data()

    def on_screen_resume(self) -> None:
        self._load_data()

    def _load_data(self) -> None:
        env_name = self.app.current_env
        env = load_environment(env_name)
        self._vms = env.vms

        self.query_one("#tf-title", Static).update(
            f"Terraform — env: [bold]{env_name}[/bold]"
        )

        table = self.query_one("#tf-table", DataTable)
        table.clear()
        for key, vm_state in env.vms.items():
            c = vm_state.config
            table.add_row(
                key, c.name, c.description, c.ip_address,
                str(c.cores), str(c.memory), c.disk_size,
                vm_state.status.value,
                key=key,
            )

    def _get_selected_key(self) -> str | None:
        table = self.query_one("#tf-table", DataTable)
        if table.row_count == 0:
            return None
        row_key = table.coordinate_to_cell_key(table.cursor_coordinate).row_key
        return str(row_key.value)

    def action_new_vm(self) -> None:
        def on_save(result: bool) -> None:
            if result:
                self._load_data()
                self.notify("VM created")
        self.app.push_screen(VMEditModal(self.app.current_env), on_save)

    def action_edit_vm(self) -> None:
        key = self._get_selected_key()
        if not key or key not in self._vms:
            self.notify("No VM selected", severity="warning")
            return
        def on_save(result: bool) -> None:
            if result:
                self._load_data()
                self.notify("VM updated")
        self.app.push_screen(
            VMEditModal(self.app.current_env, self._vms[key].config), on_save
        )

    def action_deploy_vm(self) -> None:
        key = self._get_selected_key()
        if not key:
            self.notify("No VM selected", severity="warning")
            return
        self.app.run_task(
            terraform_deploy_vm(self.app.current_env, key),
            f"Deploy VM: {key}",
        )

    def action_destroy_vm(self) -> None:
        key = self._get_selected_key()
        if not key:
            self.notify("No VM selected", severity="warning")
            return

        def on_confirm(confirmed: bool) -> None:
            if confirmed:
                self.app.run_task(
                    terraform_destroy_vm(self.app.current_env, key),
                    f"Destroy VM: {key}",
                    on_success=lambda: self._remove_vm_from_tfvars(key),
                )

        self.app.push_screen(
            ConfirmDialog(
                f"Destroy VM '{key}'?\nThis will permanently delete the VM and remove it from config.",
                title="Destroy VM",
            ),
            on_confirm,
        )

    def action_delete_vm(self) -> None:
        """Delete VM from tfvars (does not destroy in Proxmox)."""
        key = self._get_selected_key()
        if not key:
            self.notify("No VM selected", severity="warning")
            return

        def on_confirm(confirmed: bool) -> None:
            if confirmed:
                self._delete_vm_from_files(key)

        self.app.push_screen(
            ConfirmDialog(
                f"Delete VM '{key}' from config files?\nThis removes the VM definition only.",
                title="Delete VM Config",
            ),
            on_confirm,
        )

    def _remove_vm_from_tfvars(self, key: str) -> None:
        """Remove a VM definition from the tfvars file (file I/O only)."""
        env = self.app.current_env
        tf_dir = get_env_terraform_dir(env)
        tfvars_path = tf_dir / "vms.auto.tfvars"
        if tfvars_path.exists():
            vms = parse_vms_tfvars(tfvars_path)
            if key in vms:
                del vms[key]
                write_vms_tfvars(tfvars_path, vms)

    def _delete_vm_from_files(self, key: str) -> None:
        """Remove VM from config and refresh the UI."""
        self._remove_vm_from_tfvars(key)
        self._load_data()
        self.notify(f"VM '{key}' removed from config")

    def action_refresh(self) -> None:
        self._load_data()
        self.notify("Refreshed")

    def on_button_pressed(self, event: Button.Pressed) -> None:
        env = self.app.current_env
        actions = {
            "btn-new": self.action_new_vm,
            "btn-edit": self.action_edit_vm,
            "btn-deploy": self.action_deploy_vm,
            "btn-deploy-all": lambda: self.app.run_task(
                terraform_deploy_all(env), "Deploy All (Terraform)"
            ),
            "btn-destroy": self.action_destroy_vm,
            "btn-clean": lambda: self._confirm_and_run(
                "Clean terraform state?", "Clean Terraform",
                terraform_clean(env), "Clean Terraform",
            ),
        }
        action = actions.get(event.button.id)
        if action:
            action()

    def _confirm_and_run(
        self, message: str, title: str, command: list[str], desc: str
    ) -> None:
        def on_confirm(confirmed: bool) -> None:
            if confirmed:
                self.app.run_task(command, desc)

        self.app.push_screen(ConfirmDialog(message, title=title), on_confirm)
