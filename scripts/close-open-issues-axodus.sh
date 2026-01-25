#!/usr/bin/env bash
set -euo pipefail

# Close open issues in Axodus repos (dev reset helper).
# - Dry-run by default. Use --confirm to actually close.
# - Does not touch ProjectV2; only closes issues.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

LOCKFILE="$ROOT/tmp/close-open-issues-axodus.lock"

COOLDOWN_SECONDS="${COOLDOWN_SECONDS:-2}"

REPOS=(
  "Axodus/AragonOSX"
  "Axodus/aragon-app"
  "Axodus/Aragon-app-backend"
)

confirm="false"

usage() {
  cat <<'EOF'
Usage: close-open-issues-axodus.sh [--confirm]

Environment:
  COOLDOWN_SECONDS=2   Sleep between close operations (seconds)

Notes:
  - Dry-run is default.
  - Closing is reversible (issues can be reopened).
EOF
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: Missing dependency: $cmd" >&2
    exit 1
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
    echo "ERROR: Another close run is in progress (lock: $LOCKFILE)" >&2
    exit 3
  fi
fi

is_rate_limit_text() {
  local s="$1"
  s="${s,,}"
  [[ "$s" == *"api rate limit exceeded"* ]] || \
  [[ "$s" == *"secondary rate limit"* ]] || \
  [[ "$s" == *"abuse detection"* ]] || \
  [[ "$s" == *"http 403"* ]]
}

close_issue_with_retry() {
  local repo="$1"
  local number="$2"

  local max_attempts=6
  local attempt=1
  while (( attempt <= max_attempts )); do
    local out
    out="$(gh issue close --repo "$repo" "$number" --comment "Dev reset: closing issues to rebuild from GitIssuer Markdown sync." 2>&1)" && return 0

    # Fallback: sometimes the GraphQL close mutation fails, but the REST update works.
    if [[ "$out" == *"Could not close the issue"* ]]; then
      if gh api "repos/${repo}/issues/${number}" -X PATCH -f state=closed >/dev/null 2>&1; then
        echo "[WARN] Closed via REST fallback: ${repo}#${number}" >&2
        return 0
      fi
    fi

    if is_rate_limit_text "$out" && (( attempt < max_attempts )); then
      local backoff=$(( 2 ** (attempt - 1) ))
      if (( backoff > 60 )); then backoff=60; fi
      echo "[WARN] Rate-limited closing $repo#$number (attempt $attempt/$max_attempts); sleeping ${backoff}s" >&2
      sleep "$backoff"
      attempt=$(( attempt + 1 ))
      continue
    fi

    echo "[WARN] Failed to close $repo#$number (attempt $attempt/$max_attempts): ${out:0:160}" >&2
    attempt=$(( attempt + 1 ))
    sleep 1
  done

  return 1
}

echo "[INFO] Mode: $( [[ "$confirm" == "true" ]] && echo "CONFIRM" || echo "DRY-RUN" )"
echo "[INFO] Cooldown: ${COOLDOWN_SECONDS}s"
echo ""

for repo in "${REPOS[@]}"; do
  echo "== $repo =="

  # Fetch open issues (not PRs).
  # gh issue list excludes PRs by default.
  issues_json="$(gh issue list --repo "$repo" --state open --limit 1000 --json number,title 2>/dev/null || echo '[]')"
  count="$(printf '%s' "$issues_json" | jq 'length')"
  echo "open issues: $count"

  if [[ "$count" == "0" ]]; then
    echo ""
    continue
  fi

  if [[ "$confirm" != "true" ]]; then
    echo "[DRY-RUN] Would close $count issues in $repo"
    echo ""
    continue
  fi

  echo "[INFO] Closing issues in $repo..."
  i=0
  while read -r n; do
    [[ -n "$n" ]] || continue
    i=$(( i + 1 ))
    if (( i % 10 == 1 )); then
      echo "progress: $i/$count" >&2
    fi

    if ! close_issue_with_retry "$repo" "$n"; then
      echo "[WARN] Giving up on $repo#$n; continuing" >&2
    fi

    if [[ "$COOLDOWN_SECONDS" != "0" ]]; then
      sleep "$COOLDOWN_SECONDS"
    fi
  done < <(printf '%s' "$issues_json" | jq -r '.[].number')

  echo "[OK] Closed issues for $repo"
  echo ""
done

echo "Done."
