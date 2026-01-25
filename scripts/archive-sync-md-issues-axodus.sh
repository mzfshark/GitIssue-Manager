#!/usr/bin/env bash
set -euo pipefail

# Archive managed issues in Axodus repos by removing the `sync-md` label.
# This enables a true "recreate from scratch" run, since the executor indexes by `labels=sync-md` with `state=all`.
#
# Dry-run by default. Use --confirm to actually remove labels.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

LOCKFILE="$ROOT/tmp/archive-sync-md-issues-axodus.lock"

COOLDOWN_SECONDS="${COOLDOWN_SECONDS:-1}"
GH_TIMEOUT_SECONDS="${GH_TIMEOUT_SECONDS:-30}"
PER_PAGE="${PER_PAGE:-100}"

REPOS=(
  "Axodus/AragonOSX"
  "Axodus/aragon-app"
  "Axodus/Aragon-app-backend"
)

confirm="false"

usage() {
  cat <<'EOF'
Usage: archive-sync-md-issues-axodus.sh [--confirm]

Environment:
  COOLDOWN_SECONDS=1   Sleep between label removals (seconds)
  GH_TIMEOUT_SECONDS=30 Timeout for each GitHub API call (seconds)
  PER_PAGE=100         Page size for GitHub REST listing

Notes:
  - Dry-run is default.
  - This does NOT delete issues; it only removes the `sync-md` label.
EOF
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: Missing dependency: $cmd" >&2
    exit 1
  fi
}

run_gh_api() {
  local args=("$@")
  if command -v timeout >/dev/null 2>&1; then
    timeout "${GH_TIMEOUT_SECONDS}s" gh api "${args[@]}"
  else
    gh api "${args[@]}"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --confirm) confirm="true"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: Unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

require_cmd gh
require_cmd jq
mkdir -p "$ROOT/tmp"

if command -v flock >/dev/null 2>&1; then
  exec 9>"$LOCKFILE"
  if ! flock -n 9; then
    echo "ERROR: Another archive run is in progress (lock: $LOCKFILE)" >&2
    exit 3
  fi
fi

echo "[INFO] Mode: $( [[ "$confirm" == "true" ]] && echo "CONFIRM" || echo "DRY-RUN" )"
echo "[INFO] Cooldown: ${COOLDOWN_SECONDS}s"
echo "[INFO] GH timeout: ${GH_TIMEOUT_SECONDS}s"
echo ""

for repo in "${REPOS[@]}"; do
  echo "== $repo =="
  page=1
  total=0
  while true; do
    # List issues (and PRs) with the sync-md label. Skip PRs.
    if ! items="$(run_gh_api "repos/${repo}/issues" -X GET -f state=all -f labels=sync-md -f per_page="$PER_PAGE" -f page="$page")"; then
      echo "[ERROR] Failed to list issues for $repo (page=$page)." >&2
      echo "[ERROR] Tip: this may be a GitHub auth/rate-limit/network issue. Try increasing GH_TIMEOUT_SECONDS or COOLDOWN_SECONDS." >&2
      exit 4
    fi

    if ! n="$(printf '%s' "$items" | jq 'length' 2>/dev/null)"; then
      echo "[ERROR] Unexpected response listing issues for $repo (page=$page)." >&2
      echo "[ERROR] Raw response (first 500 chars): $(printf '%s' "$items" | head -c 500)" >&2
      exit 5
    fi
    if [[ "$n" == "0" ]]; then
      break
    fi

    # Extract issue numbers only (exclude PRs).
    mapfile -t nums < <(printf '%s' "$items" | jq -r '.[] | select(.pull_request == null) | .number')
    if (( ${#nums[@]} == 0 )); then
      # If the page only had PRs, keep paging anyway.
      page=$(( page + 1 ))
      continue
    fi

    for num in "${nums[@]}"; do
      total=$(( total + 1 ))
      if [[ "$confirm" != "true" ]]; then
        echo "[DRY-RUN] Would remove sync-md from ${repo}#${num}"
        continue
      fi

      # Removing the label via the dedicated endpoint avoids overwriting other labels.
      if ! run_gh_api "repos/${repo}/issues/${num}/labels/sync-md" -X DELETE >/dev/null 2>&1; then
        echo "[WARN] Failed to remove sync-md from ${repo}#${num} (continuing)" >&2
      fi

      if [[ "$COOLDOWN_SECONDS" != "0" ]]; then
        sleep "$COOLDOWN_SECONDS"
      fi
    done

    page=$(( page + 1 ))
  done

  if [[ "$confirm" == "true" ]]; then
    echo "[OK] Removed sync-md from ${total} issues in $repo"
  else
    echo "[INFO] Would remove sync-md from ${total} issues in $repo"
  fi
  echo ""
done

echo "Done."
