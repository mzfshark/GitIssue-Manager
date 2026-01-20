#!/usr/bin/env bash

################################################################################
# Cleanup Script: Close "Not Implemented" Issues (Multi-Repo, Configurable)
#
# Purpose: Identify and close issues across multiple repositories that are NOT
# referenced in PLAN.md files, marking them as "not-implemented".
#
# Features:
#   - Multi-repo support (configurable via CLI or JSON config)
#   - Hybrid mode: config.json + CLI flags override
#   - Selective filtering: labels, dates, status, etc.
#   - Paginação para alcançar 10k+ issues
#   - Parallel execution (xargs -P 5)
#   - Safety: DRY-RUN mode by default
#
# Usage:
#   bash cleanup_unnecessary_issues.sh [OPTIONS]
#
# Examples:
#   bash cleanup_unnecessary_issues.sh --limit 10              # Preview (dry-run)
#   bash cleanup_unnecessary_issues.sh --execute --limit 50    # Close first 50
#   bash cleanup_unnecessary_issues.sh --repos "owner/repo"    # Specific repo
#   bash cleanup_unnecessary_issues.sh --config custom.json    # Custom config
#   bash cleanup_unnecessary_issues.sh --help                  # Full help
#
################################################################################

set -euo pipefail

# ============================================================================
# DEFAULTS & CONFIGURATION
# ============================================================================

CONFIG_FILE="cleanup-config.json"
REPOS_OVERRIDE=""
INCLUDE_LABELS=""
EXCLUDE_LABELS=""
STATUS="open"
FROM_DATE=""
TO_DATE=""
MODE="without-plan"
EXECUTE_MODE=false
LIMIT=""
DEBUG_MODE=false
HELP_MODE=false

# Where to read PLAN files from locally (fallback if GitHub Contents API fails).
# If empty, only remote extraction is attempted.
PLAN_ROOT=""

LOG_DIR="./logs"
LOG_FILE="$LOG_DIR/cleanup_$(date +%Y%m%d_%H%M%S).log"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Runtime values loaded from config (with safe defaults)
MAX_PARALLEL=5
SLEEP_SECONDS=0.5
COMMENT_ON_CLOSE_ENABLED=true
CLOSE_MESSAGE=""

CONFIGURED_REPOS=""

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

log() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

debug() {
    [ "$DEBUG_MODE" = true ] && echo -e "${MAGENTA}[DEBUG]${NC} $1" | tee -a "$LOG_FILE" || true
}

print_help() {
    cat << 'EOF'
GitHub Issue Cleanup Script - Multi-Repo Configuration

USAGE:
  bash cleanup_unnecessary_issues.sh [OPTIONS]

OPTIONS:
    --repos REPO1,REPO2,...     Override repos from config (format: owner/repo,owner/repo). If a value has no '/', it is resolved against repos in config.
  --config FILE               Use custom config file (default: cleanup-config.json)
    --plan-root DIR              Local workspace root containing repos (fallback for reading PLAN files)
  --include-labels LABEL1,... Include ONLY issues with these labels
  --exclude-labels LABEL1,... Exclude issues with these labels
  --status open|closed|all    Filter by status (default: open)
  --from-date YYYY-MM-DD      Include issues created BEFORE this date
  --to-date YYYY-MM-DD        Include issues created AFTER this date
  --without-plan              Close issues NOT in PLAN (default)
  --with-plan                 Close issues IN PLAN (inverse logic, debug mode)
  --limit N                   Process at most N issues
  --execute                   Apply changes (default: dry-run preview)
  --debug                     Verbose output for troubleshooting
  --help                      Show this help message

EXAMPLES:
  # Preview first 20 issues (dry-run, safe)
  bash cleanup_unnecessary_issues.sh --limit 20

  # Close first 50 issues not in PLAN
  bash cleanup_unnecessary_issues.sh --execute --limit 50

  # Multi-repo cleanup
  bash cleanup_unnecessary_issues.sh \
    --repos "mzfshark/AragonOSX,Axodus/aragon-app" \
    --execute

  # Filter by label
  bash cleanup_unnecessary_issues.sh \
    --include-labels "sync-md" \
    --execute --limit 100

  # Cleanup old issues (before 2025-01-01)
  bash cleanup_unnecessary_issues.sh \
    --from-date "2025-01-01" \
    --execute

DOCUMENTATION:
  Full guide: docs/CLEANUP_SCRIPT_GUIDE.md
  Examples:   docs/CLEANUP_EXAMPLES.md
  Config:     docs/cleanup-config.example.json

EOF
}

