#!/bin/bash
set -euo pipefail

MANAGER_PATH="/opt/GitIssue-Manager"
LOG_FILE="${LOG_FILE:-/var/log/gitissuer/daemon-$(date +%Y%m%d).log}"

repo_path="$1"
repo_owner="$2"
repo_name="$3"
auto_deploy="$4"

log() {
  local level="$1"
  shift
  local msg="$*"
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$timestamp] [$level] $msg" | tee -a "$LOG_FILE"
}

run_cmd() {
  local label="$1"
  shift
  log "INFO" "$label"
  if "$@" >>"$LOG_FILE" 2>&1; then
    log "INFO" "SUCCESS: $label"
    return 0
  fi
  log "ERROR" "FAILED: $label"
  return 1
}

if [[ ! -d "$repo_path" ]]; then
  log "ERROR" "Repository path not found: $repo_path"
  exit 1
fi

if [[ ! -d "$repo_path/.git" ]]; then
  log "ERROR" "Not a git repository: $repo_path"
  exit 1
fi

cd "$repo_path"

mkdir -p ".gitissuer"
repo_state_file=".gitissuer/state.json"

cat >"$repo_state_file" <<EOF
{
  "last_run": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "status": "processing",
  "steps": ["add", "prepare", "deploy", "e2e"],
  "repo": "${repo_owner}/${repo_name}"
}
EOF

if [[ ! -f "ISSUE_UPDATES.md" ]]; then
  log "WARN" "ISSUE_UPDATES.md not found in $repo_path"
  cat >"$repo_state_file" <<EOF
{
  "last_run": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "status": "skipped",
  "reason": "ISSUE_UPDATES.md not found",
  "repo": "${repo_owner}/${repo_name}"
}
EOF
  exit 0
fi

run_cmd "Step 1/4: ADD - Load updates" \
  /bin/bash "$MANAGER_PATH/scripts/gitissuer.sh" add --file ISSUE_UPDATES.md

run_cmd "Step 2/4: PREPARE - Validate changes (dry-run)" \
  /bin/bash "$MANAGER_PATH/scripts/gitissuer.sh" prepare --repo "${repo_owner}/${repo_name}" --dry-run || true

if [[ "$auto_deploy" == "true" ]]; then
  run_cmd "Step 3/4: DEPLOY - Apply changes" \
    /bin/bash "$MANAGER_PATH/scripts/gitissuer.sh" deploy --repo "${repo_owner}/${repo_name}" --batch --confirm

  run_cmd "Step 4/4: E2E - Run validation" \
    /bin/bash "$MANAGER_PATH/scripts/gitissuer.sh" e2e:run --repo "${repo_owner}/${repo_name}" || true
else
  log "INFO" "AUTO_DEPLOY disabled for ${repo_owner}/${repo_name}. Skipping deploy and e2e."
fi

cat >"$repo_state_file" <<EOF
{
  "last_run": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "status": "success",
  "steps": ["add", "prepare", "deploy", "e2e"],
  "auto_deploy": $auto_deploy,
  "repo": "${repo_owner}/${repo_name}"
}
EOF
