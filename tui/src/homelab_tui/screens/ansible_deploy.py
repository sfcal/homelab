from textual.app import ComposeResult
from textual.binding import Binding
from textual.screen import Screen
from textual.widgets import DataTable, Footer, Header, Static

from ..data.environment import load_environment
from ..task_runner.registry import ansible_task


class AnsibleDeployScreen(Screen):
    BINDINGS = [
        Binding("enter", "run_selected", "Run"),
        Binding("r", "refresh", "Refresh"),
        Binding("escape", "dashboard", "Dashboard"),
    ]

    DEFAULT_CSS = """
    #ansible-title {
        padding: 0 1;
        text-style: bold;
    }
    #playbook-table {
        height: 1fr;
        margin: 1 1;
    }
    """

    def compose(self) -> ComposeResult:
        yield Header()
        yield Static(f"Ansible Deployments - {self.app.current_env}", id="ansible-title")
        yield DataTable(id="playbook-table", cursor_type="row")
        yield Footer()

    def on_mount(self) -> None:
        self._load_data()

    def _load_data(self) -> None:
        env = load_environment(self.app.current_env)
        self._playbooks = {pb.task_name: pb for pb in env.playbooks}
        table = self.query_one("#playbook-table", DataTable)
        table.clear(columns=True)
        table.add_columns("Task", "Name", "Description", "Target Group")
        for pb in env.playbooks:
            table.add_row(
                pb.task_name,
                pb.display_name,
                pb.description,
                pb.hosts_group or "all",
                key=pb.task_name,
            )
        try:
            self.query_one("#ansible-title", Static).update(
                f"Ansible Deployments - {self.app.current_env}"
            )
        except Exception:
            pass

    def action_run_selected(self) -> None:
        table = self.query_one("#playbook-table", DataTable)
        if table.row_count == 0:
            return
        row_key = table.coordinate_to_cell_key(table.cursor_coordinate).row_key
        task_name = str(row_key.value)
        pb = self._playbooks.get(task_name)
        if pb:
            self.app.run_task(
                ansible_task(task_name, self.app.current_env),
                f"Ansible: {pb.display_name}",
            )

    def on_data_table_row_selected(self, event: DataTable.RowSelected) -> None:
        task_name = str(event.row_key.value)
        pb = self._playbooks.get(task_name)
        if pb:
            self.app.run_task(
                ansible_task(task_name, self.app.current_env),
                f"Ansible: {pb.display_name}",
            )

    def action_refresh(self) -> None:
        self._load_data()
        self.notify("Refreshed")

    def action_dashboard(self) -> None:
        self.app.switch_screen("dashboard")
