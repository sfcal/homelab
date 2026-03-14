"""NTP screen — chrony tracking and sources via SSH."""

from __future__ import annotations

import asyncio

from textual.app import ComposeResult
from textual.binding import Binding
from textual.screen import Screen
from textual.widgets import Footer, Header, RichLog, Static
from textual.containers import Horizontal
from textual import work

from ..data.environment import get_infra_host_ip, get_ssh_user


class NTPScreen(Screen):
    BINDINGS = [
        Binding("r", "refresh", "Refresh"),
    ]

    DEFAULT_CSS = """
    #ntp-title {
        padding: 0 1;
        text-style: bold;
    }
    #ntp-panels {
        height: 1fr;
    }
    #ntp-tracking {
        width: 1fr;
        border: round $primary;
        margin: 0 1;
    }
    #ntp-sources {
        width: 1fr;
        border: round $secondary;
        margin: 0 1;
    }
    #ntp-status {
        height: 1;
        padding: 0 1;
        color: $text-muted;
    }
    """

    def compose(self) -> ComposeResult:
        yield Header()
        yield Static("NTP Status", id="ntp-title")
        with Horizontal(id="ntp-panels"):
            yield RichLog(id="ntp-tracking", highlight=True, markup=True, wrap=True)
            yield RichLog(id="ntp-sources", highlight=True, markup=True, wrap=True)
        yield Static("", id="ntp-status")
        yield Footer()

    def on_mount(self) -> None:
        self._load_data()

    def on_screen_resume(self) -> None:
        self._load_data()

    def _load_data(self) -> None:
        self._fetch_ntp_data()

    @work(thread=False)
    async def _fetch_ntp_data(self) -> None:
        ntp_host = get_infra_host_ip(self.app.current_env, "infra_ntp")
        if not ntp_host:
            self.query_one("#ntp-status", Static).update("No NTP server found (infra_ntp)")
            return

        ssh_user = get_ssh_user(self.app.current_env)
        self.query_one("#ntp-title", Static).update(
            f"NTP Status — {ssh_user}@{ntp_host} — env: [bold]{self.app.current_env}[/bold]"
        )

        tracking_log = self.query_one("#ntp-tracking", RichLog)
        sources_log = self.query_one("#ntp-sources", RichLog)

        tracking = await self._ssh_command(ssh_user, ntp_host, "chronyc tracking")
        tracking_log.clear()
        tracking_log.write("[bold]Tracking[/bold]")
        tracking_log.write(tracking)

        sources = await self._ssh_command(ssh_user, ntp_host, "chronyc sources -v")
        sources_log.clear()
        sources_log.write("[bold]Sources[/bold]")
        sources_log.write(sources)

        self.query_one("#ntp-status", Static).update("Press r to refresh")

    async def _ssh_command(self, user: str, host: str, command: str) -> str:
        try:
            proc = await asyncio.create_subprocess_exec(
                "ssh", "-o", "StrictHostKeyChecking=no", "-o", "ConnectTimeout=3",
                "-o", "BatchMode=yes",
                f"{user}@{host}", command,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
            stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=10.0)
            return stdout.decode("utf-8", errors="replace")
        except asyncio.TimeoutError:
            return "(SSH timeout)"
        except Exception as e:
            return f"(SSH error: {e})"

    def action_refresh(self) -> None:
        self._load_data()
