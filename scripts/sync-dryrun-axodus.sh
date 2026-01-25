#!/usr/bin/env bash
set -euo pipefail

# Runs `gitissuer sync --dry-run` for Axodus repos with per-repo logs.
# - Safe by default (dry-run)
# - Adds a small cooldown between repos to reduce GitHub secondary rate-limit pressure
# - Stores logs under GitIssue-Manager/tmp/sync-dryrun-logs/

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

COOLDOWN_SECONDS="${COOLDOWN_SECONDS:-3}"
NO_LINK_HIERARCHY="${NO_LINK_HIERARCHY:-1}"   # 1 => add --no-link-hierarchy

# Reduce GitHub secondary rate-limit pressure.
# - Throttle between gh API calls inside the executor
# - Keep Search API fallback disabled (it is more likely to trigger secondary limits)
export GITISSUER_GH_MIN_DELAY_MS="${GITISSUER_GH_MIN_DELAY_MS:-400}"
export GITISSUER_USE_SEARCH_FALLBACK="${GITISSUER_USE_SEARCH_FALLBACK:-0}"

REPOS=(
  "Axodus/AragonOSX"
  "Axodus/aragon-app"
  "Axodus/Aragon-app-backend"
)

LOG_DIR="$ROOT/tmp/sync-dryrun-logs"
mkdir -p "$LOG_DIR"

if ! command -v gh >/dev/null 2>&1; then
  echo "ERROR: gh CLI not found in PATH" >&2
  exit 1
fi

if ! command -v bash >/dev/null 2>&1; then
  echo "ERROR: bash not found" >&2
  exit 1
fi

if [[ ! -x "$ROOT/bin/gitissuer" ]]; then
  echo "ERROR: $ROOT/bin/gitissuer not found or not executable" >&2
  exit 1
fi

for repo in "${REPOS[@]}"; do
  safe="${repo//\//_}"
  log="$LOG_DIR/${safe}.log"

  echo "== sync --dry-run: $repo =="
  echo "log: $log"

  args=(sync --repo "$repo" --dry-run)
  if [[ "$NO_LINK_HIERARCHY" == "1" ]]; then
    args+=(--no-link-hierarchy)
  fi

  # Capture stdout+stderr into file (and show a minimal live header)
  {
    echo "# $(date -Is)"
    echo "# repo=$repo"
    echo "# cmd=$ROOT/bin/gitissuer ${args[*]}"
    echo ""
    "$ROOT/bin/gitissuer" "${args[@]}"
  } >"$log" 2>&1 || true

  # Quick summary line for operators
  created_count=$(grep -cE "\[DRY-RUN\] Would create (issue|subtask)" "$log" 2>/dev/null || true)
  found_count=$(grep -cE "\[DEBUG\] Found existing issue" "$log" 2>/dev/null || true)
  rate_count=$(grep -ciE "rate limit|secondary rate limit|abuse detection|HTTP 403" "$log" 2>/dev/null || true)

  echo "summary: would-create=$created_count found-existing=$found_count rate-limit-lines=$rate_count"

  if [[ "$COOLDOWN_SECONDS" != "0" ]]; then
    sleep "$COOLDOWN_SECONDS"
  fi

  echo ""
done

echo "Done. Logs: $LOG_DIR"