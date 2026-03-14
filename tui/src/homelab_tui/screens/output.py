"""Output screen — multi-pane concurrent command output viewer."""

from __future__ import annotations

from textual.app import ComposeResult
from textual.binding import Binding
from textual.screen import Screen
from textual.widgets import Footer, Header, RichLog, Static, TabbedContent, TabPane


class OutputPane:
    """Tracks a single command output."""

    def __init__(self, pane_id: str, description: str):
        self.pane_id = pane_id
        self.description = description
        self.lines: list[str] = []
        self.status: str = "running"


class OutputScreen(Screen):
    BINDINGS = [
        Binding("c", "clear_all", "Clear All"),
    ]

    DEFAULT_CSS = """
    #output-title {
        padding: 0 1;
        text-style: bold;
    }
    #output-tabs {
        height: 1fr;
    }
    #output-status {
        height: 1;
        padding: 0 1;
        color: $text-muted;
    }
    """

    def __init__(self) -> None:
        super().__init__()
        self._panes: dict[str, OutputPane] = {}
        self._counter = 0
        self._synced_panes: set[str] = set()

    def compose(self) -> ComposeResult:
        yield Header()
        yield Static("Command Output", id="output-title")
        yield TabbedContent(id="output-tabs")
        yield Static("No commands running", id="output-status")
        yield Footer()

    def on_mount(self) -> None:
        self._sync_panes()

    def on_screen_resume(self) -> None:
        self._sync_panes()

    def _sync_panes(self) -> None:
        """Create DOM elements for any panes that haven't been synced yet."""
        for pane_id, pane in self._panes.items():
            if pane_id not in self._synced_panes:
                self._create_pane_dom(pane)
        self._update_status()

    def _create_pane_dom(self, pane: OutputPane) -> None:
        """Create the TabPane + RichLog in the DOM and replay buffered lines."""
        try:
            tabs = self.query_one("#output-tabs", TabbedContent)
            log = RichLog(
                highlight=True, markup=True, wrap=True,
                id=f"log-{pane.pane_id}",
            )
            tab_pane = TabPane(pane.description, log, id=pane.pane_id)
            tabs.add_pane(tab_pane)
            tabs.active = pane.pane_id
            self._synced_panes.add(pane.pane_id)
            # Replay any buffered lines
            for line in pane.lines:
                log.write(line)
        except Exception:
            pass

    def create_pane(self, description: str) -> str:
        """Create a new output pane and return its ID."""
        self._counter += 1
        pane_id = f"output-{self._counter}"
        pane = OutputPane(pane_id, description)
        self._panes[pane_id] = pane

        if self.is_current:
            self._create_pane_dom(pane)

        self._update_status()
        return pane_id

    def append_line(self, pane_id: str, line: str) -> None:
        """Append a line to a specific output pane."""
        pane = self._panes.get(pane_id)
        if not pane:
            return
        pane.lines.append(line)
        if pane_id in self._synced_panes:
            try:
                log = self.query_one(f"#log-{pane_id}", RichLog)
                log.write(line)
            except Exception:
                pass

    def mark_complete(self, pane_id: str, success: bool) -> None:
        """Mark a pane as completed or failed."""
        pane = self._panes.get(pane_id)
        if pane:
            pane.status = "completed" if success else "failed"
        self._update_status()

    def _update_status(self) -> None:
        try:
            running = sum(1 for p in self._panes.values() if p.status == "running")
            total = len(self._panes)
            if total == 0:
                text = "No commands running"
            elif running > 0:
                text = f"{running} running, {total} total"
            else:
                text = f"{total} completed"
            self.query_one("#output-status", Static).update(text)
        except Exception:
            pass

    def action_clear_all(self) -> None:
        """Clear all completed output panes."""
        to_remove = [
            pid for pid, p in self._panes.items() if p.status != "running"
        ]
        for pid in to_remove:
            try:
                tabs = self.query_one("#output-tabs", TabbedContent)
                tabs.remove_pane(pid)
            except Exception:
                pass
            self._synced_panes.discard(pid)
            del self._panes[pid]

        self._update_status()
        self.notify("Cleared completed outputs")
