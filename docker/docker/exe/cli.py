#!/usr/bin/env python3

import subprocess
from rich.console import Console
from rich.table import Table
from rich.prompt import Prompt
from rich import box

console = Console()

# Define your deployment steps
steps = [
    ("prepare", "Prepare environment", "prepare"),
    ("network", "Setup networking", "setup:network"),
    ("storage", "Configure storage", "setup:storage"),
    ("containers", "Deploy containers", "deploy:containers"),
    ("services", "Start services", "deploy:services"),
    ("monitoring", "Setup monitoring", "deploy:monitoring"),
    ("verify", "Verify deployment", "verify:all")
]

# Show available steps
table = Table(title="Deployment Steps", box=box.ROUNDED)
table.add_column("Index", style="cyan")
table.add_column("Step", style="magenta")
table.add_column("Description", style="green")

for i, (name, desc, _) in enumerate(steps):
    table.add_row(str(i), name, desc)

console.print(table)
console.print()

# Get start and end
start = int(Prompt.ask("Start at step", default="0"))
end = int(Prompt.ask("End at step", default=str(len(steps)-1)))

# Show what will be run
console.print(f"\n[bold]Will run steps {start} to {end}:[/bold]")
for i in range(start, end + 1):
    console.print(f"  • {steps[i][0]}: {steps[i][1]}")

if Prompt.ask("\nProceed?", choices=["y", "n"]) != "y":
    console.print("[yellow]Cancelled[/yellow]")
    exit()

# Execute steps
for i in range(start, end + 1):
    name, desc, task = steps[i]
    console.print(f"\n[bold cyan]Running: {name}[/bold cyan]")
    
    try:
        subprocess.run(["task", task], check=True)
        console.print(f"[green]✓ Completed: {name}[/green]")
    except subprocess.CalledProcessError:
        console.print(f"[red]✗ Failed: {name}[/red]")
        if Prompt.ask("Continue?", choices=["y", "n"]) != "y":
            break

console.print("\n[bold green]Done![/bold green]")