from __future__ import annotations

import asyncio
import shlex
from collections.abc import Callable
from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from pathlib import Path


class TaskStatus(Enum):
    RUNNING = "running"
    COMPLETED = "completed"
    FAILED = "failed"
    CANCELLED = "cancelled"


@dataclass
class TaskExecution:
    id: str
    description: str
    command: list[str]
    status: TaskStatus = TaskStatus.RUNNING
    output_lines: list[str] = field(default_factory=list)
    return_code: int | None = None
    started_at: datetime | None = None
    finished_at: datetime | None = None
    _process: asyncio.subprocess.Process | None = field(default=None, repr=False)


class TaskRunner:
    """Manages async subprocess execution with streaming output."""

    def __init__(self, working_dir: Path):
        self.working_dir = working_dir
        self.tasks: dict[str, TaskExecution] = {}
        self._counter = 0

    def _next_id(self) -> str:
        self._counter += 1
        return f"task-{self._counter}"

    async def run(
        self,
        command: list[str],
        description: str,
        on_output: Callable | None = None,
        on_complete: Callable | None = None,
    ) -> TaskExecution:
        task_id = self._next_id()
        task = TaskExecution(
            id=task_id,
            description=description,
            command=command,
            started_at=datetime.now(),
        )
        self.tasks[task_id] = task

        try:
            shell_cmd = shlex.join(command)
            process = await asyncio.create_subprocess_shell(
                shell_cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.STDOUT,
                cwd=str(self.working_dir),
            )
            task._process = process

            async for line in process.stdout:
                decoded = line.decode("utf-8", errors="replace").rstrip("\n")
                task.output_lines.append(decoded)
                if on_output:
                    on_output(task_id, decoded)

            await process.wait()
            task.return_code = process.returncode
            task.status = TaskStatus.COMPLETED if process.returncode == 0 else TaskStatus.FAILED
        except asyncio.CancelledError:
            task.status = TaskStatus.CANCELLED
            if task._process:
                task._process.terminate()
        except Exception as e:
            task.status = TaskStatus.FAILED
            task.output_lines.append(f"Error: {e}")
        finally:
            task.finished_at = datetime.now()
            if on_complete:
                on_complete(task)

        return task

    async def cancel(self, task_id: str) -> None:
        task = self.tasks.get(task_id)
        if task and task._process and task.status == TaskStatus.RUNNING:
            task._process.terminate()
            task.status = TaskStatus.CANCELLED
