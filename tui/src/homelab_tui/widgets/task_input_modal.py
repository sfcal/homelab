from textual.app import ComposeResult
from textual.containers import Horizontal, Vertical
from textual.screen import ModalScreen
from textual.widgets import Button, Input, Label


class TaskInputModal(ModalScreen[dict[str, str] | None]):
    """Modal for collecting extra task variables (e.g., VM=, CSR=, TEMPLATE=)."""

    DEFAULT_CSS = """
    TaskInputModal {
        align: center middle;
    }
    #task-input-dialog {
        width: 60;
        height: auto;
        border: thick $accent;
        background: $surface;
        padding: 1 2;
    }
    #task-input-title {
        text-style: bold;
        width: 100%;
        content-align: center middle;
        margin-bottom: 1;
    }
    .var-row {
        height: 3;
        margin-bottom: 0;
    }
    .var-label {
        width: 15;
        padding: 1 1 0 0;
    }
    .var-input {
        width: 1fr;
    }
    #task-input-buttons {
        width: 100%;
        align-horizontal: center;
        margin-top: 1;
    }
    #task-input-buttons Button {
        margin: 0 1;
    }
    """

    def __init__(self, title: str, variables: list[str]):
        super().__init__()
        self._title = title
        self._variables = variables

    def compose(self) -> ComposeResult:
        with Vertical(id="task-input-dialog"):
            yield Label(self._title, id="task-input-title")
            for var in self._variables:
                with Horizontal(classes="var-row"):
                    yield Label(f"{var}:", classes="var-label")
                    yield Input(
                        placeholder=f"Enter {var}",
                        id=f"var-{var}",
                        classes="var-input",
                    )
            with Horizontal(id="task-input-buttons"):
                yield Button("Run", variant="primary", id="btn-run")
                yield Button("Cancel", variant="default", id="btn-cancel")

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "btn-cancel":
            self.dismiss(None)
            return
        if event.button.id == "btn-run":
            result = {}
            for var in self._variables:
                val = self.query_one(f"#var-{var}", Input).value.strip()
                if val:
                    result[var] = val
            self.dismiss(result)
