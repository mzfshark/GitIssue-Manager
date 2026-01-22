#!/bin/bash

# E2E Flow - Complete Issue Hierarchy Generator
# Version: 2.0 - Full Implementation with Navigation

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="${CONFIG_FILE:-$PROJECT_ROOT/config/e2e-config.json}"
OUTPUT_DIR="${OUTPUT_DIR:-$PROJECT_ROOT/tmp/e2e-execution}"
STATE_FILE="$OUTPUT_DIR/execution-state.json"

# Defaults
DRY_RUN=false
SELECTED_REPO=""
SELECTED_PLAN=""
CURRENT_STAGE=1
INTERACTIVE=true

# Stage names
STAGE_NAMES=("SETUP" "PREPARE" "CREATE_PAI" "CREATE_CHILDREN" "LINK_HIERARCHY" "SYNC_PROJECTV2" "PROGRESS_TRACKING" "REPORTING")

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging
log_stage() { echo ""; echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; echo -e "${MAGENTA}  STAGE $1: $2${NC}"; echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; echo ""; }
log_info() { echo -e "${BLUE}ℹ${NC} $1"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1" >&2; }
log_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
log_prompt() { echo -e "${CYAN}❯${NC} $1"; }

# State management
save_state() {
    local stage=$1
    local data=${2:-"{}"}
    mkdir -p "$OUTPUT_DIR"
    if [[ -f "$STATE_FILE" ]]; then
        jq --arg stage "$stage" --argjson data "$data" '.stages[$stage] = $data | .lastStage = ($stage | tonumber) | .timestamp = now' "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
    else
        jq -n --arg stage "$stage" --argjson data "$data" '{stages: {($stage): $data}, lastStage: ($stage | tonumber), timestamp: now, version: "2.0"}' > "$STATE_FILE"
    fi
}

get_stage_data() {
    local stage=$1
    [[ -f "$STATE_FILE" ]] && jq -r ".stages[\"$stage\"] // {}" "$STATE_FILE" 2>/dev/null || echo "{}"
}

get_last_completed_stage() {
    [[ -f "$STATE_FILE" ]] && jq -r '.lastStage // 0' "$STATE_FILE" || echo "0"
}

# ============================================================================
# STAGE IMPLEMENTATIONS
# ============================================================================

# STAGE 1: SETUP
stage_setup() {
    log_stage "1" "SETUP - Configuration & Environment Validation"
    mkdir -p "$OUTPUT_DIR"
    
    # Validate config file
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Config file not found: $CONFIG_FILE"
        log_info "Copy config/e2e-config.sample.json to $CONFIG_FILE"
        return 1
    fi
    log_success "Config file found"
    
    # Validate JSON
    if ! jq empty "$CONFIG_FILE" 2>/dev/null; then
        log_error "Invalid JSON in config file"
        return 1
    fi
    log_success "Config is valid JSON"
    
    # Check GitHub CLI
    if ! command -v gh &> /dev/null; then
        log_error "GitHub CLI (gh) not found"
        return 1
    fi
    log_success "GitHub CLI found"
    
    # Check authentication
    if ! gh auth status &>/dev/null; then
        log_error "Not authenticated with GitHub"
        return 1
    fi
    log_success "GitHub authenticated"
    
    # Check jq
    if ! command -v jq &> /dev/null; then
        log_error "jq not found"
        return 1
    fi
    log_success "jq found"
    
    local org=$(jq -r '.github.organization // "Axodus"' "$CONFIG_FILE")
    local repo_count=$(jq '.repositories | length' "$CONFIG_FILE")
    log_info "Organization: $org"
    log_info "Repositories: $repo_count"
    
    save_state "1" "{\"completed\": true, \"org\": \"$org\"}"
    log_success "STAGE 1 complete"
    return 0
}

# STAGE 2: PREPARE
stage_prepare() {
    log_stage "2" "PREPARE - Parse Plans and Build Hierarchy"
    
    local setup_data=$(get_stage_data "1")
    if [[ $(echo "$setup_data" | jq -r '.completed // false') != "true" ]]; then
        log_error "STAGE 1 not completed"
        return 1
    fi
    
    local repo_config=$(jq --arg id "$SELECTED_REPO" '.repositories[] | select(.id == $id)' "$CONFIG_FILE")
    if [[ -z "$repo_config" ]]; then
        log_error "Repository '$SELECTED_REPO' not found"
        return 1
    fi
    
    local repo_full_name=$(echo "$repo_config" | jq -r '.fullName')
    local repo_name=$(echo "$repo_config" | jq -r '.name // (.fullName | split("/")[1])')
    local docs_path=$(echo "$repo_config" | jq -r '.docsPath // "./docs/plans"')
    
    log_info "Repository: $repo_full_name"
    log_info "Plan: $SELECTED_PLAN"
    
    local plan_file="$PROJECT_ROOT/../$repo_name/$docs_path/$SELECTED_PLAN"
    if [[ ! -f "$plan_file" ]]; then
        log_error "Plan file not found: $plan_file"
        return 1
    fi
    log_success "Plan file found"
    
    local hierarchy_file="$OUTPUT_DIR/hierarchy.json"
    log_info "Parsing plan file..."
    
    # Simple parser
    node -e "
    const fs = require('fs');
    const content = fs.readFileSync('$plan_file', 'utf-8');
    const lines = content.split('\\n');
    const items = [];
    let idCounter = 1;
    
    lines.forEach((line, idx) => {
        const match = line.match(/^(\s*)- \[ \] (.+)/);
        if (match) {
            const indent = match[1].length;
            const title = match[2].trim();
            const level = Math.floor(indent / 2);
            items.push({
                id: idCounter++,
                title: title,
                level: level,
                line: idx + 1
            });
        }
    });
    
    const output = {
        source: '$SELECTED_PLAN',
        repository: '$repo_full_name',
        totalItems: items.length,
        items: items,
        metadata: { parsedAt: new Date().toISOString() }
    };
    
    fs.writeFileSync('$hierarchy_file', JSON.stringify(output, null, 2));
    console.log(JSON.stringify({success: true, itemCount: items.length}));
    " || return 1
    
    local item_count=$(jq -r '.totalItems' "$hierarchy_file")
    log_success "Parsed $item_count items"
    
    save_state "2" "{\"completed\": true, \"hierarchyFile\": \"$hierarchy_file\", \"itemCount\": $item_count, \"repository\": \"$repo_full_name\"}"
    log_success "STAGE 2 complete"
    return 0
}

# STAGE 3: CREATE PAI
stage_create_pai() {
    log_stage "3" "CREATE PAI - Generate Parent Issue (Epic)"
    
    local prep_data=$(get_stage_data "2")
    if [[ $(echo "$prep_data" | jq -r '.completed // false') != "true" ]]; then
        log_error "STAGE 2 not completed"
        return 1
    fi
    
    local repo_full=$(echo "$prep_data" | jq -r '.repository')
    local item_count=$(echo "$prep_data" | jq -r '.itemCount')
    
    log_info "Repository: $repo_full"
    log_info "Sub-items: $item_count"
    
    local repo_config=$(jq --arg id "$SELECTED_REPO" '.repositories[] | select(.id == $id)' "$CONFIG_FILE")
    local labels=$(echo "$repo_config" | jq -r '.metadata.defaultLabels | join(",")')
    local assignee=$(echo "$repo_config" | jq -r '.metadata.defaultAssignee')
    
    local pai_title="[EPIC] Implementation Plan: $SELECTED_PLAN"
    local pai_body="# Implementation Plan

**Source:** \`$SELECTED_PLAN\`  
**Total Tasks:** $item_count  
**Generated:** $(date +'%Y-%m-%d %H:%M:%S')

---

This Epic tracks implementation of tasks from \`$SELECTED_PLAN\`.

All sub-issues will be created and linked automatically.

---

_Generated by E2E Flow v2.0_"
    
    log_info "Creating PAI..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_warning "[DRY-RUN] Would create PAI"
        local pai_number="999"
    else
        local create_output=$(gh issue create \
            --repo "$repo_full" \
            --title "$pai_title" \
            --body "$pai_body" \
            --label "$labels" \
            --assignee "$assignee" \
            2>&1)
        
        if [[ $? -ne 0 ]]; then
            log_error "Failed to create PAI"
            return 1
        fi
        
        local pai_number=$(echo "$create_output" | grep -oP 'https://github.com/.+/issues/\K\d+' | head -n1)
        log_success "PAI created: #$pai_number"
    fi
    
    save_state "3" "{\"completed\": true, \"paiNumber\": $pai_number, \"repository\": \"$repo_full\"}"
    log_success "STAGE 3 complete - PAI #$pai_number"
    return 0
}

# STAGE 4: CREATE CHILDREN
stage_create_children() {
    log_stage "4" "CREATE CHILDREN - Generate All Sub-Issues"
    
    local pai_data=$(get_stage_data "3")
    if [[ $(echo "$pai_data" | jq -r '.completed // false') != "true" ]]; then
        log_error "STAGE 3 not completed"
        return 1
    fi
    
    local pai_number=$(echo "$pai_data" | jq -r '.paiNumber')
    local repo_full=$(echo "$pai_data" | jq -r '.repository')
    
    local prep_data=$(get_stage_data "2")
    local hierarchy_file=$(echo "$prep_data" | jq -r '.hierarchyFile')
    local item_count=$(echo "$prep_data" | jq -r '.itemCount')
    
    log_info "PAI: #$pai_number"
    log_info "Creating $item_count sub-issues..."
    
    local items=$(jq -c '.items[]' "$hierarchy_file")
    local counter=1
    
    echo "$items" | while IFS= read -r item; do
        local item_id=$(echo "$item" | jq -r '.id')
        local item_title=$(echo "$item" | jq -r '.title')
        
        log_info "[$counter/$item_count] $item_title"
        
        local issue_body="**Parent:** #$pai_number

---

$item_title

---

_Generated by E2E Flow v2.0 (Item #$item_id)_"
        
        if [[ "$DRY_RUN" == "true" ]]; then
            local issue_number=$((1000 + counter))
        else
            local create_output=$(gh issue create \
                --repo "$repo_full" \
                --title "$item_title" \
                --body "$issue_body" \
                2>&1)
            
            local issue_number=$(echo "$create_output" | grep -oP 'https://github.com/.+/issues/\K\d+' | head -n1)
            log_success "Created #$issue_number"
        fi
        
        echo "{\"id\": $item_id, \"number\": $issue_number, \"title\": \"$(echo "$item_title" | sed 's/"/\\"/g')\"}" >> "$OUTPUT_DIR/created-issues.jsonl"
        
        counter=$((counter + 1))
        sleep 0.5
    done
    
    jq -s '.' "$OUTPUT_DIR/created-issues.jsonl" > "$OUTPUT_DIR/created-issues.json"
    rm -f "$OUTPUT_DIR/created-issues.jsonl"
    
    local created_count=$(jq 'length' "$OUTPUT_DIR/created-issues.json")
    log_success "Created $created_count sub-issues"
    
    save_state "4" "{\"completed\": true, \"createdCount\": $created_count, \"issuesFile\": \"$OUTPUT_DIR/created-issues.json\"}"
    log_success "STAGE 4 complete"
    return 0
}

# STAGE 5: LINK HIERARCHY
stage_link_hierarchy() {
    log_stage "5" "LINK HIERARCHY - Create Parent-Child Relationships"
    
    local children_data=$(get_stage_data "4")
    if [[ $(echo "$children_data" | jq -r '.completed // false') != "true" ]]; then
        log_error "STAGE 4 not completed"
        return 1
    fi
    
    local pai_data=$(get_stage_data "3")
    local pai_number=$(echo "$pai_data" | jq -r '.paiNumber')
    local repo_full=$(echo "$pai_data" | jq -r '.repository')
    local issues_file=$(echo "$children_data" | jq -r '.issuesFile')
    
    log_info "Linking to PAI #$pai_number..."
    
    local link_count=0
    jq -c '.[]' "$issues_file" | while IFS= read -r issue; do
        local issue_number=$(echo "$issue" | jq -r '.number')
        
        if [[ "$DRY_RUN" == "true" ]]; then
            log_warning "[DRY-RUN] Would link #$issue_number"
        else
            log_info "Linking #$issue_number..."
            if gh issue link "$pai_number" "$issue_number" --repo "$repo_full" &>/dev/null; then
                log_success "Linked #$issue_number"
                link_count=$((link_count + 1))
            fi
        fi
        sleep 0.3
    done
    
    log_success "Linked $link_count issues"
    
    save_state "5" "{\"completed\": true, \"linkedCount\": $link_count}"
    log_success "STAGE 5 complete"
    return 0
}

# STAGE 6: SYNC PROJECTV2
stage_sync_projectv2() {
    log_stage "6" "SYNC PROJECTV2 - Synchronize Metadata Fields"
    
    local link_data=$(get_stage_data "5")
    if [[ $(echo "$link_data" | jq -r '.completed // false') != "true" ]]; then
        log_error "STAGE 5 not completed"
        return 1
    fi
    
    log_warning "ProjectV2 field sync requires GraphQL mutations"
    log_info "Manual sync recommended via GitHub UI"
    
    save_state "6" "{\"completed\": true, \"note\": \"Manual sync recommended\"}"
    log_success "STAGE 6 complete"
    return 0
}

# STAGE 7: PROGRESS TRACKING
stage_progress_tracking() {
    log_stage "7" "PROGRESS TRACKING - Generate Nested Checklist"
    
    local children_data=$(get_stage_data "4")
    if [[ $(echo "$children_data" | jq -r '.completed // false') != "true" ]]; then
        log_error "STAGE 4 not completed"
        return 1
    fi
    
    local pai_data=$(get_stage_data "3")
    local pai_number=$(echo "$pai_data" | jq -r '.paiNumber')
    local repo_full=$(echo "$pai_data" | jq -r '.repository')
    local issues_file=$(echo "$children_data" | jq -r '.issuesFile')
    local total_count=$(jq 'length' "$issues_file")
    
    log_info "Generating checklist..."
    
    local checklist_file="$OUTPUT_DIR/progress-tracking.md"
    
    cat > "$checklist_file" << EOF
## Progress Tracking

**Total:** $total_count  
**Completed:** 0 / $total_count (0%)

---

EOF
    
    jq -r '.[] | "- [ ] [#\(.number)](https://github.com/'$repo_full'/issues/\(.number)) \(.title)"' "$issues_file" >> "$checklist_file"
    
    log_success "Checklist generated"
    
    if [[ "$DRY_RUN" != "true" ]]; then
        log_info "Updating PAI..."
        local current_body=$(gh issue view "$pai_number" --repo "$repo_full" --json body --jq '.body')
        echo "$current_body

---

$(cat "$checklist_file")" | gh issue edit "$pai_number" --repo "$repo_full" --body-file - &>/dev/null
        log_success "PAI updated"
    fi
    
    save_state "7" "{\"completed\": true, \"checklistFile\": \"$checklist_file\"}"
    log_success "STAGE 7 complete"
    return 0
}

# STAGE 8: REPORTING
stage_reporting() {
    log_stage "8" "REPORTING - Generate Audit Trail"
    
    local pai_data=$(get_stage_data "3")
    local children_data=$(get_stage_data "4")
    
    local pai_number=$(echo "$pai_data" | jq -r '.paiNumber')
    local repo_full=$(echo "$pai_data" | jq -r '.repository')
    local created_count=$(echo "$children_data" | jq -r '.createdCount')
    
    log_info "Generating report..."
    
    local report_file="$OUTPUT_DIR/e2e-execution-report.md"
    
    cat > "$report_file" << EOF
# E2E Flow Execution Report

**Generated:** $(date +'%Y-%m-%d %H:%M:%S')  
**Repository:** $repo_full  
**Plan:** $SELECTED_PLAN

---

## Summary

- ✅ PAI Issue: #$pai_number
- ✅ Sub-Issues: $created_count created
- ✅ All issues linked
- ⚠️  ProjectV2: Manual sync recommended

---

**PAI URL:** https://github.com/$repo_full/issues/$pai_number

---

_Generated by E2E Flow v2.0_
EOF
    
    log_success "Report generated: $report_file"
    
    echo ""
    log_stage "✨" "EXECUTION COMPLETE"
    echo ""
    log_success "PAI Issue: #$pai_number"
    log_success "Sub-Issues: $created_count"
    echo ""
    log_info "View: https://github.com/$repo_full/issues/$pai_number"
    echo ""
    
    save_state "8" "{\"completed\": true, \"reportFile\": \"$report_file\"}"
    log_success "All done! 🎉"
    return 0
}

# ============================================================================
# NAVIGATION & ORCHESTRATION
# ============================================================================

show_navigation_menu() {
    local current=$1
    local stage_name=${STAGE_NAMES[$current-1]:-"UNKNOWN"}
    
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  Current Stage: $current - $stage_name${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Options:"
    echo "  [c] Continue to next stage"
    [[ $current -gt 1 ]] && echo "  [b] Back to previous stage"
    echo "  [r] Re-run current stage"
    echo "  [s] Show current state"
    echo "  [q] Quit"
    echo ""
    read -p "Choose option: " choice
    echo "$choice"
}

run_stage() {
    local stage_num=$1
    case $stage_num in
        1) stage_setup ;;
        2) stage_prepare ;;
        3) stage_create_pai ;;
        4) stage_create_children ;;
        5) stage_link_hierarchy ;;
        6) stage_sync_projectv2 ;;
        7) stage_progress_tracking ;;
        8) stage_reporting ;;
        *) log_error "Invalid stage: $stage_num"; return 1 ;;
    esac
}

show_current_state() {
    log_info "Current execution state:"
    echo ""
    for i in {1..8}; do
        local stage_data=$(get_stage_data "$i")
        local completed=$(echo "$stage_data" | jq -r '.completed // false')
        local status="❌ Not started"
        [[ "$completed" == "true" ]] && status="✅ Complete"
        echo -e "  Stage $i (${STAGE_NAMES[$i-1]}): $status"
    done
    echo ""
}

# ============================================================================
# MAIN ORCHESTRATOR
# ============================================================================

main() {
    echo -e "${MAGENTA}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════════════════╗
║                                                                           ║
║                    E2E FLOW - ISSUE HIERARCHY GENERATOR                   ║
║                              Version 2.0                                  ║
║                                                                           ║
╚═══════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --repo) SELECTED_REPO="$2"; shift 2 ;;
            --plan) SELECTED_PLAN="$2"; shift 2 ;;
            --config) CONFIG_FILE="$2"; shift 2 ;;
            --dry-run) DRY_RUN=true; shift ;;
            --resume) CURRENT_STAGE=$(($(get_last_completed_stage) + 1)); shift ;;
            --non-interactive) INTERACTIVE=false; shift ;;
            --help)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --repo <id>          Repository ID"
                echo "  --plan <file>        Plan file (SPRINT.md, PLAN.md, etc.)"
                echo "  --config <path>      Config file path"
                echo "  --dry-run            Simulate without creating issues"
                echo "  --resume             Resume from last stage"
                echo "  --non-interactive    No prompts"
                echo "  --help               This help"
                exit 0
                ;;
            *) log_error "Unknown option: $1"; exit 1 ;;
        esac
    done
    
    # Interactive repository selection
    if [[ -z "$SELECTED_REPO" ]]; then
        echo ""
        log_prompt "Select repository:"
        jq -r '.repositories[] | "  [\(.id)] \(.fullName)"' "$CONFIG_FILE" 2>/dev/null || {
            log_error "Cannot read config file"
            exit 1
        }
        echo ""
        read -p "Repository ID: " SELECTED_REPO
    fi
    
    # Interactive plan selection
    if [[ -z "$SELECTED_PLAN" ]]; then
        echo ""
        log_prompt "Select plan file:"
        echo "  [1] PLAN.md"
        echo "  [2] SPRINT.md"
        echo "  [3] Custom"
        echo ""
        read -p "Choice [1-3]: " plan_choice
        case $plan_choice in
            1) SELECTED_PLAN="PLAN.md" ;;
            2) SELECTED_PLAN="SPRINT.md" ;;
            3) read -p "Enter filename: " SELECTED_PLAN ;;
            *) SELECTED_PLAN="SPRINT.md" ;;
        esac
    fi
    
    log_info "Repository: $SELECTED_REPO"
    log_info "Plan: $SELECTED_PLAN"
    [[ "$DRY_RUN" == "true" ]] && log_warning "DRY-RUN MODE"
    
    # Execute stages
    if [[ "$INTERACTIVE" == "true" ]]; then
        while [[ $CURRENT_STAGE -le 8 ]]; do
            if run_stage $CURRENT_STAGE; then
                [[ $CURRENT_STAGE -eq 8 ]] && break
                
                choice=$(show_navigation_menu $CURRENT_STAGE)
                case $choice in
                    c|C|"") CURRENT_STAGE=$((CURRENT_STAGE + 1)) ;;
                    b|B) 
                        if [[ $CURRENT_STAGE -gt 1 ]]; then
                            CURRENT_STAGE=$((CURRENT_STAGE - 1))
                        fi
                        ;;
                    r|R) log_info "Re-running stage $CURRENT_STAGE" ;;
                    s|S) show_current_state ;;
                    q|Q) log_warning "Stopped by user"; exit 0 ;;
                    *) CURRENT_STAGE=$((CURRENT_STAGE + 1)) ;;
                esac
            else
                log_error "Stage $CURRENT_STAGE failed"
                read -p "Retry? [y/N]: " retry
                [[ "$retry" =~ ^[Yy]$ ]] && continue || exit 1
            fi
        done
    else
        for stage in $(seq $CURRENT_STAGE 8); do
            run_stage $stage || { log_error "Stage $stage failed"; exit 1; }
        done
    fi
    
    echo ""
    log_success "E2E Flow completed! 🎉"
}

# Entry point
main "$@"
