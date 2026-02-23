from textual.app import ComposeResult
from textual.binding import Binding
from textual.containers import Horizontal
from textual.screen import Screen
from textual.widgets import Button, DataTable, Footer, Header, Static

from ..config import ENVIRONMENTS
from ..data.environment import load_environment
from ..data.models import VMState


class VMManagementScreen(Screen):
    BINDINGS = [
        Binding("n", "new_vm", "New VM"),
        Binding("e", "edit_vm", "Edit"),
        Binding("d", "deploy_vm", "Deploy"),
        Binding("x", "destroy_vm", "Destroy"),
        Binding("r", "refresh", "Refresh"),
        Binding("escape", "dashboard", "Dashboard"),
    ]

    DEFAULT_CSS = """
    #vm-title {
        padding: 0 1;
        text-style: bold;
    }
    #vm-table {
        height: 1fr;
        margin: 1 1;
    }
    #vm-actions {
        height: 3;
        padding: 0 1;
        align: center middle;
    }
    #vm-actions Button {
        margin: 0 1;
    }
    """

    def compose(self) -> ComposeResult:
        yield Header()
        yield Static(f"VM Management - {self.app.current_env}", id="vm-title")
        yield DataTable(id="vm-table", cursor_type="row")
        with Horizontal(id="vm-actions"):
            yield Button("New [n]", id="btn-new", variant="success")
            yield Button("Edit [e]", id="btn-edit", variant="primary")
            yield Button("Deploy [d]", id="btn-deploy", variant="warning")
            yield Button("Destroy [x]", id="btn-destroy", variant="error")
        yield Footer()

    def on_mount(self) -> None:
        self._load_data()

    def _load_data(self) -> None:
        env = load_environment(self.app.current_env)
        self._vms = env.vms
        table = self.query_one("#vm-table", DataTable)
        table.clear(columns=True)
        table.add_columns("Key", "Name", "IP Address", "VMID", "Cores", "RAM (MB)", "Disk", "Status")
        for key, vm_state in env.vms.items():
            c = vm_state.config
            table.add_row(
                key, c.name, c.ip_address, str(c.vmid),
                str(c.cores), str(c.memory), c.disk_size,
                vm_state.status.value,
                key=key,
            )
        try:
            self.query_one("#vm-title", Static).update(
                f"VM Management - {self.app.current_env}"
            )
        except Exception:
            pass

    def _get_selected_key(self) -> str | None:
        table = self.query_one("#vm-table", DataTable)
        if table.row_count == 0:
            return None
        row_key = table.coordinate_to_cell_key(table.cursor_coordinate).row_key
        return str(row_key.value)

    def action_new_vm(self) -> None:
        from .vm_edit_modal import VMEditModal

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

        from .vm_edit_modal import VMEditModal

        def on_save(result: bool) -> None:
            if result:
                self._load_data()
                self.notify("VM updated")

        self.app.push_screen(VMEditModal(self.app.current_env, self._vms[key].config), on_save)

    def action_deploy_vm(self) -> None:
        key = self._get_selected_key()
        if not key:
            self.notify("No VM selected", severity="warning")
            return
        from ..task_runner.registry import terraform_deploy_vm

        self.app.run_task(
            terraform_deploy_vm(self.app.current_env, key),
            f"Deploy VM: {key}",
        )

    def action_destroy_vm(self) -> None:
        key = self._get_selected_key()
        if not key:
            self.notify("No VM selected", severity="warning")
            return

        from .confirm_dialog import ConfirmDialog
        from ..task_runner.registry import terraform_destroy_vm

        def on_confirm(confirmed: bool) -> None:
            if confirmed:
                self.app.run_task(
                    terraform_destroy_vm(self.app.current_env, key),
                    f"Destroy VM: {key}",
                )

        self.app.push_screen(
            ConfirmDialog(
                f"Destroy VM '{key}'?\nThis will permanently delete the VM from Proxmox.",
                title="Destroy VM",
            ),
            on_confirm,
        )

    def action_refresh(self) -> None:
        self._load_data()
        self.notify("Refreshed")

    def action_dashboard(self) -> None:
        self.app.switch_screen("dashboard")

    def on_button_pressed(self, event: Button.Pressed) -> None:
        actions = {
            "btn-new": self.action_new_vm,
            "btn-edit": self.action_edit_vm,
            "btn-deploy": self.action_deploy_vm,
            "btn-destroy": self.action_destroy_vm,
        }
        action = actions.get(event.button.id)
        if action:
            action()
