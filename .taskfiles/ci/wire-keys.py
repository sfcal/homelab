#!/usr/bin/env python3
"""Wire an environment's CI keys into the repo (called by `task ci:keys`).

- ansible/inventory/group_vars/site_<env>/ci.yml: ci_deploy_ssh_pubkey
- .sops.yaml: append the CI age recipient to the rule tagged `# ci:<env>`
Idempotent: re-running with the same keys changes nothing.
"""
import pathlib
import re
import sys

env, ci_dir = sys.argv[1], pathlib.Path(sys.argv[2])
root = pathlib.Path(__file__).resolve().parents[2]

ssh_pub = (ci_dir / "id_ed25519.pub").read_text().strip()
age_pub = next(
    line.split(":", 1)[1].strip()
    for line in (ci_dir / "age.txt").read_text().splitlines()
    if line.startswith("# public key:")
)

ci_yml = root / f"ansible/inventory/group_vars/site_{env}/ci.yml"
text, n = re.subn(
    r"^ci_deploy_ssh_pubkey:.*$",
    f'ci_deploy_ssh_pubkey: "{ssh_pub}"',
    ci_yml.read_text(),
    count=1,
    flags=re.M,
)
if n != 1:
    sys.exit(f"{ci_yml}: no ci_deploy_ssh_pubkey line")
ci_yml.write_text(text)

sops_yaml = root / ".sops.yaml"
marker = f"# ci:{env}"
lines = sops_yaml.read_text().splitlines(keepends=True)
for i, line in enumerate(lines):
    m = re.match(r"^(\s*age:\s*)(\S+)\s*" + re.escape(marker) + r"\s*$", line)
    if m:
        recipients = m.group(2).split(",")
        if age_pub not in recipients:
            recipients.append(age_pub)
        lines[i] = f"{m.group(1)}{','.join(recipients)}  {marker}\n"
        break
else:
    sys.exit(f".sops.yaml: no `age: ...  {marker}` line")
sops_yaml.write_text("".join(lines))

print(f"{env}: ssh {ssh_pub.split()[0]} …{ssh_pub.split()[1][-12:]}, age {age_pub}")
