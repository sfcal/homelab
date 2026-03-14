from textual.app import ComposeResult
from textual.containers import Horizontal
from textual.message import Message
from textual.widget import Widget
from textual.widgets import Select, Static

from ..data.discovery import discover_environments


class EnvSelector(Widget):
    """Global environment selector widget."""

    DEFAULT_CSS = """
    EnvSelector {
        height: 3;
        padding: 0 1;
        layout: horizontal;
        align: left middle;
    }
    EnvSelector #env-label {
        width: auto;
        padding: 0 1 0 0;
        content-align: left middle;
    }
    EnvSelector #env-select {
        width: 20;
    }
    """

    class Changed(Message):
        def __init__(self, value: str) -> None:
            super().__init__()
            self.value = value

    def __init__(self, current: str) -> None:
        super().__init__()
        self._current = current

    def compose(self) -> ComposeResult:
        envs = discover_environments()
        yield Static("ENV:", id="env-label")
        yield Select(
            [(e, e) for e in envs],
            value=self._current,
            id="env-select",
            allow_blank=False,
        )

    def on_select_changed(self, event: Select.Changed) -> None:
        if event.select.id == "env-select" and event.value is not None:
            self.post_message(self.Changed(event.value))
