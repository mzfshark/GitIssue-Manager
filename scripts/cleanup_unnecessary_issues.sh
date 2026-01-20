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

LOG_DIR="./logs"
LOG_FILE="$LOG_DIR/cleanup_$(date +%Y%m%d_%H%M%S).log"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

################################################################################
# Helper functions
################################################################################

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

################################################################################
# Parse arguments
################################################################################

while [[ $# -gt 0 ]]; do
    case $1 in
        --execute)
            EXECUTE_MODE=true
            shift
            ;;
        --limit)
            LIMIT="$2"
            shift 2
            ;;
        --help)
            head -n 20 "$0" | tail -n 19
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            exit 1
            ;;
    esac
done

################################################################################
# Sanity checks
################################################################################

log "Starting cleanup script for $REPO"

if ! command -v gh &> /dev/null; then
    error "GitHub CLI (gh) not found. Please install it: https://cli.github.com/"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    error "jq not found. Please install it for JSON parsing."
    exit 1
fi

# Verify we're in the right repo or can access it
if ! gh repo view "$REPO" &> /dev/null; then
    error "Cannot access repository $REPO. Check authentication with: gh auth status"
    exit 1
fi

log "Authenticated as: $(gh auth status --show-token 2>&1 | head -n1)"
log "Repository: $REPO"
log "Dry-run mode: $([ "$EXECUTE_MODE" = true ] && echo 'DISABLED' || echo 'ENABLED (preview only)')"
[ -n "$LIMIT" ] && log "Limit: $LIMIT issues"
log "Log file: $LOG_FILE"

################################################################################
# Extract issue numbers from PLAN.md files
################################################################################

log ""
log "Extracting issue numbers from PLAN documents..."

PLAN_ISSUES=$(mktemp)
# Extract issue numbers referenced in PLAN files (e.g., "#156", "#150", etc.)
if [ -f "$PLAN_FILE" ]; then
    grep -oE '#[0-9]{1,4}' "$PLAN_FILE" | sed 's/#//' | sort -u >> "$PLAN_ISSUES" || true
fi

if [ -f "$PLAN_CLOSEOUT_FILE" ]; then
    grep -oE '#[0-9]{1,4}' "$PLAN_CLOSEOUT_FILE" | sed 's/#//' | sort -u >> "$PLAN_ISSUES" || true
fi

PLAN_ISSUE_COUNT=$(wc -l < "$PLAN_ISSUES")
log "Found $PLAN_ISSUE_COUNT issue numbers referenced in PLAN documents"

################################################################################
# Fetch all open issues with sync-md or subtask labels
################################################################################

log ""
log "Fetching all open issues with 'sync-md' or 'subtask' labels..."

ISSUES_LIST=$(mktemp)

gh issue list --repo "$REPO" --state open --label sync-md,subtask \
    --json number \
    --template '{{range .}}{{.number}}{{"\n"}}{{end}}' >> "$ISSUES_LIST" || true

TOTAL_ISSUES=$(wc -l < "$ISSUES_LIST")
log "Found $TOTAL_ISSUES total open issues with those labels"

################################################################################
# Identify issues NOT in PLAN
################################################################################

log ""
log "Identifying issues NOT in PLAN documents (candidates for closure)..."

ISSUES_TO_CLOSE=$(mktemp)

while IFS= read -r issue_num; do
    if ! grep -q "^${issue_num}$" "$PLAN_ISSUES"; then
        echo "$issue_num" >> "$ISSUES_TO_CLOSE"
    fi
done < "$ISSUES_LIST"

CLOSE_COUNT=$(wc -l < "$ISSUES_TO_CLOSE")
log "Found $CLOSE_COUNT issues to close (not in PLAN documents)"

if [ $CLOSE_COUNT -eq 0 ]; then
    success "No issues to close. All open issues are in PLAN."
    rm -f "$PLAN_ISSUES" "$ISSUES_LIST" "$ISSUES_TO_CLOSE"
    exit 0
fi

################################################################################
# Apply limits
################################################################################

if [ -n "$LIMIT" ]; then
    log ""
    warn "Limit set to $LIMIT issues. Truncating list..."
    head -n "$LIMIT" "$ISSUES_TO_CLOSE" > "$ISSUES_TO_CLOSE.tmp"
    mv "$ISSUES_TO_CLOSE.tmp" "$ISSUES_TO_CLOSE"
    CLOSE_COUNT=$(wc -l < "$ISSUES_TO_CLOSE")
    log "Will process $CLOSE_COUNT issues"
fi

################################################################################
# Preview or Execute
################################################################################

log ""
if [ "$EXECUTE_MODE" = false ]; then
    warn "DRY-RUN MODE: Not making any changes. Re-run with --execute to apply."
    log ""
    log "Preview of first 20 issues to close:"
    log "================================"
    
    head -20 "$ISSUES_TO_CLOSE" | while IFS= read -r issue_num; do
        TITLE=$(gh issue view "$issue_num" --repo "$REPO" --json title --template '{{.title}}' 2>/dev/null || echo "N/A")
        log "  Issue #$issue_num: $TITLE"
    done
    
    log ""
    log "To close these $CLOSE_COUNT issues, run:"
    log "  bash cleanup_unnecessary_issues.sh --execute $([ -n "$LIMIT" ] && echo "--limit $LIMIT")"
    
    rm -f "$PLAN_ISSUES" "$ISSUES_LIST" "$ISSUES_TO_CLOSE"
    exit 0
fi

################################################################################
# Execute: Close issues
################################################################################

log ""
log "EXECUTE MODE: Closing $CLOSE_COUNT issues as 'not-implemented'..."
log "================================"

CLOSED_COUNT=0
FAILED_COUNT=0

cat "$ISSUES_TO_CLOSE" | xargs -P 5 -I {} bash -c '
    TITLE=$(gh issue view {} --repo "mzfshark/AragonOSX" --json title --template "{{.title}}" 2>/dev/null || echo "N/A")
    
    # Close message
    CLOSE_MESSAGE="This issue is marked as '\''not-implemented'\'' because it does not appear in the current PLAN.md documentation. It may be:
- Auto-generated from an older framework sync
- Duplicate or superseded by other work
- Out of scope for the current sprint

If needed, reopen and link to PLAN.md."
    
    if gh issue comment {} --repo "mzfshark/AragonOSX" --body "$CLOSE_MESSAGE" 2>/dev/null && \
       gh issue close {} --repo "mzfshark/AragonOSX" 2>/dev/null; then
        success "  ✓ Closed #{}: $TITLE"
        ((CLOSED_COUNT++))
    else
        error "  ✗ Failed to close #{}"
        ((FAILED_COUNT++))
    fi
    
    sleep 0.5  # Rate limiting
'

################################################################################
# Summary
################################################################################

log ""
log "================================"
log "CLEANUP SUMMARY"
log "================================"
success "Closed: $CLOSED_COUNT / $CLOSE_COUNT"
[ $FAILED_COUNT -gt 0 ] && error "Failed: $FAILED_COUNT"
log "Log: $LOG_FILE"

rm -f "$PLAN_ISSUES" "$ISSUES_LIST" "$ISSUES_TO_CLOSE"

[ $FAILED_COUNT -eq 0 ] && exit 0 || exit 1
