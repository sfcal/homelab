"""Dynamic discovery of environments, tasks, and packer templates."""

from __future__ import annotations

import asyncio
import json
from pathlib import Path

from ..config import ANSIBLE_DIR, PACKER_DIR, PROJECT_ROOT
from .models import PackerTemplate, TaskInfo


def discover_environments() -> list[str]:
    """Scan ansible/environments/ for available environments."""
    env_dir = ANSIBLE_DIR / "environments"
    if not env_dir.exists():
        return []
    return sorted(
        d.name for d in env_dir.iterdir()
        if d.is_dir() and not d.name.startswith(".")
    )


async def discover_tasks() -> list[TaskInfo]:
    """Run `task --list-all --json` and parse available tasks."""
    try:
        proc = await asyncio.create_subprocess_exec(
            "task", "--list-all", "--json",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
            cwd=str(PROJECT_ROOT),
        )
        stdout, _ = await proc.communicate()
        if proc.returncode != 0:
            return []
        data = json.loads(stdout.decode())
        tasks: list[TaskInfo] = []
        for t in data.get("tasks", []):
            name = t.get("name", "")
            desc = t.get("desc", "")
            if ":" in name:
                namespace, short_name = name.split(":", 1)
            else:
                namespace = ""
                short_name = name
            tasks.append(TaskInfo(
                name=name,
                description=desc,
                namespace=namespace,
                short_name=short_name,
            ))
        return tasks
    except Exception:
        return []


def discover_packer_templates() -> list[PackerTemplate]:
    """Scan packer/templates/ for available .pkr.hcl files."""
    templates_dir = PACKER_DIR / "templates"
    if not templates_dir.exists():
        return []
    templates: list[PackerTemplate] = []
    for f in sorted(templates_dir.glob("*.pkr.hcl")):
        name = f.stem.replace(".pkr", "")
        templates.append(PackerTemplate(
            name=name,
            filename=f.name,
            path=str(f),
        ))
    return templates
