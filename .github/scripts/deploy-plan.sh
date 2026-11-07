#!/usr/bin/env bash
# Works out what the deploy workflow should run, per environment.
#
# Push events: diff group_vars between the environment's last successful
# deploy (tag deploy/<env>) and HEAD, and map changed files to playbooks.
# Without that tag yet, diff against the push's `before` commit.
# workflow_dispatch: an explicit target, or (target empty) the same diff.
#
# Writes `<env>=<json>` lines to $GITHUB_OUTPUT, where <json> is a list of
# {"kind": "app"|"playbook", "target": ...} for the deploy matrix, plus
# `mark=true|false` (move deploy/<env> after a successful deploy).
#
# Env: EVENT, HEAD_SHA, BEFORE, DEPLOY_ENVS, INPUT_ENV, INPUT_TARGET,
#      GITHUB_OUTPUT, GITHUB_STEP_SUMMARY (both optional when run by hand).
set -euo pipefail

ALL_ENVS=(wil ldn)
GITHUB_OUTPUT=${GITHUB_OUTPUT:-/dev/stdout}
GITHUB_STEP_SUMMARY=${GITHUB_STEP_SUMMARY:-/dev/null}
HEAD_SHA=${HEAD_SHA:-$(git rev-parse HEAD)}

# --- Auto-deploy allowlist: group_vars directory -> playbook ---
# Keep in sync with the host pattern in ansible/playbooks/ci-access.yml.
# Anything else under group_vars (app_hermes, infra_ca, infra_networking,
# infra_ntp, infra_proxmox, all/ except apps.yml) is reported but never
# auto-deployed.
declare -A PLAYBOOK_FOR=(
  [app_mediastack]=apps/media/deploy.yml
  [app_frigate]=apps/frigate/deploy.yml
  [app_gaming]=apps/gaming/deploy.yml
  [infra_monitoring]=infrastructure/monitoring/deploy.yml
  [infra_netboot]=infrastructure/netboot/deploy.yml
)

notice() { echo "::notice::$*" >&2; echo "- $*" >>"$GITHUB_STEP_SUMMARY"; }
fail() { echo "::error::$*" >&2; exit 1; }

# True when [group] in the env's inventory lists at least one host.
group_has_hosts() {
  awk -v hdr="[$2]" '
    $0 == hdr { inside = 1; next }
    /^\[/     { inside = 0 }
    inside && NF && $1 !~ /^[#;]/ { found = 1 }
    END { exit !found }' "ansible/environments/$1/hosts.ini"
}

# Registry apps whose apps.yml entry differs between $2 and HEAD (env $1).
changed_apps() {
  local env=$1 base=$2 f="ansible/environments/$1/group_vars/all/apps.yml" old new
  new=$(git show "$HEAD_SHA:$f" 2>/dev/null | yq -o=json '.apps // {}') || return 0
  old=$(git show "$base:$f" 2>/dev/null | yq -o=json '.apps // {}') || old='{}'
  jq -rn --argjson a "$old" --argjson b "$new" \
    '$b | keys[] as $k | select($a[$k] != $b[$k]) | [$k, ($b[$k].host_group // "")] | @tsv' |
  while IFS=$'\t' read -r app host_group; do
    if [[ -n $host_group ]] && group_has_hosts "$env" "$host_group"; then
      echo "app $app"
    else
      notice "$env: app '$app' changed but $host_group has no hosts here; skipped"
    fi
  done
}

# Changed targets for env $1 since commit $2, one "kind target" per line.
plan_from_diff() {
  local env=$1 base=$2 f group
  git diff --name-only "$base" "$HEAD_SHA" -- "ansible/environments/$env/group_vars/" |
  while read -r f; do
    group=$(cut -d/ -f5 <<<"$f")
    if [[ $f == */group_vars/all/apps.yml ]]; then
      changed_apps "$env" "$base"
    elif [[ -n ${PLAYBOOK_FOR[$group]:-} ]]; then
      if group_has_hosts "$env" "$group"; then
        echo "playbook ${PLAYBOOK_FOR[$group]}"
      else
        notice "$env: $f changed but [$group] has no hosts here; skipped"
      fi
    else
      notice "$env: $f changed; not auto-deployed (deploy manually)"
    fi
  done
}

# Commit to diff from for env $1.
base_for() {
  local tag="refs/tags/deploy/$1"
  if git rev-parse -q --verify "$tag^{commit}" >/dev/null; then
    git rev-parse "$tag^{commit}"
  elif [[ -n ${BEFORE:-} && ! ${BEFORE} =~ ^0+$ ]] && git cat-file -e "$BEFORE^{commit}" 2>/dev/null; then
    git rev-parse "$BEFORE^{commit}"
  else
    git rev-parse "$HEAD_SHA~1"
  fi
}

to_json() { sort -u | jq -Rnc '[inputs | select(length > 0) | split(" ") | {kind: .[0], target: .[1]}]'; }

declare -A PLAN
for env in "${ALL_ENVS[@]}"; do PLAN[$env]='[]'; done
mark=false

echo "### Deploy plan (${HEAD_SHA:0:7})" >>"$GITHUB_STEP_SUMMARY"

if [[ ${EVENT:-push} == workflow_dispatch ]]; then
  env=${INPUT_ENV:-}
  [[ " ${ALL_ENVS[*]} " == *" $env "* ]] || fail "unknown environment '$env'"
  target=${INPUT_TARGET:-}
  if [[ -z $target ]]; then
    git rev-parse -q --verify "refs/tags/deploy/$env" >/dev/null ||
      fail "no deploy/$env tag yet: pass a target (app:<name> or playbook:<path>)"
    base=$(base_for "$env")
    echo "- $env: changes since ${base:0:7}" >>"$GITHUB_STEP_SUMMARY"
    PLAN[$env]=$(plan_from_diff "$env" "$base" | to_json)
    mark=true
  elif [[ $target =~ ^app:([a-z0-9_]+)$ ]]; then
    PLAN[$env]=$(echo "app ${BASH_REMATCH[1]}" | to_json)
  elif [[ $target =~ ^playbook:([a-z0-9_/-]+\.yml)$ ]]; then
    [[ -f ansible/playbooks/${BASH_REMATCH[1]} ]] || fail "no such playbook: ansible/playbooks/${BASH_REMATCH[1]}"
    PLAN[$env]=$(echo "playbook ${BASH_REMATCH[1]}" | to_json)
  else
    fail "target must be app:<name> or playbook:<path under ansible/playbooks>, got '$target'"
  fi
else
  read -ra enabled <<<"${DEPLOY_ENVS:-wil}"
  for env in "${enabled[@]}"; do
    [[ " ${ALL_ENVS[*]} " == *" $env "* ]] || fail "DEPLOY_ENVS lists unknown environment '$env'"
    base=$(base_for "$env")
    echo "- $env: changes since ${base:0:7}" >>"$GITHUB_STEP_SUMMARY"
    PLAN[$env]=$(plan_from_diff "$env" "$base" | to_json)
  done
  for env in "${ALL_ENVS[@]}"; do
    [[ " ${enabled[*]} " == *" $env "* ]] ||
      echo "- $env: auto-deploy off (not in DEPLOY_ENVS)" >>"$GITHUB_STEP_SUMMARY"
  done
  mark=true
fi

for env in "${ALL_ENVS[@]}"; do
  echo "- $env targets: \`${PLAN[$env]}\`" >>"$GITHUB_STEP_SUMMARY"
  echo "$env=${PLAN[$env]}" >>"$GITHUB_OUTPUT"
done
echo "mark=$mark" >>"$GITHUB_OUTPUT"
