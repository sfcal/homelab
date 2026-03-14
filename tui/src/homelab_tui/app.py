from collections.abc import Callable

from textual.app import App
from textual.binding import Binding
from textual import work

from .config import PROJECT_ROOT
from .data.discovery import discover_environments
from .screens.dashboard import DashboardScreen
from .screens.dns import DNSScreen
from .screens.docker_view import DockerScreen
from .screens.ntp import NTPScreen
from .screens.output import OutputScreen
from .screens.tasks import TasksScreen
from .task_runner.runner import TaskRunner


TABS = [
    ("1", "dashboard", "Dashboard"),
    ("2", "dns", "DNS"),
    ("3", "ntp", "NTP"),
    ("4", "docker", "Docker"),
    ("5", "tasks", "Tasks"),
    ("6", "output", "Output"),
]


class HomelabApp(App):
    """Homelab infrastructure management TUI."""

    TITLE = "Homelab Manager"
    CSS_PATH = "css/app.tcss"

    BINDINGS = [
        Binding("1", "tab_1", "Dashboard", show=True),
        Binding("2", "tab_2", "DNS", show=True),
        Binding("3", "tab_3", "NTP", show=True),
        Binding("4", "tab_4", "Docker", show=True),
        Binding("5", "tab_5", "Tasks", show=True),
        Binding("6", "tab_6", "Output", show=True),
        Binding("e", "switch_env", "Env", show=True),
        Binding("q", "quit", "Quit", show=True),
        Binding("h", "vim_left", show=False),
        Binding("j", "vim_down", show=False),
        Binding("k", "vim_up", show=False),
        Binding("l", "vim_right", show=False),
    ]

    current_env: str = ""

    def __init__(self):
        super().__init__()
        self.task_runner = TaskRunner(PROJECT_ROOT)
        # Set default environment
        envs = discover_environments()
        self.current_env = "wil" if "wil" in envs else (envs[0] if envs else "wil")

    def on_mount(self) -> None:
        self.install_screen(DashboardScreen(), name="dashboard")
        self.install_screen(DNSScreen(), name="dns")
        self.install_screen(NTPScreen(), name="ntp")
        self.install_screen(DockerScreen(), name="docker")
        self.install_screen(TasksScreen(), name="tasks")
        self.install_screen(OutputScreen(), name="output")
        self.push_screen("dashboard")
        self.sub_title = f"env: {self.current_env}"

    def _switch_to(self, name: str) -> None:
        self.switch_screen(name)

    def action_tab_1(self) -> None:
        self._switch_to("dashboard")

    def action_tab_2(self) -> None:
        self._switch_to("dns")

    def action_tab_3(self) -> None:
        self._switch_to("ntp")

    def action_tab_4(self) -> None:
        self._switch_to("docker")

    def action_tab_5(self) -> None:
        self._switch_to("tasks")

    def action_tab_6(self) -> None:
        self._switch_to("output")

    def _vim_navigate(self, direction: str) -> None:
        focused = self.focused
        if focused is None:
            return
        action = f"cursor_{direction}" if hasattr(focused, f"action_cursor_{direction}") else f"scroll_{direction}"
        if hasattr(focused, f"action_{action}"):
            getattr(focused, f"action_{action}")()

    def action_vim_left(self) -> None:
        self._vim_navigate("left")

    def action_vim_down(self) -> None:
        self._vim_navigate("down")

    def action_vim_up(self) -> None:
        self._vim_navigate("up")

    def action_vim_right(self) -> None:
        self._vim_navigate("right")

    def action_switch_env(self) -> None:
        """Cycle through available environments."""
        envs = discover_environments()
        if not envs:
            return
        try:
            idx = envs.index(self.current_env)
            next_idx = (idx + 1) % len(envs)
        except ValueError:
            next_idx = 0
        self.current_env = envs[next_idx]
        self.sub_title = f"env: {self.current_env}"
        self.notify(f"Switched to: {self.current_env}")
        self._reload_current_screen()

    def _reload_current_screen(self) -> None:
        """Reload the active screen's data for the new environment."""
        screen = self.screen
        if hasattr(screen, "_load_data"):
            screen._load_data()
        elif hasattr(screen, "_load_tasks"):
            screen._load_tasks()

    def run_task(
        self,
        command: list[str],
        description: str,
        on_success: Callable[[], None] | None = None,
    ) -> None:
        """Execute a task command and show output in the output screen."""
        output_screen: OutputScreen = self.get_screen("output")
        pane_id = output_screen.create_pane(description)
        output_screen.append_line(pane_id, f"$ {' '.join(command)}")
        output_screen.append_line(pane_id, "")
        self.switch_screen("output")
        self._execute_task(command, description, pane_id, on_success)

    @work(thread=False)
    async def _execute_task(
        self,
        command: list[str],
        description: str,
        pane_id: str,
        on_success: Callable[[], None] | None = None,
    ) -> None:
        output_screen: OutputScreen = self.get_screen("output")

        def on_output(task_id: str, line: str) -> None:
            output_screen.append_line(pane_id, line)

        task = await self.task_runner.run(
            command, description, on_output=on_output
        )

        output_screen.append_line(pane_id, "")
        if task.status.value == "completed":
            output_screen.append_line(pane_id, "[green]Task completed successfully[/green]")
            output_screen.mark_complete(pane_id, True)
            self.notify(f"{description} completed", severity="information")
            if on_success:
                on_success()
        else:
            output_screen.append_line(
                pane_id,
                f"[red]Task failed (exit code: {task.return_code})[/red]",
            )
            output_screen.mark_complete(pane_id, False)
            self.notify(f"{description} failed", severity="error")


def main():
    app = HomelabApp()
    app.run()


if __name__ == "__main__":
    main()
