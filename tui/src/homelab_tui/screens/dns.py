"""DNS screen — resolve every service FQDN against the environment DNS server."""

from __future__ import annotations

import asyncio
from pathlib import Path

import yaml

from textual.app import ComposeResult
from textual.binding import Binding
from textual.screen import Screen
from textual.widgets import DataTable, Footer, Header, Static
from textual import work

from ..data.environment import get_env_ansible_dir, get_infra_host_ip


def _load_services(env_name: str) -> list[dict]:
    """Parse all proxy YAML files for an environment and return service dicts."""
    proxy_dir = get_env_ansible_dir(env_name) / "group_vars" / "all" / "proxy"
    if not proxy_dir.is_dir():
        return []

    services: list[dict] = []
    for yml_file in sorted(proxy_dir.glob("*.yml")):
        if yml_file.name.startswith("_"):
            continue
        try:
            data = yaml.safe_load(yml_file.read_text()) or {}
        except Exception:
            continue
        # Each file has one top-level key like wil_services, video_services, etc.
        # The domain is the filename without .yml
        domain = yml_file.stem
        for _key, svc_list in data.items():
            if not isinstance(svc_list, list):
                continue
            for svc in svc_list:
                if not isinstance(svc, dict):
                    continue
                if svc.get("enabled") is False:
                    continue
                svc["domain"] = domain
                services.append(svc)
    return services


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

    def compose(self) -> ComposeResult:
        yield Header()
        yield Static("DNS — Services", id="dns-title")
        yield DataTable(id="dns-table")
        yield Static("", id="dns-status")
        yield Footer()

    def on_mount(self) -> None:
        table = self.query_one("#dns-table", DataTable)
        table.add_columns("Service", "FQDN", "Expected", "Resolved", "Status")
        self._load_data()

    def on_screen_resume(self) -> None:
        self._load_data()

    def _load_data(self) -> None:
        self._run_dns_queries()

    @work(thread=False)
    async def _run_dns_queries(self) -> None:
        env = self.app.current_env
        dns_server = get_infra_host_ip(env, "infra_networking")
        if not dns_server:
            self.query_one("#dns-status", Static).update(
                "No DNS server found (infra_networking)"
            )
            return

        services = _load_services(env)
        if not services:
            self.query_one("#dns-status", Static).update("No services found")
            return

        self.query_one("#dns-title", Static).update(
            f"DNS — Services — server: {dns_server} — env: [bold]{env}[/bold]"
        )
        self.query_one("#dns-status", Static).update(
            f"Querying {len(services)} services…"
        )

        # Query all services concurrently
        tasks = []
        for svc in services:
            fqdn = f"{svc['name']}.{svc['domain']}"
            expected = svc.get("backend_host", "")
            tasks.append(self._query_service(dns_server, svc, fqdn, expected))

        results = sorted(await asyncio.gather(*tasks), key=lambda r: r["fqdn"][::-1])

        table = self.query_one("#dns-table", DataTable)
        table.clear()

        ok_count = 0
        for r in results:
            status = r["status"]
            if status == "OK":
                ok_count += 1
                status_display = "[green]OK[/green]"
            elif status == "MISMATCH":
                status_display = "[yellow]MISMATCH[/yellow]"
            else:
                status_display = f"[red]{status}[/red]"
            table.add_row(
                r["name"], r["fqdn"], r["expected"], r["resolved"], status_display
            )

        total = len(results)
        self.query_one("#dns-status", Static).update(
            f"{ok_count}/{total} services resolving correctly"
        )

    async def _query_service(
        self, dns_server: str, svc: dict, fqdn: str, expected: str
    ) -> dict:
        name = svc.get("name", "")
        try:
            proc = await asyncio.create_subprocess_exec(
                "dig", f"@{dns_server}", fqdn, "A", "+short", "+time=2", "+tries=1",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
            stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=5.0)
            resolved = stdout.decode().strip().splitlines()
            resolved_str = resolved[-1] if resolved else ""

            if not resolved_str:
                status = "NXDOMAIN"
            elif resolved_str == expected:
                status = "OK"
            else:
                # For proxied services the DNS points to the reverse proxy, not the backend
                status = "OK" if svc.get("proxied") else "MISMATCH"

            return {
                "name": name,
                "fqdn": fqdn,
                "expected": expected if not svc.get("proxied") else "(proxied)",
                "resolved": resolved_str or "(no result)",
                "status": status,
            }
        except asyncio.TimeoutError:
            return {
                "name": name,
                "fqdn": fqdn,
                "expected": expected,
                "resolved": "(timeout)",
                "status": "TIMEOUT",
            }
        except Exception as e:
            return {
                "name": name,
                "fqdn": fqdn,
                "expected": expected,
                "resolved": str(e),
                "status": "ERROR",
            }

    def action_refresh(self) -> None:
        self._load_data()
