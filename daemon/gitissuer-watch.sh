#!/bin/bash
set -euo pipefail

MANAGER_PATH="/opt/GitIssue-Manager"
CONFIG_FILE="$MANAGER_PATH/config/repos.config.json"
LOG_FILE="/var/log/gitissuer/watch-$(date +%Y%m%d).log"

log() {
  local level="$1"
  shift
  local msg="$*"
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$timestamp] [$level] $msg" | tee -a "$LOG_FILE"
}

if ! command -v inotifywait >/dev/null 2>&1; then
  log "ERROR" "Missing dependency: inotifywait (install inotify-tools)"
  exit 1
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
  log "ERROR" "Configuration file not found: $CONFIG_FILE"
  exit 1
fi

repos=$(jq -r '.repositories[] | select(.enabled==true) | .path' "$CONFIG_FILE")

if [[ -z "$repos" ]]; then
  log "WARN" "No enabled repositories found"
  exit 0
fi

log "INFO" "Starting file watch for ISSUE_UPDATES.md"

for repo_path in $repos; do
  if [[ ! -d "$repo_path" ]]; then
    log "WARN" "Repository path not found, skipping: $repo_path"
    continue
  fi

  issue_file="$repo_path/ISSUE_UPDATES.md"
  log "INFO" "Watching: $issue_file"

  inotifywait -m -e modify,create "$issue_file" --format '%w %e' |
  while read -r path event; do
    log "INFO" "Detected $event on $path. Triggering gitissuer.service"
    systemctl start gitissuer.service
  done &

done

wait
