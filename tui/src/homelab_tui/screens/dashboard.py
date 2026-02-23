from textual.app import ComposeResult
from textual.binding import Binding
from textual.containers import Horizontal
from textual.screen import Screen
from textual.widgets import Button, DataTable, Footer, Header, Select, Static

from ..data.environment import load_environment
from ..config import ENVIRONMENTS


class DashboardScreen(Screen):
    BINDINGS = [
        Binding("r", "refresh", "Refresh"),
        Binding("v", "vm_screen", "VMs"),
        Binding("a", "ansible_screen", "Ansible"),
        Binding("q", "quit", "Quit"),
    ]

    DEFAULT_CSS = """
    #top-bar {
        height: 3;
        padding: 0 1;
        align: left middle;
    }
    #env-label {
        width: auto;
        padding: 0 1;
    }
    #env-selector {
        width: 20;
    }
    #vm-overview {
        height: 1fr;
        margin: 1 1;
    }
    #quick-actions {
        height: 3;
        padding: 0 1;
        align: center middle;
    }
    #quick-actions Button {
        margin: 0 1;
    }
    """

    def compose(self) -> ComposeResult:
        yield Header()
        with Horizontal(id="top-bar"):
            yield Static("Environment:", id="env-label")
            yield Select(
                [(env, env) for env in ENVIRONMENTS],
                value=self.app.current_env,
                id="env-selector",
                allow_blank=False,
            )
        yield DataTable(id="vm-overview")
        with Horizontal(id="quick-actions"):
            yield Button("Deploy All (TF)", id="btn-tf-deploy")
            yield Button("Deploy All (Ansible)", id="btn-ansible-deploy")
            yield Button("Ping All", id="btn-ping")
        yield Footer()

    def on_mount(self) -> None:
        self._load_data()

    def _load_data(self) -> None:
        env = load_environment(self.app.current_env)
        table = self.query_one("#vm-overview", DataTable)
        table.clear(columns=True)
        table.add_columns("Key", "Name", "IP Address", "VMID", "Cores", "RAM (MB)", "Disk", "Status")
        for key, vm_state in env.vms.items():
            c = vm_state.config
            table.add_row(
                key,
                c.name,
                c.ip_address,
                str(c.vmid),
                str(c.cores),
                str(c.memory),
                c.disk_size,
                vm_state.status.value,
                key=key,
            )

    def on_select_changed(self, event: Select.Changed) -> None:
        if event.select.id == "env-selector" and event.value is not None:
            self.app.current_env = event.value
            self._load_data()

    def action_refresh(self) -> None:
        self._load_data()
        self.notify("Refreshed")

    def action_vm_screen(self) -> None:
        self.app.switch_screen("vm_management")

    def action_ansible_screen(self) -> None:
        self.app.switch_screen("ansible_deploy")

    def on_button_pressed(self, event: Button.Pressed) -> None:
        from ..task_runner.registry import ansible_task, terraform_deploy_all

        env = self.app.current_env
        if event.button.id == "btn-tf-deploy":
            self.app.run_task(terraform_deploy_all(env), "Deploy All (Terraform)")
        elif event.button.id == "btn-ansible-deploy":
            self.app.run_task(ansible_task("ansible:deploy-all", env), "Deploy All (Ansible)")
        elif event.button.id == "btn-ping":
            self.app.run_task(ansible_task("ansible:ping", env), "Ping All Hosts")
