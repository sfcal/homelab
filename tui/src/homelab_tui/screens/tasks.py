"""Tasks screen — dynamically discovered task execution."""

from __future__ import annotations

import re

from textual.app import ComposeResult
from textual.binding import Binding
from textual.screen import Screen
from textual.widgets import DataTable, Footer, Header, Static
from textual import work

from ..data.discovery import discover_tasks
from ..data.models import TaskInfo
from ..task_runner.registry import task_command
from ..widgets.task_input_modal import TaskInputModal


# Patterns that suggest a task needs extra variables
EXTRA_VAR_PATTERNS = {
    r"deploy-vm": ["VM"],
    r"destroy-vm": ["VM"],
    r"build": ["TEMPLATE"],
    r"sign": ["CSR"],
}


class TasksScreen(Screen):
    BINDINGS = [
        Binding("enter", "run_task", "Run"),
        Binding("r", "refresh", "Refresh"),
    ]

    DEFAULT_CSS = """
    #tasks-title {
        padding: 0 1;
        text-style: bold;
    }
    #tasks-table {
        height: 1fr;
        margin: 0 1;
    }
    #tasks-status {
        height: 1;
        padding: 0 1;
        color: $text-muted;
    }
    """

    def __init__(self) -> None:
        super().__init__()
        self._tasks: list[TaskInfo] = []
        self._tasks_by_name: dict[str, TaskInfo] = {}

    def compose(self) -> ComposeResult:
        yield Header()
        yield Static("Tasks", id="tasks-title")
        yield DataTable(id="tasks-table", cursor_type="row")
        yield Static("Loading tasks...", id="tasks-status")
        yield Footer()

    def on_mount(self) -> None:
        table = self.query_one("#tasks-table", DataTable)
        table.add_columns("Namespace", "Task", "Description")
        self._load_tasks()

    def on_screen_resume(self) -> None:
        self._load_tasks()

    @work(thread=False)
    async def _load_tasks(self) -> None:
        tasks = await discover_tasks()
        self._tasks = tasks
        self._tasks_by_name = {t.name: t for t in tasks}

        # Group by namespace
        namespaces: dict[str, list[TaskInfo]] = {}
        for t in tasks:
            ns = t.namespace or "(root)"
            namespaces.setdefault(ns, []).append(t)

        self.query_one("#tasks-title", Static).update(
            f"Tasks — env: [bold]{self.app.current_env}[/bold]"
        )

        table = self.query_one("#tasks-table", DataTable)
        table.clear()
        for ns in sorted(namespaces.keys()):
            for t in namespaces[ns]:
                table.add_row(ns, t.short_name, t.description, key=t.name)

        self.query_one("#tasks-status", Static).update(
            f"{len(tasks)} tasks discovered"
        )

    def _get_selected_task(self) -> TaskInfo | None:
        table = self.query_one("#tasks-table", DataTable)
        if table.row_count == 0:
            return None
        row_key = table.coordinate_to_cell_key(table.cursor_coordinate).row_key
        return self._tasks_by_name.get(str(row_key.value))

    def _detect_extra_vars(self, task_name: str) -> list[str]:
        """Detect if a task needs extra variables based on its name."""
        for pattern, vars_needed in EXTRA_VAR_PATTERNS.items():
            if re.search(pattern, task_name):
                return vars_needed
        return []

    def action_run_task(self) -> None:
        task = self._get_selected_task()
        if not task:
            self.notify("No task selected", severity="warning")
            return

        extra_vars = self._detect_extra_vars(task.name)
        if extra_vars:
            self._prompt_and_run(task, extra_vars)
        else:
            self._execute_task(task, {})

    def _prompt_and_run(self, task: TaskInfo, variables: list[str]) -> None:
        def on_result(result: dict[str, str] | None) -> None:
            if result is not None:
                self._execute_task(task, result)

        self.app.push_screen(
            TaskInputModal(f"Run: {task.name}", variables),
            on_result,
        )

    def _execute_task(self, task: TaskInfo, extra_vars: dict[str, str]) -> None:
        env = self.app.current_env
        cmd = task_command(task.name, env, **extra_vars)
        desc = task.description or task.name
        self.app.run_task(cmd, desc)

    def on_data_table_row_selected(self, event: DataTable.RowSelected) -> None:
        self.action_run_task()

    def action_refresh(self) -> None:
        self._load_tasks()
