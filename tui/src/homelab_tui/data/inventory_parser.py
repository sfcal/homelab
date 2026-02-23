import re
from pathlib import Path


def parse_hosts_ini(ini_path: Path) -> dict[str, list[str]]:
    """Parse hosts.ini and return {group_name: [host_line1, host_line2, ...]}."""
    if not ini_path.exists():
        return {}
    groups: dict[str, list[str]] = {}
    current_group: str | None = None
    for line in ini_path.read_text().splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#") or stripped.startswith(";"):
            continue
        match = re.match(r"^\[(.+)\]$", stripped)
        if match:
            current_group = match.group(1)
            groups[current_group] = []
        elif current_group is not None:
            groups[current_group].append(stripped)
    return groups


def write_hosts_ini(ini_path: Path, groups: dict[str, list[str]]) -> None:
    """Write hosts.ini from groups dict."""
    lines: list[str] = []
    for group, hosts in groups.items():
        lines.append(f"[{group}]")
        for host in hosts:
            lines.append(host)
        lines.append("")
    ini_path.write_text("\n".join(lines))
