from textual.app import App
from textual.binding import Binding
from textual import work

from .config import PROJECT_ROOT
from .screens.ansible_deploy import AnsibleDeployScreen
from .screens.command_output import CommandOutputScreen
from .screens.dashboard import DashboardScreen
from .screens.vm_management import VMManagementScreen
from .task_runner.runner import TaskRunner


class HomelabApp(App):
    """Homelab infrastructure management TUI."""

    TITLE = "Homelab Manager"
    CSS_PATH = "css/app.tcss"

    BINDINGS = [
        Binding("1", "goto_dashboard", "Dashboard", show=True),
        Binding("2", "goto_vms", "VMs", show=True),
        Binding("3", "goto_ansible", "Ansible", show=True),
        Binding("4", "goto_logs", "Logs", show=True),
        Binding("q", "quit", "Quit", show=True),
    ]

    current_env: str = "wil"

    def __init__(self):
        super().__init__()
        self.task_runner = TaskRunner(PROJECT_ROOT)

    def on_mount(self) -> None:
        self.install_screen(DashboardScreen(), name="dashboard")
        self.install_screen(VMManagementScreen(), name="vm_management")
        self.install_screen(AnsibleDeployScreen(), name="ansible_deploy")
        self.install_screen(CommandOutputScreen(), name="command_output")
        self.push_screen("dashboard")

    def action_goto_dashboard(self) -> None:
        self.switch_screen("dashboard")

    def action_goto_vms(self) -> None:
        self.switch_screen("vm_management")

    def action_goto_ansible(self) -> None:
        self.switch_screen("ansible_deploy")

    def action_goto_logs(self) -> None:
        self.switch_screen("command_output")

    def run_task(self, command: list[str], description: str) -> None:
        """Execute a task command and show output in the command output screen."""
        output_screen: CommandOutputScreen = self.get_screen("command_output")
        output_screen.clear_log()
        output_screen.set_title(f"Running: {description}")
        output_screen.append_line(f"$ {' '.join(command)}")
        output_screen.append_line("")
        self.switch_screen("command_output")
        self._execute_task(command, description)

    @work(thread=False)
    async def _execute_task(self, command: list[str], description: str) -> None:
        output_screen: CommandOutputScreen = self.get_screen("command_output")

        def on_output(task_id: str, line: str) -> None:
            output_screen.append_line(line)

        task = await self.task_runner.run(
            command, description, on_output=on_output
        )

        output_screen.append_line("")
        if task.status.value == "completed":
            output_screen.append_line("[green]Task completed successfully[/green]")
            output_screen.set_title(f"Completed: {description}")
            self.notify(f"{description} completed", severity="information")
        else:
            output_screen.append_line(
                f"[red]Task failed (exit code: {task.return_code})[/red]"
            )
            output_screen.set_title(f"Failed: {description}")
            self.notify(f"{description} failed", severity="error")


def main():
    app = HomelabApp()
    app.run()


if __name__ == "__main__":
    main()