split_csv_to_json_array() {
    local csv="$1"
    if [ -z "$csv" ]; then
        echo '[]'
        return
    fi
    # shellcheck disable=SC2001
    echo "$csv" | tr ',' '\n' | sed 's/^ *//; s/ *$//' | awk 'NF' | jq -R . | jq -s .
}

resolve_repo_aliases() {
    # Converts input repos (possibly without owner) into canonical owner/repo
    # based on configured repos in cleanup-config.json.
    local input_repos="$1"
    local resolved=""
    while IFS= read -r item; do
        item="$(echo "$item" | sed 's/^ *//; s/ *$//')"
        [ -z "$item" ] && continue

        if echo "$item" | grep -q '/'; then
            resolved+="$item"$'\n'
            continue
        fi

        # Try to match by repo name suffix
        local matches
        matches=$(echo "$CONFIGURED_REPOS" | awk -F/ -v name="$item" '$2==name {print $0}')
        local match_count
        match_count=$(echo "$matches" | awk 'NF' | wc -l | tr -d ' ')

        if [ "$match_count" -eq 1 ]; then
            resolved+="$matches"$'\n'
        elif [ "$match_count" -eq 0 ]; then
            error "Repo alias '$item' not found in config. Use owner/repo or add it to $CONFIG_FILE."
            exit 1
        else
            error "Repo alias '$item' is ambiguous. Matches: $(echo "$matches" | tr '\n' ',' | sed 's/,$//')"
            error "Use full owner/repo in --repos to disambiguate."
            exit 1
        fi
    done <<< "$(echo "$input_repos" | tr ',' '\n')"

    echo "$resolved" | awk 'NF'
}

# ============================================================================
# ARGUMENT PARSING
# ============================================================================

while [[ $# -gt 0 ]]; do
    case $1 in
        --repos)
            REPOS_OVERRIDE="$2"
            shift 2
            ;;
        --config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --include-labels)
            INCLUDE_LABELS="$2"
            shift 2
            ;;
        --exclude-labels)
            EXCLUDE_LABELS="$2"
            shift 2
            ;;
        --status)
            STATUS="$2"
            shift 2
            ;;
        --from-date)
            FROM_DATE="$2"
            shift 2
            ;;
        --to-date)
            TO_DATE="$2"
            shift 2
            ;;
        --plan-root)
            PLAN_ROOT="$2"
            shift 2
            ;;
        --without-plan)
            MODE="without-plan"
            shift
            ;;
        --with-plan)
            MODE="with-plan"
            shift
            ;;
        --limit)
            LIMIT="$2"
            shift 2
            ;;
        --execute)
            EXECUTE_MODE=true
            shift
            ;;
        --debug)
            DEBUG_MODE=true
            shift
            ;;
        --help)
            print_help
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            print_help
            exit 1
            ;;
    esac
done

# ============================================================================
# SANITY CHECKS
# ============================================================================

mkdir -p "$LOG_DIR"

log "Starting GitHub Issue Cleanup Script"
log "========================================"

# Check dependencies
if ! command -v gh &> /dev/null; then
    error "GitHub CLI (gh) not found. Install: https://cli.github.com/"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    error "jq not found. Install: https://stedolan.github.io/jq/"
    exit 1
fi

# Verify authentication
if ! gh auth status &> /dev/null; then
    error "Not authenticated with GitHub. Run: gh auth login"
    exit 1
fi

log "Authenticated as: $(gh auth status --show-token 2>&1 | head -n1 | grep -oE 'Logged in.*' || echo 'User')"
log "Mode: $MODE ($([ "$EXECUTE_MODE" = true ] && echo 'EXECUTE' || echo 'DRY-RUN'))"
[ "$DEBUG_MODE" = true ] && log "Debug mode: ENABLED"

