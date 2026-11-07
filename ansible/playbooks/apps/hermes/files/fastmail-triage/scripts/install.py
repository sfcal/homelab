#!/usr/bin/env python3
"""Install the fastmail-triage skill into Hermes and create its two weekly cron jobs. Run it on the Hermes machine.

  python3 install.py --deliver telegram --timezone Europe/London

Needs Hermes v0.22.6 or newer. Safe to re-run: it updates the skill files and repairs the jobs, and it only changes a
schedule, time zone or delivery target if you pass one. It never touches your config, your token or your mail.
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

SKILL = "fastmail-triage"
DECIDE = "fastmail-triage-decide"
APPLY = "fastmail-triage-apply"
PAUSE_REASON = "fastmail-triage install"
DEFAULT_TIMEZONE, DEFAULT_DECIDE, DEFAULT_APPLY = "Europe/London", "0 8 * * 1", "30 8 * * 1"
PROMPT = ("Run the Scheduled step of the fastmail-triage skill on the digest in the Script Output above. "
          "Reply with the JSON block only.")
LAUNCHER = '''#!/usr/bin/env python3
# Written by fastmail-triage's install.py. Hermes only runs cron scripts from this folder.
import os
import runpy
import sys
from pathlib import Path

home = Path(__file__).resolve().parent.parent
os.environ["HERMES_HOME"] = str(home)
os.environ["FASTMAIL_TRIAGE_JOB"] = "1"
target = home / "skills" / "email" / "fastmail-triage" / "scripts" / "fastmail_triage.py"
sys.argv = [str(target), "%s", "--cron"]
runpy.run_path(str(target), run_name="__main__")
'''


def fail(message: str) -> None:
    print(f"install: {message}", file=sys.stderr)
    sys.exit(1)


def load_jobs(home: Path) -> dict:
    path = home / "cron" / "jobs.json"
    if not path.exists():
        return {"jobs": []}
    return json.loads(path.read_text(encoding="utf-8"))


def find_job(home: Path, name: str) -> dict | None:
    return next((j for j in load_jobs(home).get("jobs", []) if j.get("name") == name), None)


def resolve_home(explicit: str | None) -> Path:
    """Follow Hermes's sticky profile, so the installer and the hermes command use the same store."""
    if explicit:
        return Path(explicit).expanduser()
    if os.environ.get("HERMES_HOME"):
        return Path(os.environ["HERMES_HOME"]).expanduser()
    root = Path.home() / ".hermes"
    active = root / "active_profile"
    name = active.read_text(encoding="utf-8").strip() if active.exists() else ""
    return root / "profiles" / name if name and name != "default" else root


def run_hermes(hermes: str, home: Path, *args: str) -> subprocess.CompletedProcess:
    result = subprocess.run([hermes, *args], capture_output=True, text=True, env={**os.environ, "HERMES_HOME": str(home)})
    if result.returncode != 0:  # argparse prints the reason last, so keep the end of the message
        fail(f"'hermes {' '.join(args[:3])} ...' failed: {(result.stderr or result.stdout).strip()[-500:]}")
    return result


