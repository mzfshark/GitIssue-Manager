#!/bin/bash
set -euo pipefail

MANAGER_PATH="/opt/GitIssue-Manager"
CONFIGS_DIR="$MANAGER_PATH/sync-helper/configs"
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

if ! command -v jq >/dev/null 2>&1; then
  log "ERROR" "Missing dependency: jq"
  exit 1
fi

if [[ ! -d "$CONFIGS_DIR" ]]; then
  log "ERROR" "Configs directory not found: $CONFIGS_DIR"
  exit 1
fi

config_repo_path() {
  local config_path="$1"
  local local_path
  local_path="$(jq -r '.localPath // empty' "$config_path" 2>/dev/null || true)"
  if [[ -z "$local_path" ]]; then
    echo ""
    return 1
  fi

  if [[ "$local_path" = /* ]]; then
    printf '%s' "$local_path"
    return 0
  fi

  printf '%s' "$MANAGER_PATH/$local_path"
}

config_enabled_flag() {
  local config_path="$1"
  jq -r 'if .gitissuer.enabled == null then true else .gitissuer.enabled end' "$config_path" 2>/dev/null || echo true
}

config_watch_flag() {
  local config_path="$1"
  jq -r 'if .gitissuer.watch.enabled == null then false else .gitissuer.watch.enabled end' "$config_path" 2>/dev/null || echo false
}

build_watch_paths() {
  local -a out=()
  out+=("$CONFIGS_DIR")

  local cfg
  shopt -s nullglob
  for cfg in "$CONFIGS_DIR"/*.json; do
    local enabled
    enabled="$(config_enabled_flag "$cfg")"
    if [[ "$enabled" != "true" ]]; then
      continue
    fi

    local watch
    watch="$(config_watch_flag "$cfg")"
    if [[ "$watch" != "true" ]]; then
      continue
    fi

    local repo_path
    repo_path="$(config_repo_path "$cfg" || true)"
    if [[ -z "$repo_path" ]]; then
      log "WARN" "Missing localPath in config, skipping: $cfg"
      continue
    fi

    if [[ ! -d "$repo_path" ]]; then
      log "WARN" "Repository path not found, skipping: $repo_path (from $cfg)"
      continue
    fi

    local issue_file="$repo_path/ISSUE_UPDATES.md"

    # Watch the file when it exists; otherwise watch the repo dir so create events are still noticed.
    if [[ -f "$issue_file" ]]; then
      out+=("$issue_file")
    else
      out+=("$repo_path")
    fi
  done

  printf '%s\n' "${out[@]}"
}

mapfile -t watch_paths < <(build_watch_paths)

if (( ${#watch_paths[@]} == 1 )); then
  log "WARN" "No watched repositories found (gitissuer.watch.enabled=true)."
  log "INFO" "Watching config changes only: $CONFIGS_DIR"
fi

log "INFO" "Starting watch (paths: ${#watch_paths[@]})"

inotifywait -m -e modify,create,move,delete --format '%w%f|%e' "${watch_paths[@]}" |
while IFS='|' read -r full_path event; do
  # If configs change, restart the service so it reloads the watch list.
  if [[ "$full_path" == "$CONFIGS_DIR"/* ]]; then
    log "INFO" "Detected config change ($event) at $full_path. Restarting watcher to reload targets."
    exit 0
  fi

  # Only react to ISSUE_UPDATES.md changes.
  if [[ "${full_path##*/}" != "ISSUE_UPDATES.md" ]]; then
    continue
  fi

  log "INFO" "Detected $event on $full_path. Triggering gitissuer.service"
  systemctl start gitissuer.service
done
