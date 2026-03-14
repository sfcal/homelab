"""Docker screen — aggregated container view across all VMs."""

from __future__ import annotations

import asyncio
import json

from textual.app import ComposeResult
from textual.binding import Binding
from textual.screen import Screen
from textual.widgets import DataTable, Footer, Header, Static
from textual import work

from ..data.environment import get_all_host_ips, get_ssh_user


class DockerScreen(Screen):
    BINDINGS = [
        Binding("r", "refresh", "Refresh"),
        Binding("z", "lazydocker", "Lazydocker"),
    ]

    DEFAULT_CSS = """
    #docker-title {
        padding: 0 1;
        text-style: bold;
    }
    #docker-table {
        height: 1fr;
        margin: 0 1;
    }
    #docker-status {
        height: 1;
        padding: 0 1;
        color: $text-muted;
    }
    """

    def __init__(self) -> None:
        super().__init__()
        self._containers: list[dict] = []

    def compose(self) -> ComposeResult:
        yield Header()
        yield Static("Docker Containers", id="docker-title")
        yield DataTable(id="docker-table", cursor_type="row")
        yield Static("", id="docker-status")
        yield Footer()

    def on_mount(self) -> None:
        table = self.query_one("#docker-table", DataTable)
        table.add_columns("Host", "Name", "Image", "Status", "Ports", "Uptime")
        self._load_data()

    def on_screen_resume(self) -> None:
        self._load_data()

    def _load_data(self) -> None:
        self._fetch_containers()

    @work(thread=False)
    async def _fetch_containers(self) -> None:
        env = self.app.current_env
        host_ips = get_all_host_ips(env)
        ssh_user = get_ssh_user(env)

        self.query_one("#docker-title", Static).update(
            f"Docker Containers — env: [bold]{env}[/bold] — {len(host_ips)} hosts"
        )

        all_containers: list[dict] = []
        tasks = [
            self._fetch_from_host(ssh_user, ip) for ip in host_ips
        ]
        results = await asyncio.gather(*tasks, return_exceptions=True)
        for ip, result in zip(host_ips, results):
            if isinstance(result, list):
                for c in result:
                    c["host"] = ip
                    all_containers.append(c)

        self._containers = all_containers

        table = self.query_one("#docker-table", DataTable)
        table.clear()
        for c in all_containers:
            table.add_row(
                c.get("host", ""),
                c.get("Names", ""),
                c.get("Image", ""),
                c.get("Status", ""),
                c.get("Ports", ""),
                c.get("RunningFor", ""),
            )

        self.query_one("#docker-status", Static).update(
            f"{len(all_containers)} containers across {len(host_ips)} hosts"
        )

    async def _fetch_from_host(self, user: str, host: str) -> list[dict]:
        try:
            proc = await asyncio.create_subprocess_exec(
                "ssh", "-o", "StrictHostKeyChecking=no", "-o", "ConnectTimeout=3",
                "-o", "BatchMode=yes",
                f"{user}@{host}",
                "docker ps --format '{{json .}}'",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
            stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=10.0)
            containers = []
            for line in stdout.decode("utf-8", errors="replace").strip().splitlines():
                line = line.strip()
                if line:
                    try:
                        containers.append(json.loads(line))
                    except json.JSONDecodeError:
                        pass
            return containers
        except (asyncio.TimeoutError, Exception):
            return []

    def action_refresh(self) -> None:
        self._load_data()

    def action_lazydocker(self) -> None:
        table = self.query_one("#docker-table", DataTable)
        if table.row_count == 0:
            self.notify("No containers to manage", severity="warning")
            return
        row_idx = table.cursor_coordinate.row
        if row_idx < len(self._containers):
            host = self._containers[row_idx].get("host", "")
            if host:
                ssh_user = get_ssh_user(self.app.current_env)
                self.app.run_task(
                    ["ssh", "-t", f"{ssh_user}@{host}", "lazydocker"],
                    f"Lazydocker on {host}",
                )
