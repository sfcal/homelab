"""DNS screen — live DNS query results against the environment's DNS server."""

from __future__ import annotations

import asyncio

from textual.app import ComposeResult
from textual.binding import Binding
from textual.screen import Screen
from textual.widgets import DataTable, Footer, Header, Static
from textual import work

from ..data.environment import get_infra_host_ip


class DNSScreen(Screen):
    BINDINGS = [
        Binding("r", "refresh", "Refresh"),
    ]

    DEFAULT_CSS = """
    #dns-title {
        padding: 0 1;
        text-style: bold;
    }
    #dns-table {
        height: 1fr;
        margin: 0 1;
    }
    #dns-status {
        height: 1;
        padding: 0 1;
        color: $text-muted;
    }
    """

    DOMAINS_TO_CHECK = [
        "google.com",
        "github.com",
        "cloudflare.com",
    ]

    def compose(self) -> ComposeResult:
        yield Header()
        yield Static("DNS Queries", id="dns-title")
        yield DataTable(id="dns-table")
        yield Static("", id="dns-status")
        yield Footer()

    def on_mount(self) -> None:
        table = self.query_one("#dns-table", DataTable)
        table.add_columns("Domain", "Type", "Result", "Response Time")
        self._load_data()

    def on_screen_resume(self) -> None:
        self._load_data()

    def _load_data(self) -> None:
        self._run_dns_queries()

    @work(thread=False)
    async def _run_dns_queries(self) -> None:
        dns_server = get_infra_host_ip(self.app.current_env, "infra_networking")
        if not dns_server:
            self.query_one("#dns-status", Static).update("No DNS server found (infra_networking)")
            return

        self.query_one("#dns-title", Static).update(
            f"DNS Queries — server: {dns_server} — env: [bold]{self.app.current_env}[/bold]"
        )

        results = []
        for domain in self.DOMAINS_TO_CHECK:
            for rtype in ["A", "AAAA"]:
                result = await self._query_dns(dns_server, domain, rtype)
                results.append(result)

        table = self.query_one("#dns-table", DataTable)
        table.clear()
        for r in results:
            table.add_row(r["domain"], r["type"], r["result"], r["time"])

        self.query_one("#dns-status", Static).update(f"{len(results)} queries completed")

    async def _query_dns(self, server: str, domain: str, rtype: str) -> dict:
        try:
            proc = await asyncio.create_subprocess_exec(
                "dig", f"@{server}", domain, rtype, "+short", "+time=2", "+tries=1",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
            stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=5.0)
            result = stdout.decode().strip() or "(no result)"
            return {"domain": domain, "type": rtype, "result": result, "time": "OK"}
        except asyncio.TimeoutError:
            return {"domain": domain, "type": rtype, "result": "(timeout)", "time": "TIMEOUT"}
        except Exception as e:
            return {"domain": domain, "type": rtype, "result": str(e), "time": "ERROR"}

    def action_refresh(self) -> None:
        self._load_data()
