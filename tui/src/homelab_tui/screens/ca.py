"""CA screen — Certificate Authority health and management."""

from __future__ import annotations

import asyncio

from textual.app import ComposeResult
from textual.binding import Binding
from textual.containers import Horizontal, Vertical
from textual.screen import Screen
from textual.widgets import Button, Footer, Header, RichLog, Static
from textual import work

from ..data.environment import get_infra_host_ip
from ..task_runner.registry import task_command


class CAScreen(Screen):
    BINDINGS = [
        Binding("r", "refresh", "Refresh"),
    ]

    DEFAULT_CSS = """
    #ca-title {
        padding: 0 1;
        text-style: bold;
    }
    #ca-content {
        height: 1fr;
    }
    #ca-health {
        width: 1fr;
        border: round $primary;
        margin: 0 1;
    }
    #ca-info {
        width: 1fr;
        border: round $secondary;
        margin: 0 1;
    }
    #ca-actions {
        height: 3;
        padding: 0 1;
        align: center middle;
    }
    #ca-actions Button {
        margin: 0 1;
    }
    #ca-status {
        height: 1;
        padding: 0 1;
        color: $text-muted;
    }
    """

    def compose(self) -> ComposeResult:
        yield Header()
        yield Static("Certificate Authority", id="ca-title")
        with Horizontal(id="ca-content"):
            yield RichLog(id="ca-health", highlight=True, markup=True, wrap=True)
            yield RichLog(id="ca-info", highlight=True, markup=True, wrap=True)
        with Horizontal(id="ca-actions"):
            yield Button("Check Health", id="btn-ca-health")
            yield Button("Fetch Root", id="btn-ca-root")
        yield Static("", id="ca-status")
        yield Footer()

    def on_mount(self) -> None:
        self._load_data()

    def on_screen_resume(self) -> None:
        self._load_data()

    def _load_data(self) -> None:
        self._fetch_ca_data()

    @work(thread=False)
    async def _fetch_ca_data(self) -> None:
        ca_host = get_infra_host_ip(self.app.current_env, "infra_ca")
        if not ca_host:
            self.query_one("#ca-status", Static).update("No CA server found (infra_ca)")
            return

        self.query_one("#ca-title", Static).update(
            f"Certificate Authority — {ca_host} — env: [bold]{self.app.current_env}[/bold]"
        )

        health_log = self.query_one("#ca-health", RichLog)
        info_log = self.query_one("#ca-info", RichLog)

        health_log.clear()
        health_log.write("[bold]Health Status[/bold]")
        health = await self._check_health(ca_host)
        health_log.write(health)

        info_log.clear()
        info_log.write("[bold]Root CA Info[/bold]")
        root_info = await self._get_root_info(ca_host)
        info_log.write(root_info)

        self.query_one("#ca-status", Static).update("Press r to refresh")

    async def _check_health(self, host: str) -> str:
        try:
            proc = await asyncio.create_subprocess_exec(
                "curl", "-sk", f"https://{host}:9000/health",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
            stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=5.0)
            return stdout.decode("utf-8", errors="replace") or "(no response)"
        except asyncio.TimeoutError:
            return "[red]Health check timed out[/red]"
        except Exception as e:
            return f"[red]Error: {e}[/red]"

    async def _get_root_info(self, host: str) -> str:
        try:
            proc = await asyncio.create_subprocess_exec(
                "curl", "-sk", f"https://{host}:9000/root",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
            stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=5.0)
            cert_pem = stdout.decode("utf-8", errors="replace")
            if not cert_pem.strip():
                return "(no root cert available)"
            openssl_proc = await asyncio.create_subprocess_exec(
                "openssl", "x509", "-text", "-noout",
                stdin=asyncio.subprocess.PIPE,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
            out, _ = await openssl_proc.communicate(input=cert_pem.encode())
            return out.decode("utf-8", errors="replace") if out else cert_pem
        except Exception as e:
            return f"(error fetching root: {e})"

    def on_button_pressed(self, event: Button.Pressed) -> None:
        env = self.app.current_env
        if event.button.id == "btn-ca-health":
            self.app.run_task(task_command("ca:health", env), "CA Health Check")
        elif event.button.id == "btn-ca-root":
            self.app.run_task(task_command("ca:root", env), "Fetch Root CA")

    def action_refresh(self) -> None:
        self._load_data()
