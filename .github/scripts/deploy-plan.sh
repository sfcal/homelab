#!/usr/bin/env bash
# Works out what the deploy workflow should run, per environment (site).
#
# Push events: diff ansible/inventory/group_vars between the site's last
# successful deploy (tag deploy/<env>) and HEAD, and map changed files to
# playbooks: site_<env>/<group>/ and the folders of groups with hosts at the
# site count for it, site_<env>/apps.yml deploys the apps whose entry changed;
# other sites' folders are skipped. Without that tag yet, diff against the
# push's `before` commit.
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

# --- Auto-deploy allowlist: group -> playbook ---
# Keep in sync with the host pattern in ansible/playbooks/ci-access.yml.
# Anything else under group_vars (app_hermes, infra_ca, infra_networking,
# infra_ntp, infra_proxmox, proxy/, all/, site_<env>/ files outside a group
# sub-folder other than apps.yml) is reported but never auto-deployed.
declare -A PLAYBOOK_FOR=(
  [app_mediastack]=apps/media/deploy.yml
  [app_frigate]=apps/frigate/deploy.yml
  [app_gaming]=apps/gaming/deploy.yml
  [infra_monitoring]=infrastructure/monitoring/deploy.yml
  [infra_netboot]=infrastructure/netboot/deploy.yml
)

notice() { echo "::notice::$*" >&2; echo "- $*" >>"$GITHUB_STEP_SUMMARY"; }
fail() { echo "::error::$*" >&2; exit 1; }

INVENTORY=ansible/inventory/hosts.ini
GROUP_VARS=ansible/inventory/group_vars

# Hosts listed under [group] in the inventory.
group_hosts() {
  awk -v hdr="[$1]" '
    $0 == hdr { inside = 1; next }
    /^\[/     { inside = 0 }
    inside && NF && $1 !~ /^[#;]/ { print $1 }' "$INVENTORY" | sort -u
}

# True when [group] $2 has at least one host at site $1.
group_has_hosts() {
  [[ -n $(comm -12 <(group_hosts "site_$1") <(group_hosts "$2")) ]]
}

# Registry apps whose entry in the site's registry (site_<env>/apps.yml)
# differs between $2 and HEAD and that are hosted at site $1. Older bases have
# the registry elsewhere, and that copy is the base then: all/apps.yml (one
# for both sites) before it was split, ansible/environments/<env>/ before the
# single inventory.
changed_apps() {
  local env=$1 base=$2 f="$GROUP_VARS/site_$1/apps.yml" old new
  new=$(git show "$HEAD_SHA:$f" 2>/dev/null | yq -o=json '.apps // {}') || return 0
  old=$({ git show "$base:$f" 2>/dev/null ||
          git show "$base:$GROUP_VARS/all/apps.yml" 2>/dev/null ||
          git show "$base:ansible/environments/$env/group_vars/all/apps.yml" 2>/dev/null; } |
        yq -o=json '.apps // {}') || old='{}'
  jq -rn --argjson a "$old" --argjson b "$new" \
    '$b | keys[] as $k | select($a[$k] != $b[$k]) | [$k, ($b[$k].host_group // "")] | @tsv' |
  while IFS=$'\t' read -r app host_group; do
    if [[ -z $host_group || -z $(group_hosts "$host_group") ]]; then
      notice "$env: app '$app' changed but its host_group '$host_group' has no hosts; skipped"
    elif group_has_hosts "$env" "$host_group"; then
      echo "app $app"
    fi
  done
}

# Changed targets for site $1 since commit $2, one "kind target" per line.
# Files moved unchanged (R100) don't count, so the move from the per-env
# inventories (ansible/environments/) doesn't redeploy everything.
plan_from_diff() {
  local env=$1 base=$2 status f to rel group
  git diff --name-status -M "$base" "$HEAD_SHA" -- "$GROUP_VARS/" ansible/environments/ |
  while IFS=$'\t' read -r status f to; do
    case $status in
      R100) continue ;;
      R*) f=$to ;;
    esac
    [[ $f == "$GROUP_VARS"/* ]] || continue
    rel=${f#"$GROUP_VARS"/}
    group=${rel%%/*}
    case $rel in
      all/apps.yml | site_"$env"/apps.yml)            # all/: before the split
        changed_apps "$env" "$base"; continue ;;
      all/*) group= ;;
      site_"$env"/*/*) group=$(cut -d/ -f2 <<<"$rel") ;;
      site_"$env"/* | site_"$env".*) group= ;;
      site_*) continue ;;                               # another site's folder
      *) [[ -n $(group_hosts "$group") ]] && ! group_has_hosts "$env" "$group" &&
           continue ;;                                  # a group at another site
    esac
    if [[ -n $group && -n ${PLAYBOOK_FOR[$group]:-} ]]; then
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