# ============================================================================
# LOAD CONFIGURATION
# ============================================================================

log ""
log "Loading configuration..."

if [ ! -f "$CONFIG_FILE" ]; then
    error "Config file not found: $CONFIG_FILE"
    error "Create one: cp docs/cleanup-config.example.json cleanup-config.json"
    exit 1
fi

# Parse config.json
CONFIGURED_REPOS=$(jq -r '.repos[]' "$CONFIG_FILE" 2>/dev/null || echo "")
REPOS="$CONFIGURED_REPOS"
if [ -z "$REPOS" ]; then
    error "No repos found in $CONFIG_FILE"
    exit 1
fi

# Load runtime settings
LOG_DIR=$(jq -r '.logging.log_directory // "./logs"' "$CONFIG_FILE" 2>/dev/null || echo "./logs")
MAX_PARALLEL=$(jq -r '.rate_limiting.max_parallel_operations // 5' "$CONFIG_FILE" 2>/dev/null || echo 5)
SLEEP_SECONDS=$(jq -r '.rate_limiting.sleep_between_requests_seconds // 0.5' "$CONFIG_FILE" 2>/dev/null || echo 0.5)
COMMENT_ON_CLOSE_ENABLED=$(jq -r '.comment_on_close.enabled // true' "$CONFIG_FILE" 2>/dev/null || echo true)
CLOSE_MESSAGE=$(jq -r '.comment_on_close.message // "This issue is marked as not-implemented."' "$CONFIG_FILE" 2>/dev/null || echo "This issue is marked as not-implemented.")

# Load PLAN root preference
if [ -z "$PLAN_ROOT" ]; then
    PLAN_ROOT=$(jq -r '.plan_root // ""' "$CONFIG_FILE" 2>/dev/null || echo "")
fi
if [ -z "$PLAN_ROOT" ] && [ -n "${PLAN_ROOT:-}" ]; then
    : # keep
fi

# Auto-detect common workspace layout (WSL default for this workspace)
if [ -z "$PLAN_ROOT" ] && [ -d "/mnt/d/Rede/Github/mzfshark" ]; then
    PLAN_ROOT="/mnt/d/Rede/Github/mzfshark"
fi

mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/cleanup_$(date +%Y%m%d_%H%M%S).log"

if [ -n "$PLAN_ROOT" ]; then
    log "PLAN root (local fallback): $PLAN_ROOT"
else
    warn "PLAN root not set; PLAN extraction will rely on GitHub Contents API only. Use --plan-root to point to your local repos root."
fi

# Override repos if --repos provided
if [ -n "$REPOS_OVERRIDE" ]; then
    debug "Overriding repos from config"
    REPOS=$(resolve_repo_aliases "$REPOS_OVERRIDE")
fi

REPO_COUNT=$(echo "$REPOS" | wc -l)
log "Found $REPO_COUNT repo(s) to process"
debug "Repos: $(echo "$REPOS" | tr '\n' ', ' | sed 's/,$//')"

# ============================================================================
# MAIN PROCESSING LOOP
# ============================================================================

TOTAL_CLOSED=0
TOTAL_FAILED=0
GRAND_TOTAL_REPOS=0