def set_no_tools(home: Path, name: str) -> None:
    """The CLI has no toolset flag, so set the field in jobs.json. An empty list means the job gets no tools."""
    path = home / "cron" / "jobs.json"
    if not path.exists():
        fail(f"{path} does not exist, so the hermes command is using a different home. Pass --hermes-home.")
    lock = open(home / "cron" / ".jobs.lock", "a")  # the same lock Hermes takes while it writes this file
    try:
        try:
            import fcntl
            fcntl.flock(lock, fcntl.LOCK_EX)
        except ImportError:
            pass
        data = json.loads(path.read_text(encoding="utf-8"))
        job = next((j for j in data.get("jobs", []) if j.get("name") == name), None)
        if job is None:
            fail(f"could not find the job {name} in {path}")
        if job.get("enabled_toolsets") != []:
            job["enabled_toolsets"] = []
            tmp = path.with_name(path.name + ".fastmail-triage.tmp")
            tmp.write_text(json.dumps(data, indent=2), encoding="utf-8")
            shutil.copymode(path, tmp)
            os.replace(tmp, path)
    finally:
        lock.close()
    check = find_job(home, name)
    if not check or check.get("enabled_toolsets") != []:
        fail(f"could not set enabled_toolsets on {name}; it was left paused")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--deliver", help="where the weekly report goes, e.g. telegram, discord, or telegram:123456 (required the first time)")
    parser.add_argument("--timezone", help=f"default {DEFAULT_TIMEZONE} on first install")
    parser.add_argument("--decide-schedule", help=f"when the model classifies (default '{DEFAULT_DECIDE}', Mondays 08:00)")
    parser.add_argument("--apply-schedule", help=f"when mail moves and the report goes out, within 6 hours after (default '{DEFAULT_APPLY}')")
    parser.add_argument("--hermes-home", help="default: $HERMES_HOME, or ~/.hermes and its active profile")
    parser.add_argument("--no-cron", action="store_true", help="install the files only")
    args = parser.parse_args()
    home = resolve_home(args.hermes_home)
    if not home.is_dir():
        fail(f"{home} does not exist. Run this on the machine where Hermes is installed, or pass --hermes-home.")

    source = Path(__file__).resolve().parent.parent
    dest = home / "skills" / "email" / SKILL
    if source != dest.resolve():
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copytree(source, dest, dirs_exist_ok=True, ignore=shutil.ignore_patterns("__pycache__", "*.pyc"))
    print(f"Skill files: {dest}")

    scripts = home / "scripts"
    scripts.mkdir(parents=True, exist_ok=True)
    for name, command in (("fastmail_triage_scan.py", "scan"), ("fastmail_triage_apply.py", "apply")):
        launcher = scripts / name
        launcher.write_text(LAUNCHER % command, encoding="utf-8")
        launcher.chmod(0o700)
    print(f"Launchers: {scripts}")

    tool = dest / "scripts" / "fastmail_triage.py"
    env = {**os.environ, "HERMES_HOME": str(home)}
    print(subprocess.run([sys.executable, str(tool), "mode"], env=env, capture_output=True, text=True).stdout.strip())

    if not args.no_cron:
        hermes = shutil.which("hermes") or shutil.which("hermes", path=str(Path.home() / ".local" / "bin"))
        if not hermes:
            fail("the hermes command is not on PATH")
        if "--timezone" not in run_hermes(hermes, home, "cron", "create", "--help").stdout:
            fail("this needs Hermes v0.22.6 or newer. Run: hermes update")
        if not find_job(home, APPLY) and not args.deliver:
            fail("--deliver is required the first time, e.g. --deliver telegram")

        def changes(schedule):  # a re-run only changes what you pass, so your own edits survive
            flags = ["--schedule", schedule] if schedule else []
            return flags + (["--timezone", args.timezone] if args.timezone else [])

        if find_job(home, DECIDE):
            set_no_tools(home, DECIDE)
            if changes(args.decide_schedule):
                run_hermes(hermes, home, "cron", "edit", find_job(home, DECIDE)["id"], *changes(args.decide_schedule))
        else:
            run_hermes(hermes, home, "cron", "create", args.decide_schedule or DEFAULT_DECIDE, PROMPT, "--name", DECIDE, "--skill", SKILL,
                       "--script", "fastmail_triage_scan.py", "--deliver", "local", "--timezone", args.timezone or DEFAULT_TIMEZONE,
                       "--paused", "--paused-reason", PAUSE_REASON)
        set_no_tools(home, DECIDE)
        job = find_job(home, DECIDE)
        if str(job.get("paused_reason") or "").startswith(PAUSE_REASON):  # never resume a job you paused yourself
            run_hermes(hermes, home, "cron", "resume", job["id"])
        print(f"Job {DECIDE} is set: model with no tools, output kept locally")
        if find_job(home, APPLY):
            extra = changes(args.apply_schedule) + (["--deliver", args.deliver] if args.deliver else [])
            if extra:
                run_hermes(hermes, home, "cron", "edit", find_job(home, APPLY)["id"], *extra)
        else:
            run_hermes(hermes, home, "cron", "create", args.apply_schedule or DEFAULT_APPLY, "--no-agent", "--script", "fastmail_triage_apply.py",
                       "--deliver", args.deliver, "--name", APPLY, "--timezone", args.timezone or DEFAULT_TIMEZONE)
        print(f"Job {APPLY} is set: script only, report goes to {(find_job(home, APPLY) or {}).get('deliver') or args.deliver}")
        for name in (DECIDE, APPLY):
            job = find_job(home, name) or {}
            if job.get("state") == "paused" or job.get("enabled") is False:
                print(f"Note: {name} is paused. Resume it with: hermes cron resume {name}")
        # Hermes can rewrite skills it maintains. These guardrails should only change when you change them.
        locked = subprocess.run([hermes, "curator", "lock", SKILL], capture_output=True, env={**os.environ, "HERMES_HOME": str(home)})
        print("Skill locked against automatic edits." if locked.returncode == 0 else "Note: could not lock the skill; check `hermes curator --help`.")

    env_file = home / ".env"
    if env_file.exists() and "FASTMAIL_API_TOKEN=" in env_file.read_text(errors="replace"):
        print(f"Warning: remove FASTMAIL_API_TOKEN from {env_file}, where every Hermes terminal can read it, and use set-token instead.")
    token_set = (home / "data" / "fastmail-triage" / "token").exists()
    print("\nNext:")
    if not token_set:
        print("  - Create a Fastmail token (Settings > Privacy & Security > Manage API tokens, type JMAP, tick Email only), then:")
        print(f"      HERMES_HOME={home} python3 {tool} set-token")
    print(f"  - Check everything:  HERMES_HOME={home} python3 {tool} check")
    print(f"  - Try it now:        hermes cron run {DECIDE}   and when that returns   hermes cron run {APPLY}")
    print("  - Cron jobs need the Hermes gateway running: hermes gateway install")
    print(f"  - When the report looks right:  HERMES_HOME={home} python3 {tool} mode apply")
    return 0


if __name__ == "__main__":
    sys.exit(main())
