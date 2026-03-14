"""Packer screen — template building."""

from textual.app import ComposeResult
from textual.binding import Binding
from textual.screen import Screen
from textual.widgets import DataTable, Footer, Header, Static

from ..data.discovery import discover_packer_templates
from ..data.models import PackerTemplate
from ..task_runner.registry import packer_build


class PackerScreen(Screen):
    BINDINGS = [
        Binding("enter", "build", "Build"),
        Binding("r", "refresh", "Refresh"),
    ]

    DEFAULT_CSS = """
    #packer-title {
        padding: 0 1;
        text-style: bold;
    }
    #packer-table {
        height: 1fr;
        margin: 0 1;
    }
    #packer-status {
        height: 1;
        padding: 0 1;
        color: $text-muted;
    }
    """

    def __init__(self) -> None:
        super().__init__()
        self._templates: list[PackerTemplate] = []

    def compose(self) -> ComposeResult:
        yield Header()
        yield Static("Packer Templates", id="packer-title")
        yield DataTable(id="packer-table", cursor_type="row")
        yield Static("", id="packer-status")
        yield Footer()

    def on_mount(self) -> None:
        table = self.query_one("#packer-table", DataTable)
        table.add_columns("Template Name", "Filename")
        self._load_data()

    def on_screen_resume(self) -> None:
        self._load_data()

    def _load_data(self) -> None:
        self._templates = discover_packer_templates()

        self.query_one("#packer-title", Static).update(
            f"Packer Templates — env: [bold]{self.app.current_env}[/bold]"
        )

        table = self.query_one("#packer-table", DataTable)
        table.clear()
        for t in self._templates:
            table.add_row(t.name, t.filename, key=t.name)

        self.query_one("#packer-status", Static).update(
            f"{len(self._templates)} templates found"
        )

    def _get_selected_template(self) -> PackerTemplate | None:
        table = self.query_one("#packer-table", DataTable)
        if table.row_count == 0:
            return None
        row_key = table.coordinate_to_cell_key(table.cursor_coordinate).row_key
        name = str(row_key.value)
        for t in self._templates:
            if t.name == name:
                return t
        return None

    def action_build(self) -> None:
        template = self._get_selected_template()
        if not template:
            self.notify("No template selected", severity="warning")
            return
        self.app.run_task(
            packer_build(self.app.current_env, template.name),
            f"Build: {template.name}",
        )

    def on_data_table_row_selected(self, event: DataTable.RowSelected) -> None:
        self.action_build()

    def action_refresh(self) -> None:
        self._load_data()
