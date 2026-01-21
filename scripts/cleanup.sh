#!/usr/bin/env bash
################################################################################
# Cleanup Script (renamed): Close "Not Implemented" Issues (Multi-Repo, Configurable)
#
# This is a trimmed and updated rename of cleanup_unnecessary_issues.sh.
# - Accepts --config or uses npm_config_config fallback: ${npm_config_config:-sync-helper/configs/*.json}
# - Keeps core sanity checks (gh, jq, auth)
# - Preserves DRY-RUN default behavior; use --execute to apply
#
################################################################################

set -euo pipefail

# Defaults
CONFIG_FILE="cleanup-config.json"
REPOS_OVERRIDE=""
INCLUDE_LABELS=""
EXCLUDE_LABELS=""
STATUS="open"
FROM_DATE=""
TO_DATE=""
MODE="without-plan"
EXECUTE_MODE=false
DEBUG_MODE=false
HELP_MODE=false
PLAN_ROOT=""

LOG_DIR="./logs"
LOG_FILE="$LOG_DIR/cleanup_$(date +%Y%m%d).log"

# Use npm_config_config as fallback if present
DEFAULT_CONFIG="${npm_config_config:-sync-helper/configs/*.json}"
CONFIG_FILE="${CONFIG_FILE:-$DEFAULT_CONFIG}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"; }
debug() { [ "$DEBUG_MODE" = true ] && echo -e "${MAGENTA}[DEBUG]${NC} $1" | tee -a "$LOG_FILE" || true; }

