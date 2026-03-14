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
    """Write hosts.ini from groups dict, preserving structure."""
    lines: list[str] = []
    # Separate into categories for clean output
    infra_groups = {k: v for k, v in groups.items() if k.startswith("infra_")}
    app_groups = {k: v for k, v in groups.items() if k.startswith("app_")}
    parent_groups = {k: v for k, v in groups.items() if ":children" in k}
    other_groups = {
        k: v for k, v in groups.items()
        if k not in infra_groups and k not in app_groups and k not in parent_groups
    }

    def write_section(section_groups: dict[str, list[str]], header: str = "") -> None:
        if not section_groups:
            return
        if header:
            lines.append(f"# --- {header} ---")
            lines.append("")
        for group, hosts in section_groups.items():
            lines.append(f"[{group}]")
            for host in hosts:
                lines.append(host)
            lines.append("")

    write_section(infra_groups, "Infrastructure")
    write_section(app_groups, "Apps")
    write_section(other_groups)
    write_section(parent_groups, "Parent groups")

    ini_path.write_text("\n".join(lines))
