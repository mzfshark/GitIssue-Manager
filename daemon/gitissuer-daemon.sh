#!/bin/bash
set -euo pipefail

MANAGER_PATH="/opt/GitIssue-Manager"
CONFIG_FILE="$MANAGER_PATH/config/repos.config.json"
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

if [[ ! -f "$CONFIG_FILE" ]]; then
  log "ERROR" "Configuration file not found: $CONFIG_FILE"
  exit 1
fi

repos=$(jq -r '.repositories[] | select(.enabled==true) | .path' "$CONFIG_FILE")

if [[ -z "$repos" ]]; then
  log "WARN" "No enabled repositories found"
  exit 0
fi

total_repos=$(echo "$repos" | wc -l | tr -d ' ')
repos_processed=0
repos_success=0
repos_failed=0

log "INFO" "Found $total_repos repositories to process"

while IFS= read -r repo_path; do
  repos_processed=$((repos_processed + 1))

  repo_owner=$(jq -r --arg path "$repo_path" '.repositories[] | select(.path==$path) | .owner' "$CONFIG_FILE")
  repo_name=$(jq -r --arg path "$repo_path" '.repositories[] | select(.path==$path) | .repo' "$CONFIG_FILE")
  auto_deploy=$(jq -r --arg path "$repo_path" '.repositories[] | select(.path==$path) | .auto_deploy' "$CONFIG_FILE")

  if [[ -z "$repo_owner" || -z "$repo_name" || "$repo_owner" == "null" || "$repo_name" == "null" ]]; then
    log "ERROR" "Invalid repo configuration for path: $repo_path"
    repos_failed=$((repos_failed + 1))
    continue
  fi

  log "INFO" "---------------------------------------------"
  log "INFO" "[$repos_processed/$total_repos] Processing: $repo_owner/$repo_name"

  if /bin/bash "$MANAGER_PATH/daemon/gitissuer-auto.sh" "$repo_path" "$repo_owner" "$repo_name" "$auto_deploy"; then
    repos_success=$((repos_success + 1))
  else
    repos_failed=$((repos_failed + 1))
  fi

done <<< "$repos"

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