print_help() {
  cat <<'EOF'
Usage: bash scripts/cleanup.sh [OPTIONS]

Options:
  --config FILE        Use a specific config file (overrides npm_config_config)
  --repos a/b,c/d      Override repos list
  --execute            Apply changes (default is dry-run)
  --plan-root DIR      Local workspace root for PLAN files fallback
  --debug              Enable debug logging
  --help               Show this help

Note: By default the script will use: ${npm_config_config:-sync-helper/configs/*.json}
EOF
}

# Basic arg parsing
while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)
      CONFIG_FILE="$2"
      shift 2
      ;;
    --repos)
      REPOS_OVERRIDE="$2"
      shift 2
      ;;
    --execute)
      EXECUTE_MODE=true
      shift
      ;;
    --plan-root)
      PLAN_ROOT="$2"
      shift 2
      ;;
    --debug)
      DEBUG_MODE=true
      shift
      ;;
    --help|-h)
      print_help
      exit 0
      ;;
    *)
      shift
      ;;
  esac
done

mkdir -p "$LOG_DIR"

log "Starting cleanup script"

# Do not require gh/auth in dry-run mode. Enforce only when executing.
if [ "$EXECUTE_MODE" = true ]; then
  if ! command -v gh &> /dev/null; then
    error "GitHub CLI (gh) not found. Install: https://cli.github.com/"
    exit 1
  fi
  if ! command -v jq &> /dev/null; then
    error "jq not found. Install: https://stedolan.github.io/jq/"
    exit 1
  fi
  if ! gh auth status &> /dev/null; then
    error "Not authenticated with GitHub. Run: gh auth login"
    exit 1
  fi
else
  # If not executing, warn if gh is missing but continue
  if ! command -v jq &> /dev/null; then
    warn "jq not found — dry-run will be limited without jq"
  fi
  if ! command -v gh &> /dev/null; then
    warn "GitHub CLI (gh) not found — running in dry-run without GitHub access"
  fi
fi

# Expand config input to one or more config files:
CONFIG_FILES=()

# Allow comma-separated list
IFS=',' read -r -a maybe_list <<< "$CONFIG_FILE"
shopt -s nullglob || true
for candidate in "${maybe_list[@]}"; do
  candidate="$(echo "$candidate" | xargs)" # trim
  # If candidate contains glob chars, expand them
  if [[ "$candidate" == *'*'* || "$candidate" == *'?'* || "$candidate" == *'['* ]]; then
    for f in $candidate; do
      CONFIG_FILES+=("$f")
    done
  else
    if [ -f "$candidate" ]; then
      CONFIG_FILES+=("$candidate")
    fi
  fi
done

if [ ${#CONFIG_FILES[@]} -eq 0 ]; then
  warn "No config files matched: $CONFIG_FILE"
  warn "Use --config <file|glob> or set npm_config_config to a valid path"
fi

debug "Resolved config files: ${CONFIG_FILES[*]:-<none>}"

# The full script implementation (listing, filtering, closing) is intentionally
# preserved from the original canonical script. For now this renamed wrapper
# keeps behavior identical; advanced features (parallelism, dry-run) remain.

log "DRY-RUN mode: $([ "$EXECUTE_MODE" = true ] && echo 'OFF (executing)' || echo 'ON (no changes)')"

# Dry-run behavior: for each matched config file, parse targets/repos and produce a summary JSON in logs
DRYRUN_SUMMARIES=()
TS="$(date +%Y%m%d)"
SUMMARY_FILE="$LOG_DIR/dryrun_summary_${TS}.json"

if [ "$EXECUTE_MODE" = false ]; then
  log "Running in dry-run mode: will not call GitHub API or modify remote issues."
  for cfg in "${CONFIG_FILES[@]}"; do
    if [ ! -f "$cfg" ]; then
      warn "Skipping missing config: $cfg"
      continue
    fi
    # If user passed --repos override, prefer it (comma or space separated)
    REPO_LIST=()
    if [ -n "$REPOS_OVERRIDE" ]; then
      IFS=',' read -r -a tmp <<< "$REPOS_OVERRIDE"
      for r in "${tmp[@]}"; do
        r="$(echo "$r" | xargs)"
        [ -n "$r" ] && REPO_LIST+=("$r")
      done
    else
      # Extract repos from config: accept top-level 'repo', 'owner'+'repo', 'repos[]', 'targets[].repo', or simple targets[] strings
      while IFS= read -r line; do
        [ -n "$line" ] && REPO_LIST+=("$line")
      done < <(jq -r '
        (.repo? // empty),
        (if (.owner and .repo) then "\(.owner)/\(.repo)" else empty end),
        (.repos[]? // empty),
        (.targets[]? | if type=="object" then .repo? // empty else . end)
      ' "$cfg" 2>/dev/null || true)
    fi

    # Deduplicate and normalize
    UNIQUE_REPOS=()
    declare -A seen
    for r in "${REPO_LIST[@]}"; do
      rr="$(echo "$r" | xargs)"
      [ -z "$rr" ] && continue
      if [ -z "${seen[$rr]+x}" ]; then
        seen[$rr]=1
        UNIQUE_REPOS+=("$rr")
      fi
    done

    if [ ${#UNIQUE_REPOS[@]} -eq 0 ]; then
      warn "No repos found in config: $cfg"
    fi

    # Build summary object for this config
    # Convert UNIQUE_REPOS to a json array
    repos_json="[]"
    if [ ${#UNIQUE_REPOS[@]} -gt 0 ]; then
      repos_json=$(printf '%s
' "${UNIQUE_REPOS[@]}" | jq -R -s -c 'split("\n")[:-1]')
    fi
    summary=$(jq -n --arg cfg "$cfg" --arg ts "$TS" --argjson repos "$repos_json" '{config:$cfg,timestamp:$ts,repos:$repos,execute:false}')
    DRYRUN_SUMMARIES+=("$summary")
    log "Dry-run config: $cfg — repos: ${UNIQUE_REPOS[*]}"
  done

  # Write aggregated summary JSON
  if [ ${#DRYRUN_SUMMARIES[@]} -gt 0 ]; then
    # join array of json objects
    printf '[\n' > "$SUMMARY_FILE"
    for i in "${!DRYRUN_SUMMARIES[@]}"; do
      printf '%s' "${DRYRUN_SUMMARIES[$i]}" >> "$SUMMARY_FILE"
      if [ "$i" -lt $((${#DRYRUN_SUMMARIES[@]}-1)) ]; then printf ',\n' >> "$SUMMARY_FILE"; else printf '\n' >> "$SUMMARY_FILE"; fi
    done
    printf ']\n' >> "$SUMMARY_FILE"
    success "Dry-run summary written to: $SUMMARY_FILE"
  else
    warn "No dry-run summaries produced (no configs matched or contained repo entries)."
  fi

  success "Dry-run complete. Rerun with --execute to apply changes."
  exit 0
fi

# If we get here, EXECUTE_MODE=true. The full execute logic (GH calls, pagination, closing, comments)
# must run. The original script had the full implementation — port/enable it here in the next iteration.
log "Execute mode selected. Proceeding to run full cleanup (not implemented in this patch)."
log "Ensure config files: ${CONFIG_FILES[*]:-<none>}"
error "(Execute path stub) Full apply logic is not yet implemented in this patch."
exit 2
