#!/bin/bash
trap 'pkill -P $$; wait; exit 143' TERM INT
set -euo pipefail

MANAGER_PATH="/opt/GitIssue-Manager"
LOG_FILE="/var/log/gitissuer/daemon-$(date +%Y%m%d).log"
STATE_FILE="/var/lib/gitissuer/.daemon-state.json"

log() {
  local level="$1"
  shift
  local msg="$*"
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$timestamp] [$level] $msg" | tee -a "$LOG_FILE"
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    log "ERROR" "Missing dependency: $cmd"
    exit 1
  fi
}

log "INFO" "============================================="
log "INFO" "GitIssuer daemon started"
log "INFO" "User: $(whoami)"
log "INFO" "PID: $$"
log "INFO" "============================================="

require_cmd jq
require_cmd gh

if ! gh auth status >/dev/null 2>&1; then
  log "ERROR" "GitHub CLI is not authenticated. Run: gh auth login"
  exit 1
fi

mkdir -p "$(dirname "$LOG_FILE")"
mkdir -p "$(dirname "$STATE_FILE")"

cat >"$STATE_FILE" <<EOF
{
  "start_time": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "status": "running",
  "repos_processed": 0,
  "repos_success": 0,
  "repos_failed": 0
}
EOF

config_glob="$MANAGER_PATH/sync-helper/configs"/*.json

shopt -s nullglob
configs=( $config_glob )
shopt -u nullglob

if [[ ${#configs[@]} -eq 0 ]]; then
  log "WARN" "No configs found under $MANAGER_PATH/sync-helper/configs"
  exit 0
fi

total_repos=${#configs[@]}
repos_processed=0
repos_success=0
repos_failed=0

log "INFO" "Found $total_repos configs to process"

for cfg in "${configs[@]}"; do
  repos_processed=$((repos_processed + 1))

  enabled=$(jq -r 'if .gitissuer.enabled == null then true else .gitissuer.enabled end' "$cfg" 2>/dev/null || echo true)
  if [[ "$enabled" != "true" ]]; then
    log "INFO" "[$repos_processed/$total_repos] Skipping (disabled): $(basename "$cfg")"
    continue
  fi

  repo_full=$(jq -r '.repo // empty' "$cfg" 2>/dev/null || true)
  auto_deploy=$(jq -r '.gitissuer.autoDeploy // true' "$cfg" 2>/dev/null || echo true)

  log "INFO" "---------------------------------------------"
  log "INFO" "[$repos_processed/$total_repos] Processing: ${repo_full:-$(basename "$cfg" .json)}"

  extra_args=()
  if [[ "$auto_deploy" == "true" ]]; then
    extra_args+=("--auto-deploy")
  fi

  if /bin/bash "$MANAGER_PATH/daemon/gitissuer-auto.sh" --config "$cfg" "${extra_args[@]}"; then
    repos_success=$((repos_success + 1))
  else
    repos_failed=$((repos_failed + 1))
  fi
done

log "INFO" "---------------------------------------------"
log "INFO" "GitIssuer daemon completed"
log "INFO" "Results: $repos_success/$total_repos successful"

cat >"$STATE_FILE" <<EOF
{
  "start_time": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "end_time": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "status": "completed",
  "repos_processed": $repos_processed,
  "repos_success": $repos_success,
  "repos_failed": $repos_failed
}
EOF

if [[ $repos_failed -gt 0 ]]; then
  exit 1
fi