# Avoid ((var++)) under set -e (returns exit code 1 when expression evaluates to 0)
while IFS= read -r REPO; do
    [ -z "$REPO" ] && continue

    GRAND_TOTAL_REPOS=$((GRAND_TOTAL_REPOS + 1))
    
    log ""
    log "========================================"
    log "Processing repo $GRAND_TOTAL_REPOS/$REPO_COUNT: $REPO"
    log "========================================"
    
    # Get PLAN files for this repo
    PLAN_FILES=$(jq -r ".plan_files.\"$REPO\"[]? // empty" "$CONFIG_FILE" 2>/dev/null | tr '\n' ' ')
    
    if [ -z "$PLAN_FILES" ]; then
        warn "No PLAN files configured for $REPO. Using defaults (PLAN.md)"
        PLAN_FILES="PLAN.md"
    fi
    
    debug "PLAN files: $PLAN_FILES"
    
    # ========================================================================
    # EXTRACT ISSUE NUMBERS FROM PLAN FILES
    # ========================================================================
    
    log ""
    log "Extracting issue numbers from PLAN files..."
    
    PLAN_ISSUES=$(mktemp)
    
    # Try to fetch PLAN files from repo and extract issue numbers
    for PLAN_FILE in $PLAN_FILES; do
        debug "Processing PLAN file: $PLAN_FILE"

        # Fetch file content from repo (base64) and extract issue references.
        # We intentionally prefer remote content since this tool runs from GitIssue-Manager.
        if gh api "repos/${REPO}/contents/${PLAN_FILE}" --jq '.content' 2>/dev/null | \
            base64 -d 2>/dev/null | \
            grep -oE '#[0-9]{1,6}|Issue[[:space:]]+[#]?[0-9]{1,6}' | \
            sed 's/[^0-9]//g' | \
            sort -u >> "$PLAN_ISSUES" 2>/dev/null; then
            debug "  ✓ Extracted from remote $PLAN_FILE"
            continue
        fi

        debug "  ⚠ Remote extraction failed for $PLAN_FILE"

        # Local fallback: read from PLAN_ROOT/<repoName>/<PLAN_FILE>
        if [ -n "$PLAN_ROOT" ]; then
            repo_name=$(echo "$REPO" | awk -F/ '{print $2}')
            local_plan_path="$PLAN_ROOT/$repo_name/$PLAN_FILE"
            if [ -f "$local_plan_path" ]; then
                debug "  ✓ Extracting from local file: $local_plan_path"
                grep -oE '#[0-9]{1,6}|Issue[[:space:]]+[#]?[0-9]{1,6}' "$local_plan_path" | \
                    sed 's/[^0-9]//g' | sort -u >> "$PLAN_ISSUES" || true
            else
                debug "  ✗ Local PLAN file not found: $local_plan_path"
            fi
        fi
    done
    
    PLAN_ISSUE_COUNT=$([ -f "$PLAN_ISSUES" ] && wc -l < "$PLAN_ISSUES" || echo 0)
    log "Found $PLAN_ISSUE_COUNT issue numbers in PLAN files"
    
    if [ "$PLAN_ISSUE_COUNT" -eq 0 ]; then
        warn "No issue numbers found in PLAN. This repo may have no planned issues."
    fi
    
    debug "PLAN issue numbers: $(head -20 "$PLAN_ISSUES" | tr '\n' ',' | sed 's/,$//')"
    
    # ========================================================================
    # BUILD QUERY FOR GH ISSUE LIST
    # ========================================================================
    
    log ""
    log "Building GitHub API query..."

    # Always fetch labels and filter locally to support OR semantics.
    GH_QUERY=(gh issue list --repo "$REPO" --state "$STATUS" --limit 10000 --json number,title,createdAt,labels)
    debug "Query: ${GH_QUERY[*]}"
    
    # ========================================================================
    # FETCH ISSUES FROM GITHUB
    # ========================================================================
    
    log ""
    log "Fetching issues from GitHub..."
    
    ISSUES_LIST=$(mktemp)
    ISSUES_JSON=$(mktemp)

        # Save JSON (source of truth for further filters)
        "${GH_QUERY[@]}" > "$ISSUES_JSON" 2>/dev/null || {
        error "Failed to fetch issues from $REPO"
        rm -f "$PLAN_ISSUES" "$ISSUES_LIST" "$ISSUES_JSON"
        continue
    }

        INCLUDE_JSON=$(split_csv_to_json_array "$INCLUDE_LABELS")
        EXCLUDE_DEFAULT_JSON=$(jq -c '.defaults.skip_labels // []' "$CONFIG_FILE" 2>/dev/null || echo '[]')
        EXCLUDE_OVERRIDE_JSON=$(split_csv_to_json_array "$EXCLUDE_LABELS")
        # Merge default skip_labels + exclude-labels
        EXCLUDE_JSON=$(jq -cn --argjson a "$EXCLUDE_DEFAULT_JSON" --argjson b "$EXCLUDE_OVERRIDE_JSON" '$a + $b | unique')

        # Filter issues into a number list
        jq -r \
                --arg fromDate "$FROM_DATE" \
                --arg toDate "$TO_DATE" \
                --argjson includeLabels "$INCLUDE_JSON" \
                --argjson excludeLabels "$EXCLUDE_JSON" \
                '
                def labelNames: (.labels // []) | map(.name);
                def hasAny($xs):
                    (labelNames) as $ln | any($xs[]; $ln | index(.) != null);
                def createdDate: (.createdAt // "") | split("T")[0];

                .
                | map(select(
                        ( ($fromDate|length)==0 or (createdDate < $fromDate) )
                        and
                        ( ($toDate|length)==0 or (createdDate > $toDate) )
                        and
                        ( ($includeLabels|length)==0 or hasAny($includeLabels) )
                        and
                        ( ($excludeLabels|length)==0 or (hasAny($excludeLabels) | not) )
                    ))
                | .[]
                | .number
                ' "$ISSUES_JSON" > "$ISSUES_LIST" || true

        TOTAL_ISSUES=$(wc -l < "$ISSUES_LIST" | tr -d ' ')
        log "Found $TOTAL_ISSUES issue(s) after filters in $REPO"
    
    if [ -n "$FROM_DATE" ]; then
        debug "Date filter (created BEFORE): $FROM_DATE"
    fi
    if [ -n "$TO_DATE" ]; then
        debug "Date filter (created AFTER): $TO_DATE"
    fi
    if [ -n "$INCLUDE_LABELS" ]; then
        debug "Include labels (OR): $INCLUDE_LABELS"
    fi
    if [ -n "$EXCLUDE_LABELS" ]; then
        debug "Exclude labels: $EXCLUDE_LABELS"
    fi
    
    # ========================================================================
    # IDENTIFY ISSUES TO CLOSE
    # ========================================================================
    
    log ""
    log "Identifying issues to close (mode: $MODE)..."
    
    ISSUES_TO_CLOSE=$(mktemp)
    
    while IFS= read -r issue_num; do
        [ -z "$issue_num" ] && continue
        
        if [ "$MODE" = "without-plan" ]; then
            # Close if NOT in PLAN
            if ! grep -q "^${issue_num}$" "$PLAN_ISSUES" 2>/dev/null; then
                echo "$issue_num" >> "$ISSUES_TO_CLOSE"
            fi
        else
            # Close if IN PLAN (inverse mode, for debug)
            if grep -q "^${issue_num}$" "$PLAN_ISSUES" 2>/dev/null; then
                echo "$issue_num" >> "$ISSUES_TO_CLOSE"
            fi
        fi
    done < "$ISSUES_LIST"
    
    CLOSE_COUNT=$([ -f "$ISSUES_TO_CLOSE" ] && wc -l < "$ISSUES_TO_CLOSE" || echo 0)
    log "Found $CLOSE_COUNT issues to close (mode=$MODE)"
    
    if [ $CLOSE_COUNT -eq 0 ]; then
        success "No issues to close in $REPO. All open issues are in PLAN."
        rm -f "$PLAN_ISSUES" "$ISSUES_LIST" "$ISSUES_JSON" "$ISSUES_TO_CLOSE"
        continue
    fi
    
    # ========================================================================
    # APPLY LIMIT
    # ========================================================================
    
    if [ -n "$LIMIT" ]; then
        debug "Limit: $LIMIT"
        head -n "$LIMIT" "$ISSUES_TO_CLOSE" > "$ISSUES_TO_CLOSE.tmp"
        mv "$ISSUES_TO_CLOSE.tmp" "$ISSUES_TO_CLOSE"
        CLOSE_COUNT=$(wc -l < "$ISSUES_TO_CLOSE")
        log "Limited to $CLOSE_COUNT issues"
    fi
    
    # ========================================================================
    # PREVIEW OR EXECUTE
    # ========================================================================
    
    if [ "$EXECUTE_MODE" = false ]; then
        log ""
        warn "DRY-RUN MODE: Not making any changes. Preview of first 20 issues:"
        log "========================================"
        
        head -20 "$ISSUES_TO_CLOSE" | while read -r issue_num; do
            TITLE=$(jq -r ".[] | select(.number==${issue_num}) | .title" "$ISSUES_JSON" 2>/dev/null | head -1 || echo "N/A")
            log "  Issue #$issue_num: $TITLE"
        done
        
        log ""
        log "Total to close: $CLOSE_COUNT issues"
        log "To execute, run:"
        log "  bash $(basename "$0") --execute $([ -n "$LIMIT" ] && echo "--limit $LIMIT")"
        
        rm -f "$PLAN_ISSUES" "$ISSUES_LIST" "$ISSUES_JSON" "$ISSUES_TO_CLOSE"
        continue
    fi
    
    # ========================================================================
    # EXECUTE: CLOSE ISSUES (PARALLEL)
    # ========================================================================
    
    log ""
    log "EXECUTE MODE: Closing $CLOSE_COUNT issues in $REPO..."
    log "========================================"
    
        CLOSED_MARKERS=$(mktemp)
        FAILED_MARKERS=$(mktemp)

        # Use xargs for parallel execution
        cat "$ISSUES_TO_CLOSE" | xargs -P "$MAX_PARALLEL" -I {} bash -c '
                issue_num="$1"
                repo="$2"
                issues_json="$3"
                log_file="$4"
                close_message="$5"
                sleep_seconds="$6"
                comment_enabled="$7"
                ok_file="$8"
                fail_file="$9"

                title=$(jq -r ".[] | select(.number==${issue_num}) | .title" "$issues_json" 2>/dev/null | head -1 || echo "N/A")

                if [ "$comment_enabled" = "true" ]; then
                    gh issue comment "$issue_num" --repo "$repo" --body "$close_message" 2>/dev/null || {
                        echo "$issue_num" >> "$fail_file"
                        echo -e "'"${RED}[ERROR]${NC}"'   ✗ Failed to comment #${issue_num}" | tee -a "$log_file"
                        sleep "$sleep_seconds"
                        exit 0
                    }
                fi

                if gh issue close "$issue_num" --repo "$repo" 2>/dev/null; then
                    echo "$issue_num" >> "$ok_file"
                    echo -e "'"${GREEN}[SUCCESS]${NC}"'   ✓ Closed #${issue_num}: ${title}" | tee -a "$log_file"
                else
                    echo "$issue_num" >> "$fail_file"
                    echo -e "'"${RED}[ERROR]${NC}"'   ✗ Failed to close #${issue_num}" | tee -a "$log_file"
                fi

                sleep "$sleep_seconds"
        ' _ {} "$REPO" "$ISSUES_JSON" "$LOG_FILE" "$CLOSE_MESSAGE" "$SLEEP_SECONDS" "$COMMENT_ON_CLOSE_ENABLED" "$CLOSED_MARKERS" "$FAILED_MARKERS"

        CLOSED_COUNT=$(wc -l < "$CLOSED_MARKERS" 2>/dev/null | tr -d ' ' || echo 0)
        FAILED_COUNT=$(wc -l < "$FAILED_MARKERS" 2>/dev/null | tr -d ' ' || echo 0)
    log ""
    success "Repo $REPO: Closed $CLOSED_COUNT / $CLOSE_COUNT"

        TOTAL_CLOSED=$((TOTAL_CLOSED + CLOSED_COUNT))
        TOTAL_FAILED=$((TOTAL_FAILED + FAILED_COUNT))
    
        rm -f "$PLAN_ISSUES" "$ISSUES_LIST" "$ISSUES_JSON" "$ISSUES_TO_CLOSE" "$CLOSED_MARKERS" "$FAILED_MARKERS"
done <<< "$REPOS"

# ============================================================================
# FINAL SUMMARY
# ============================================================================

log ""
log "========================================"
log "CLEANUP SUMMARY (All Repos)"
log "========================================"
success "Total repos processed: $GRAND_TOTAL_REPOS"
success "Total closed: $TOTAL_CLOSED"
[ $TOTAL_FAILED -gt 0 ] && error "Total failed: $TOTAL_FAILED"
log "Log file: $LOG_FILE"
log ""

[ $TOTAL_FAILED -eq 0 ] && exit 0 || exit 1
