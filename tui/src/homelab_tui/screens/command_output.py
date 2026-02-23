from textual.app import ComposeResult
from textual.binding import Binding
from textual.screen import Screen
from textual.widgets import Footer, Header, RichLog, Static


class CommandOutputScreen(Screen):
    BINDINGS = [
        Binding("c", "clear_log", "Clear"),
        Binding("escape", "go_back", "Back"),
    ]

    def __init__(self, title: str = "Command Output"):
        super().__init__()
        self._title = title
        self._pending_lines: list[str] = []
        self._mounted = False

    def compose(self) -> ComposeResult:
        yield Header()
        yield Static(self._title, id="output-title")
        yield RichLog(id="log-viewer", highlight=True, markup=True, wrap=True)
        yield Footer()

    def on_mount(self) -> None:
        self._mounted = True
        # Flush any lines that were queued before mount
        if self._pending_lines:
            log = self.query_one("#log-viewer", RichLog)
            for line in self._pending_lines:
                log.write(line)
            self._pending_lines.clear()

    def on_screen_resume(self) -> None:
        """Called when this screen becomes active again after being suspended."""
        self._mounted = True
        if self._pending_lines:
            log = self.query_one("#log-viewer", RichLog)
            for line in self._pending_lines:
                log.write(line)
            self._pending_lines.clear()

    def append_line(self, line: str) -> None:
        if self._mounted:
            try:
                self.query_one("#log-viewer", RichLog).write(line)
            except Exception:
                self._pending_lines.append(line)
        else:
            self._pending_lines.append(line)

    def set_title(self, title: str) -> None:
        self._title = title
        if self._mounted:
            try:
                self.query_one("#output-title", Static).update(title)
            except Exception:
                pass

    def clear_log(self) -> None:
        self._pending_lines.clear()
        if self._mounted:
            try:
                self.query_one("#log-viewer", RichLog).clear()
            except Exception:
                pass

    def action_clear_log(self) -> None:
        self.clear_log()

    def action_go_back(self) -> None:
        self.app.switch_screen("dashboard")
