#!/bin/bash
# E2E Flow v2.0 - Complete Implementation
set -euo pipefail

# Hardening: ensure we use bash builtins even if the environment exports a `read` alias/function.
unalias read 2>/dev/null || true
unset -f read 2>/dev/null || true

# Config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="${CONFIG_FILE:-$PROJECT_ROOT/config/e2e-config.json}"
OUTPUT_DIR="${OUTPUT_DIR:-$PROJECT_ROOT/tmp/e2e-execution}"
# Default state file; will be updated once repository is selected to be repo-specific.
STATE_FILE="$OUTPUT_DIR/execution-state.json"
AUDIT_LOG_FILE="$OUTPUT_DIR/audit-log.jsonl"

# Defaults
DRY_RUN=false
SELECTED_REPO=""        # Back-compat: accepts repo id OR owner/name
SELECTED_REPO_ID=""
SELECTED_REPO_FULL=""
SELECTED_PLAN=""
SELECTED_PLAN_FILE=""
PARENT_ISSUE_NUMBER=""
CHILDREN_FILE=""
INCLUDE_PARENT_IN_BODY=true
ENABLE_PROJECT_SYNC=false
PROJECT_SPEC=""         # format: ownerOrOrg/number (e.g. Axodus/23)
PROJECT_ID=""
PROJECT_OWNER=""
PROJECT_NUMBER=""
METADATA_FILE=""
METADATA_REQUIRED=true
METADATA_JSON="{}"
ENGINE_OUTPUT_FILE_OVERRIDE=""
ENFORCE_LABEL_ALLOWLIST=false
TIMING_AFTER_PAI=0
TIMING_AFTER_CHILDREN=0
TIMING_AFTER_LINK=0
ENFORCE_PAI_CONTENT_MATCH=false
PLAN_HASH=""
CURRENT_STAGE=1
INTERACTIVE=true
RUN_SINGLE_STAGE=false
STAGE_NAMES=("SETUP" "PREPARE" "CREATE_PAI" "CREATE_CHILDREN" "LINK_HIERARCHY" "SYNC_PROJECTV2" "PROGRESS_TRACKING" "REPORTING")

# Sub-issues linking behavior
REPLACE_PARENT=false

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
MAGENTA='\033[0;35m'; CYAN='\033[0;36m'; NC='\033[0m'

# Logging
log_stage() { echo ""; echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; echo -e "${MAGENTA}  STAGE $1: $2${NC}"; echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; echo ""; }
log_info() { echo -e "${BLUE}ℹ${NC} $1"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1" >&2; }
log_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
log_prompt() { echo -e "${CYAN}❯${NC} $1"; }

# Strip inline metadata shortcodes (e.g. [priority:high], [estimate:2h]) from titles.
# Note: we intentionally only strip bracket tags containing ':' to avoid removing
# human prefixes like "[Backend]".
strip_shortcodes() {
    local input="$1"
    local out
    out=$(printf '%s' "$input" | sed -E 's/\[[A-Za-z][A-Za-z0-9_-]*:[^]]+\]//g' | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//')
    printf '%s' "$out"
}

# Resolve the sync-helper config that corresponds to a given repo.
# This makes sync-helper the single source of truth for outputs paths and parsing behavior.
resolve_sync_config_for_repo() {
    local repo_full="$1"
    local cfg
    for cfg in "$PROJECT_ROOT/sync-helper/configs"/*.json; do
        [[ -f "$cfg" ]] || continue
        local r
        r=$(jq -r '.repo // empty' "$cfg" 2>/dev/null || true)
        if [[ -n "$r" && "$r" == "$repo_full" ]]; then
            printf '%s' "$cfg"
            return 0
        fi
    done
    return 1
}

prompt_for_repo_selection() {
    local i=1
    local repos=()
    
    # Look in sync-helper configs
    for cfg in "$PROJECT_ROOT/sync-helper/configs"/*.json; do
        [[ -f "$cfg" ]] || continue
        local r
        r=$(jq -r '.repo // empty' "$cfg" 2>/dev/null || true)
        local id
        id=$(basename "$cfg" .json)
        
        if [[ -n "$r" ]]; then
            repos+=("$r")
            printf "  %d) %-30s (%s)\n" "$i" "$id" "$r"
            i=$((i + 1))
        fi
    done
    
    # Fallback/legacy check
    if [[ ${#repos[@]} -eq 0 ]]; then
         local raw
         raw=$(jq -r '.repositories[]? | "\(.id)|\(.fullName)"' "$CONFIG_FILE" 2>/dev/null || true)
         if [[ -n "$raw" ]]; then
            while IFS='|' read -r k r; do
                if [[ -n "$k" ]]; then
                     repos+=("$r")
                     printf "  %d) %-30s (%s)\n" "$i" "$k" "$r"
                     i=$((i + 1))
                fi
            done <<< "$raw"
         fi
    fi

    if [[ ${#repos[@]} -eq 0 ]]; then
        log_warning "No repositories configured."
        builtin read -r -p "Enter owner/name manually: " SELECTED_REPO
        return 0
    fi
    
    echo
    builtin read -r -p "Select repository (1-${#repos[@]}) or type owner/name: " selection
    
    if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le ${#repos[@]} ]; then
        local idx=$((selection - 1))
        SELECTED_REPO="${repos[$idx]}"
    else
        SELECTED_REPO="$selection"
    fi
}

merge_managed_section() {
    local existing_body="$1"
    local begin_marker="$2"
    local end_marker="$3"
    local new_section="$4"

    # Pass large payloads via stdin to avoid OS argv size limits.
        jq -n --arg existing "$existing_body" --arg replacement "$new_section" '{existing:$existing,replacement:$replacement}' \
                | node -e '
const fs = require("fs");

const begin = process.argv[1];
const end = process.argv[2];
const payload = JSON.parse(fs.readFileSync(0, "utf8") || "{}");
const existing = String(payload.existing || "");
const replacement = String(payload.replacement || "");

function ensureMarkers(text) {
    let out = String(text || "");
    if (!out.includes(begin)) out += `\n\n${begin}\n${end}\n`;
    if (!out.includes(end)) out += `\n${end}\n`;
    return out;
}

const withMarkers = ensureMarkers(existing);
const re = new RegExp(`${begin}[\\s\\S]*?${end}`, "m");
const next = withMarkers.replace(re, `${begin}\n${replacement}\n${end}`);
process.stdout.write(next);
' "$begin_marker" "$end_marker"
}

# Audit logging (JSONL)
audit_log() {
    local action="$1"
    local payload_json="${2:-{}}"
    mkdir -p "$OUTPUT_DIR"

    # Safer: only attempt to treat payload as JSON when jq accepts it; otherwise encode it as a string.
    local ts
    ts=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
    local payload
    if printf '%s' "$payload_json" | jq -e . >/dev/null 2>&1; then
        payload=$(printf '%s' "$payload_json")
    else
        # Wrap arbitrary text as JSON string
        payload=$(printf '%s' "$payload_json" | jq -Rs '.')
    fi

    printf '%s\n' "{\"ts\":\"$ts\",\"action\":\"$action\",\"stage\":${CURRENT_STAGE:-0},\"repo\":\"${SELECTED_REPO_FULL:-}\",\"payload\":$payload}" >> "$AUDIT_LOG_FILE" 2>/dev/null || true
}

# Check for existing issue by title and marker
check_existing_issue() {
    local repo_full="$1"
    local title="$2"
    local marker="${3:-Generated by E2E Flow v2.0}"

    # Strategy 1: GraphQL with explicit body field, DESC order + tail = oldest match
    local query="query {
      repository(owner: \"$(echo "$repo_full" | cut -d'/' -f1)\", name: \"$(echo "$repo_full" | cut -d'/' -f2)\") {
        issues(first: 100, states: OPEN, orderBy: {field: CREATED_AT, direction: DESC}) {
          nodes {
            number
            title
            body
          }
        }
      }
    }"

    local result
    result=$(gh api graphql -f query="$query" 2>/dev/null || echo '{}')

    local matched
    matched=$(echo "$result" | jq --arg title "$title" --arg marker "$marker" -r '.data.repository.issues.nodes[]? | select(.title == $title and ((.body // "") | contains($marker))) | .number' 2>/dev/null | tail -n1)

    if [[ -n "$matched" && "$matched" != "null" && "$matched" != "" ]]; then
        echo "$matched"
        return 0
    fi

    # Strategy 2: Search by marker (may have index delay)
    local existing
    existing=$(gh search issues -R "$repo_full" --match body --json number,title,state "$marker" --limit 100 2>/dev/null || echo '[]')

    matched=$(echo "$existing" | jq --arg title "$title" -r '.[] | select(.title == $title and .state == "OPEN") | .number' 2>/dev/null | head -n1)

    if [[ -n "$matched" && "$matched" != "null" && "$matched" != "" ]]; then
        echo "$matched"
        return 0
    fi

    # Not found
    return 1
}

parse_repo_input() {
    local input="$1"
    if [[ "$input" == *"/"* ]]; then
        SELECTED_REPO_FULL="$input"
        SELECTED_REPO_ID=""
    else
        SELECTED_REPO_ID="$input"
        SELECTED_REPO_FULL=""
    fi
}

resolve_repo_full() {
    if [[ -n "$SELECTED_REPO_FULL" ]]; then
        return 0
    fi

    if [[ -n "$SELECTED_REPO_ID" ]]; then
        # First try sync-helper config name (preferred; reflects newly added repos immediately)
        local cfg_path
        cfg_path="$PROJECT_ROOT/sync-helper/configs/${SELECTED_REPO_ID}.json"
        if [[ -f "$cfg_path" ]]; then
            local r
            r=$(jq -r '.repo // empty' "$cfg_path" 2>/dev/null || true)
            if [[ -n "$r" && "$r" != "null" ]]; then
                SELECTED_REPO_FULL="$r"
                return 0
            fi
        fi

        local repo_config
        repo_config=$(jq --arg id "$SELECTED_REPO_ID" '.repositories[] | select(.id == $id)' "$CONFIG_FILE" 2>/dev/null || true)
        [[ -n "$repo_config" ]] && SELECTED_REPO_FULL="$(echo "$repo_config" | jq -r '.fullName')"
    fi

    if [[ -z "$SELECTED_REPO_FULL" ]]; then
        # Auto-detect from current directory (gh will infer repo from git remote)
        SELECTED_REPO_FULL=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null || true)
    fi

    [[ -z "$SELECTED_REPO_FULL" ]] && {
        log_error "Unable to resolve target repo. Provide --repo owner/name or run inside a git repo with a GitHub remote."
        return 1
    }

    return 0
}

resolve_metadata_file() {
    if [[ -n "$METADATA_FILE" ]]; then
        [[ -f "$METADATA_FILE" ]] && return 0
        log_error "Metadata file not found: $METADATA_FILE"
        return 1
    fi

    local candidate_repo_dir="${SELECTED_REPO_FULL//\//-}"
    local candidates=(
        "$PROJECT_ROOT/tmp/metadata.json"
        "$PROJECT_ROOT/tmp/${candidate_repo_dir}/metadata.json"
        "$PROJECT_ROOT/tmp/${SELECTED_REPO_ID}/metadata.json"
    )

    for c in "${candidates[@]}"; do
        if [[ -n "$c" && -f "$c" ]]; then
            METADATA_FILE="$c"
            return 0
        fi
    done

    if [[ "$METADATA_REQUIRED" == "true" ]]; then
        log_error "Metadata file not found. Provide --metadata-file or generate via sync-helper."
        return 1
    fi

    log_warning "Metadata file not found. Continuing without metadata validations."
    return 0
}

load_metadata() {
    if [[ -z "$METADATA_FILE" ]]; then
        METADATA_JSON="{}"
        return 0
    fi

    METADATA_JSON=$(jq -c '.' "$METADATA_FILE" 2>/dev/null || echo '{}')

    ENFORCE_LABEL_ALLOWLIST=$(echo "$METADATA_JSON" | jq -r '.validation.enforceLabelAllowlist // false')
    TIMING_AFTER_PAI=$(echo "$METADATA_JSON" | jq -r '.timing.afterPaiSeconds // 0')
    TIMING_AFTER_CHILDREN=$(echo "$METADATA_JSON" | jq -r '.timing.afterChildrenSeconds // 0')
    TIMING_AFTER_LINK=$(echo "$METADATA_JSON" | jq -r '.timing.afterLinkSeconds // 0')
    ENFORCE_PAI_CONTENT_MATCH=$(echo "$METADATA_JSON" | jq -r '.validation.enforcePaiContentMatch // false')

    local allowlist_count
    allowlist_count=$(echo "$METADATA_JSON" | jq -r '.labels.allowed | length' 2>/dev/null || echo 0)
    if [[ "$ENFORCE_LABEL_ALLOWLIST" == "true" && "$allowlist_count" -eq 0 ]]; then
        log_error "Label allowlist enforcement enabled but labels.allowed is empty in metadata."
        return 1
    fi
    return 0
}

compute_plan_hash() {
    local plan_file="$1"
    PLAN_HASH=$(node -e "const fs=require('fs');const crypto=require('crypto');const data=fs.readFileSync('${plan_file}');console.log(crypto.createHash('sha1').update(data).digest('hex'));" 2>/dev/null || echo "")
    if [[ -z "$PLAN_HASH" ]]; then
        log_error "Failed to compute plan hash"
        return 1
    fi
    return 0
}

validate_labels_allowlist() {
        local metadata_file="$1"
    if [[ "$ENFORCE_LABEL_ALLOWLIST" != "true" ]]; then
        return 0
    fi

        node -e "
        const fs = require('fs');
        const metadata = JSON.parse(fs.readFileSync('$metadata_file', 'utf8'));
        const allowed = new Set((metadata.labels && metadata.labels.allowed || []).map(l => String(l).toLowerCase()));
        const invalid = new Set();
        const items = [...(metadata.tasks || []), ...(metadata.subtasks || [])];
        for (const item of items) {
            const labels = Array.isArray(item.labels) ? item.labels : [];
            for (const label of labels) {
                const l = String(label).trim();
                if (!l) continue;
                if (!allowed.has(l.toLowerCase())) invalid.add(l);
            }
        }
        if (invalid.size) {
            console.error('Invalid labels found:', Array.from(invalid).join(', '));
            process.exit(2);
        }
        "
    if [[ $? -ne 0 ]]; then
        log_error "Label allowlist validation failed."
        return 1
    fi

    log_success "Label allowlist validation passed"
    return 0
}

parse_project_spec() {
    local spec="$1"
    PROJECT_OWNER="${spec%/*}"
    PROJECT_NUMBER="${spec#*/}"
    [[ -z "$PROJECT_OWNER" || -z "$PROJECT_NUMBER" || "$PROJECT_NUMBER" == "$spec" ]] && return 1
    [[ ! "$PROJECT_NUMBER" =~ ^[0-9]+$ ]] && return 1
    return 0
}

resolve_project_id() {
    # If explicitly set, use it.
    if [[ -n "$PROJECT_ID" ]]; then
        echo "$PROJECT_ID"
        return 0
    fi

    # CLI spec: owner/number
    if [[ -n "$PROJECT_SPEC" ]]; then
        parse_project_spec "$PROJECT_SPEC" || {
            log_error "Invalid --project value. Expected <ownerOrOrg>/<number> (e.g. Axodus/23)."
            return 1
        }

        # Try org project first
        local id
        id=$(gh api graphql \
            -f query='query($login:String!,$number:Int!){organization(login:$login){projectV2(number:$number){id}}}' \
            -f login="$PROJECT_OWNER" -F number="$PROJECT_NUMBER" --jq '.data.organization.projectV2.id' 2>/dev/null || true)

        # If ID is missing or looks like an error JSON (starts with {), try user project
        if [[ -z "$id" || "$id" == "null" || "$id" == \{* ]]; then
            id=$(gh api graphql \
                -f query='query($login:String!,$number:Int!){user(login:$login){projectV2(number:$number){id}}}' \
                -f login="$PROJECT_OWNER" -F number="$PROJECT_NUMBER" --jq '.data.user.projectV2.id' 2>/dev/null || true)
        fi

        if [[ -z "$id" || "$id" == "null" || "$id" == \{* ]]; then
             log_error "Failed to resolve ProjectV2 id for $PROJECT_SPEC (Owner '$PROJECT_OWNER', Number '$PROJECT_NUMBER')"
             return 1
        fi
        PROJECT_ID="$id"
        echo "$PROJECT_ID"
        return 0
    fi

    # Config fallback (only if a repo id was selected)
    if [[ -n "$SELECTED_REPO_ID" ]]; then
        local repo_config
        repo_config=$(jq --arg id "$SELECTED_REPO_ID" '.repositories[] | select(.id == $id)' "$CONFIG_FILE" 2>/dev/null || true)
        local cfg_id
        cfg_id=$(echo "$repo_config" | jq -r '.project.id // empty' 2>/dev/null || true)
        if [[ -n "$cfg_id" ]]; then
            PROJECT_ID="$cfg_id"
            echo "$PROJECT_ID"
            return 0
        fi
    fi

    log_error "ProjectV2 not configured. Provide --project <ownerOrOrg>/<number> or --project-id <nodeId>."
    return 1
}

# State management
save_state() {
    local stage=$1
    local data_str=$2
    mkdir -p "$OUTPUT_DIR"
    
    # Escape JSON properly
    local escaped_data=$(echo "$data_str" | jq -c '.')
    
    if [[ -f "$STATE_FILE" ]]; then
        jq --arg stage "$stage" --argjson data "$escaped_data" \
           '.stages[$stage] = $data | .lastStage = ($stage | tonumber) | .timestamp = now' \
           "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
    else
        jq -n --arg stage "$stage" --argjson data "$escaped_data" \
           '{stages: {($stage): $data}, lastStage: ($stage | tonumber), timestamp: now, version: "2.0"}' \
           > "$STATE_FILE"
    fi
}

get_stage_data() {
    local stage=$1
    [[ -f "$STATE_FILE" ]] && jq -r ".stages[\"$stage\"] // {}" "$STATE_FILE" 2>/dev/null || echo "{}"
}

get_last_completed_stage() {
    [[ -f "$STATE_FILE" ]] && jq -r '.lastStage // 0' "$STATE_FILE" || echo "0"
}

# STAGE 1
stage_setup() {
    log_stage "1" "SETUP - Configuration & Environment Validation"
    mkdir -p "$OUTPUT_DIR"
    
    [[ ! -f "$CONFIG_FILE" ]] && { log_error "Config not found: $CONFIG_FILE"; return 1; }
    log_success "Config found"
    
    jq empty "$CONFIG_FILE" 2>/dev/null || { log_error "Invalid JSON"; return 1; }
    log_success "Valid JSON"
    
    command -v gh &> /dev/null || { log_error "gh CLI not found"; return 1; }
    log_success "gh CLI found"
    
    gh auth status &>/dev/null || { log_error "Not authenticated"; return 1; }
    log_success "Authenticated"
    
    command -v jq &> /dev/null || { log_error "jq not found"; return 1; }
    log_success "jq found"
    
    local org
    # Use repo owner if known, else fall back to config default
    if [[ -n "${SELECTED_REPO_FULL:-}" ]]; then
        org="${SELECTED_REPO_FULL%%/*}"
    else
        org=$(jq -r '.github.organization // empty' "$CONFIG_FILE" 2>/dev/null || true)
    fi
    [[ -z "$org" ]] && org="(auto)"
    log_info "Organization: $org"
    
    save_state "1" '{"completed": true, "org": "'$org'"}'
    log_success "STAGE 1 complete"
    return 0
}

# STAGE 2
stage_prepare() {
    log_stage "2" "PREPARE - Parse Plans and Build Hierarchy"
    
    local setup_data=$(get_stage_data "1")
    [[ $(echo "$setup_data" | jq -r '.completed // false') != "true" ]] && { log_error "STAGE 1 not completed"; return 1; }
    
    resolve_repo_full || return 1

    local repo_full_name="$SELECTED_REPO_FULL"
    local repo_name="${repo_full_name#*/}"
    local docs_path=""
    local repo_config=""

    if [[ -n "$SELECTED_REPO_ID" ]]; then
        repo_config=$(jq --arg id "$SELECTED_REPO_ID" '.repositories[] | select(.id == $id)' "$CONFIG_FILE" 2>/dev/null || true)
        docs_path=$(echo "$repo_config" | jq -r '.docsPath // "./docs/plans"' 2>/dev/null || true)
    fi
    
    log_info "Repository: $repo_full_name"
    log_info "Plan: $SELECTED_PLAN"
    
    local plan_file=""
    if [[ -n "$SELECTED_PLAN_FILE" ]]; then
        plan_file="$SELECTED_PLAN_FILE"
    else
        local candidates=(
            "$PROJECT_ROOT/../$repo_name/$docs_path/$SELECTED_PLAN"
            "$PROJECT_ROOT/../$repo_name/plans/$SELECTED_PLAN"
            "$PROJECT_ROOT/../$repo_name/$SELECTED_PLAN"
        )
        for c in "${candidates[@]}"; do
            if [[ -f "$c" ]]; then
                plan_file="$c"
                break
            fi
        done
        
        if [[ -z "$plan_file" ]]; then
            log_error "Plan not found in candidates:"
            for c in "${candidates[@]}"; do log_error "  - $c"; done
            return 1
        fi
    fi

    [[ ! -f "$plan_file" ]] && { log_error "Plan not found: $plan_file"; return 1; }
    log_success "Plan found"

    # Use sync-helper artifacts as the single source of truth.
    local sync_config
    sync_config=$(resolve_sync_config_for_repo "$repo_full_name" 2>/dev/null || true)
    [[ -z "$sync_config" ]] && { log_error "No sync-helper config found for repo: $repo_full_name"; return 1; }

    log_info "Using sync-helper config: $sync_config"
    log_info "Running prepare (client/prepare.js)..."
    node "$PROJECT_ROOT/client/prepare.js" --config "$sync_config" --plans "$plan_file" >/dev/null

    local tasks_path
    local subtasks_path
    local engine_input_path
    local engine_output_path
    tasks_path=$(jq -r '.outputs.tasksPath // empty' "$sync_config" 2>/dev/null || true)
    subtasks_path=$(jq -r '.outputs.subtasksPath // empty' "$sync_config" 2>/dev/null || true)
    engine_input_path=$(jq -r '.outputs.engineInputPath // empty' "$sync_config" 2>/dev/null || true)
    engine_output_path=$(jq -r '.outputs.engineOutputPath // empty' "$sync_config" 2>/dev/null || true)
    [[ -z "$tasks_path" || -z "$engine_input_path" || -z "$engine_output_path" ]] && { log_error "Missing outputs paths in sync-helper config: $sync_config"; return 1; }

    local metadata_file
    metadata_file="$(dirname "$tasks_path")/metadata.json"
    [[ ! -f "$metadata_file" ]] && { log_error "metadata.json not found after prepare: $metadata_file"; return 1; }

    METADATA_FILE="$metadata_file"
    load_metadata || return 1
    compute_plan_hash "$plan_file" || return 1

    local item_count
    item_count=$(jq -r '((.tasks|length) + (.subtasks|length)) // 0' "$metadata_file" 2>/dev/null || echo 0)
    log_success "Prepared artifacts (items=$item_count)"

    validate_labels_allowlist "$metadata_file" || return 1

    save_state "2" '{"completed": true, "repository": "'$repo_full_name'", "planFile": "'$plan_file'", "planHash": "'$PLAN_HASH'", "syncConfig": "'$sync_config'", "metadataFile": "'$metadata_file'", "tasksPath": "'$tasks_path'", "subtasksPath": "'$subtasks_path'", "engineInputPath": "'$engine_input_path'", "engineOutputPath": "'$engine_output_path'", "itemCount": '$item_count'}'
    log_success "STAGE 2 complete"
    return 0
}

# STAGE 3
stage_create_pai() {
    log_stage "3" "CREATE PAI - Generate Parent Issue (Epic)"
    
    local prep_data=$(get_stage_data "2")
    [[ $(echo "$prep_data" | jq -r '.completed // false') != "true" ]] && { log_error "STAGE 2 not completed"; return 1; }
    
    local repo_full
    repo_full=$(echo "$prep_data" | jq -r '.repository')
    local item_count
    item_count=$(echo "$prep_data" | jq -r '.itemCount')
    local plan_file
    plan_file=$(echo "$prep_data" | jq -r '.planFile')
    local plan_hash
    plan_hash=$(echo "$prep_data" | jq -r '.planHash // empty')
    local metadata_file
    metadata_file=$(echo "$prep_data" | jq -r '.metadataFile // empty')
    
    log_info "Repository: $repo_full"
    log_info "Sub-items: $item_count"
    log_info "Plan file: $plan_file"
    
    local labels=""
    local assignee=""
    local default_priority=""
    local default_status=""
    if [[ -n "$SELECTED_REPO_ID" ]]; then
        local repo_config
        repo_config=$(jq --arg id "$SELECTED_REPO_ID" '.repositories[] | select(.id == $id)' "$CONFIG_FILE" 2>/dev/null || true)
        labels=$(echo "$repo_config" | jq -r '.metadata.defaultLabels | join(",")' 2>/dev/null || true)
        assignee=$(echo "$repo_config" | jq -r '.metadata.defaultAssignee // empty' 2>/dev/null || true)
        default_priority=$(echo "$repo_config" | jq -r '.metadata.defaultPriority // empty' 2>/dev/null || true)
        default_status=$(echo "$repo_config" | jq -r '.metadata.defaultStatus // empty' 2>/dev/null || true)
    fi

    [[ ! -f "$plan_file" ]] && { log_error "Plan file not found: $plan_file"; return 1; }
    [[ ! -f "$metadata_file" ]] && { log_error "Metadata file not found: $metadata_file"; return 1; }

    local pai_stable_id
    pai_stable_id="plan-${plan_hash}"

    local template_path
    template_path="$PROJECT_ROOT/templates/PLAN.md"
    [[ ! -f "$template_path" ]] && { log_error "Template not found: $template_path"; return 1; }

    local rendered
    rendered=$(PLAN_FILE="$plan_file" TEMPLATE_PATH="$template_path" REPO_FULL="$repo_full" PLAN_HASH="$plan_hash" PAI_STABLE_ID="$pai_stable_id" METADATA_FILE="$metadata_file" PAI_LABELS="$labels" PAI_PRIORITY="$default_priority" PAI_STATUS="$default_status" node - <<'NODE'
const fs = require('fs');
const path = require('path');

const planFile = process.env.PLAN_FILE;
const templatePath = process.env.TEMPLATE_PATH;
const repoFull = process.env.REPO_FULL;
const planHash = process.env.PLAN_HASH || '';
const stableId = process.env.PAI_STABLE_ID || '';
const labelsCsv = process.env.PAI_LABELS || '';
const defaultPriority = process.env.PAI_PRIORITY || 'HIGH';
const defaultStatus = process.env.PAI_STATUS || 'In Progress';
const metadataFile = process.env.METADATA_FILE;

const template = fs.readFileSync(templatePath, 'utf8');
const planContent = fs.readFileSync(planFile, 'utf8');
const metadata = JSON.parse(fs.readFileSync(metadataFile, 'utf8'));

const [owner, repo] = repoFull.split('/');

function firstHeading(md) {
  const lines = md.split(/\r?\n/);
  for (const line of lines) {
    const m = line.match(/^#{1,6}\s+(.+)$/);
    if (m) return m[1].trim();
  }
  return path.basename(planFile);
}

const planTitle = firstHeading(planContent);
const short = planHash ? planHash.slice(0, 6) : '000000';

const tasks = Array.isArray(metadata.tasks) ? metadata.tasks : [];
const subtasks = Array.isArray(metadata.subtasks) ? metadata.subtasks : [];
const totalItems = tasks.length + subtasks.length;
const totalEstimate = [...tasks, ...subtasks].reduce((acc, it) => acc + (typeof it.estimateHours === 'number' ? it.estimateHours : 0), 0);

let body = template;
body = body.replace(/^#\s+\s*#PLAN-001\s+-\s+<Plan Title>\s*$/m, `#  #PLAN-${short} - ${planTitle}`);
body = body.replace(/^\*\*Repository:\*\*\s+.*$/m, `**Repository:** ${repo}(${owner}/${repo})`);
body = body.replace(/^\*\*End Date Goal:\*\*\s+<date>\s*$/m, `**End Date Goal:** TBD`);
body = body.replace(/^\*\*Priority:\*\*\s+<PRIORITY>\s+\[.*\]$/m, `**Priority:** ${defaultPriority || 'HIGH'} [ LOW | HIGH | URGENT | MEDIUM ]`);
body = body.replace(/^\*\*Estimative Hours:\*\*\s+<ESTIMATE>\s*$/m, `**Estimative Hours:** ${totalEstimate || 0}h`);
body = body.replace(/^\*\*Status:\*\*\s+<STATUS>\s+\[.*\]$/m, `**Status:** ${defaultStatus || 'In Progress'} [ in progress | Ready | Done | in Review | Backlog ]`);
body = body.replace(/\*\*Total Planned Work:\*\*\s+<hours>/g, `**Total Planned Work:** ${totalEstimate || 0}h`);
body = body.replace(/\*\*Completion:\*\*\s+<percent>/g, `**Completion:** 0%`);
body = body.replace(/\*\*Active Features:\*\*\s+<count>/g, `**Active Features:** 0`);
body = body.replace(/\*\*Open Bugs:\*\*\s+<count>/g, `**Open Bugs:** 0`);
body = body.replace(/\*\*Timeline:\*\*\s+<start>\s+→\s+<end>/g, `**Timeline:** TBD → TBD`);

const idBlock = [
  stableId ? `**StableId:** ${stableId}` : null,
  planHash ? `**Plan Hash:** ${planHash}` : null,
  totalItems ? `**Total Items:** ${totalItems}` : null,
  labelsCsv ? `**Labels:** ${labelsCsv}` : null,
].filter(Boolean).join('  \n');

if (idBlock) {
  body = body.replace(/\n---\n\n## Executive Summary\n/m, `\n${idBlock}\n\n---\n\n## Executive Summary\n`);
}

const planSource = `<details>\n<summary>Source plan file (${path.basename(planFile)})</summary>\n\n\n\`\`\`markdown\n${planContent.replace(/\`\`\`/g, '\\`\\`\\`')}\n\`\`\`\n\n</details>`;
const progressPlaceholder = `## Progress Tracking\n\n_Not generated yet._`;

const markers = {
  metadataBegin: '<!-- E2E:PLAN_METADATA:BEGIN -->',
  metadataEnd: '<!-- E2E:PLAN_METADATA:END -->',
  planBegin: '<!-- E2E:PLAN_SOURCE:BEGIN -->',
  planEnd: '<!-- E2E:PLAN_SOURCE:END -->',
  progressBegin: '<!-- E2E:PROGRESS_TRACKING:BEGIN -->',
  progressEnd: '<!-- E2E:PROGRESS_TRACKING:END -->',
};

body = `${body.trim()}\n\n${markers.metadataBegin}\n${idBlock}\n${markers.metadataEnd}\n\n${markers.planBegin}\n${planSource}\n${markers.planEnd}\n\n${markers.progressBegin}\n${progressPlaceholder}\n${markers.progressEnd}\n`;
const title = `[PLAN] ${planTitle}`;

process.stdout.write(JSON.stringify({ title, body, planSource, progressPlaceholder, stableId, idBlock }, null, 0));
NODE
    )

    local pai_title
    pai_title=$(echo "$rendered" | jq -r '.title')
    local pai_body
    pai_body=$(echo "$rendered" | jq -r '.body')
    local pai_plan_source
    pai_plan_source=$(echo "$rendered" | jq -r '.planSource')
    local progress_placeholder
    progress_placeholder=$(echo "$rendered" | jq -r '.progressPlaceholder')
    local pai_metadata
    pai_metadata=$(echo "$rendered" | jq -r '.idBlock')

    log_info "Creating/reusing PAI (StableId: $pai_stable_id)..."

    if [[ "$DRY_RUN" == "true" ]]; then
        local dry_pai_number=null
        if [[ -n "$PARENT_ISSUE_NUMBER" ]]; then
            dry_pai_number="$PARENT_ISSUE_NUMBER"
        fi
        save_state "3" '{"completed": true, "paiNumber": '$dry_pai_number', "repository": "'$repo_full'", "simulated": true, "stableId": "'$pai_stable_id'"}'
        log_success "STAGE 3 complete (DRY-RUN simulated)"
        return 0
    fi

    local pai_number=""

    if [[ -n "$PARENT_ISSUE_NUMBER" ]]; then
        gh issue view "$PARENT_ISSUE_NUMBER" --repo "$repo_full" --json number --jq '.number' >/dev/null 2>&1 || {
            log_error "Parent issue #$PARENT_ISSUE_NUMBER not found in $repo_full"
            return 1
        }
        pai_number="$PARENT_ISSUE_NUMBER"
        log_success "Using existing PAI: #$pai_number"
    else
        local existing_list
        existing_list=$(gh issue list --repo "$repo_full" --label "sync-md" --state all --limit 200 --json number,body,title 2>/dev/null || echo '[]')
        local existing_pai
        # Accept both formats (e.g. "StableId: <id>" and "**StableId:** <id>")
        existing_pai=$(echo "$existing_list" | jq -r --arg sid "$pai_stable_id" '.[] | select(((.body // "") | contains($sid))) | .number' 2>/dev/null | head -n1)

        if [[ -n "$existing_pai" && "$existing_pai" != "null" ]]; then
            pai_number="$existing_pai"
            log_success "Reusing existing PAI: #$pai_number"
        else
            local pai_labels
            if [[ -n "$labels" ]]; then
                pai_labels="$labels,sync-md"
            else
                pai_labels="sync-md"
            fi

            local create_output
            create_output=$(gh issue create \
                --repo "$repo_full" \
                --title "$pai_title" \
                --body "$pai_body" \
                --label "$pai_labels" \
                ${assignee:+--assignee "$assignee"} \
                2>&1)

            [[ $? -ne 0 ]] && { log_error "Failed to create PAI: $create_output"; return 1; }

            pai_number=$(echo "$create_output" | grep -oP 'issues/\K\d+' | head -n1)
            if [[ -z "$pai_number" || "$pai_number" == "null" ]]; then
                log_error "Failed to extract PAI issue number from: $create_output"
                return 1
            fi

            log_success "PAI created: #$pai_number"
            audit_log "issue_create" '{"kind":"parent","number":'$pai_number',"url":"'$(echo "$create_output" | grep -oP 'https://[^\s]+' | head -n1)'","stableId":'"$(echo "$pai_stable_id" | jq -Rs '.')"'}'
        fi
    fi

    # Ensure plan source section stays in sync, without overwriting progress structure.
    local current_body
    current_body=$(gh issue view "$pai_number" --repo "$repo_full" --json body --jq '.body' 2>/dev/null || echo "")
    local merged_body
    merged_body=$(merge_managed_section "$current_body" "<!-- E2E:PLAN_METADATA:BEGIN -->" "<!-- E2E:PLAN_METADATA:END -->" "$pai_metadata")
    merged_body=$(merge_managed_section "$merged_body" "<!-- E2E:PLAN_SOURCE:BEGIN -->" "<!-- E2E:PLAN_SOURCE:END -->" "$pai_plan_source")
    if ! echo "$merged_body" | grep -Fq "<!-- E2E:PROGRESS_TRACKING:BEGIN -->"; then
        merged_body=$(merge_managed_section "$merged_body" "<!-- E2E:PROGRESS_TRACKING:BEGIN -->" "<!-- E2E:PROGRESS_TRACKING:END -->" "$progress_placeholder")
    fi

    # Keep title fresh but avoid blowing away user-edits outside managed sections.
    echo "$merged_body" | gh issue edit "$pai_number" --repo "$repo_full" --title "$pai_title" --body-file - &>/dev/null || {
        log_error "Failed to update PAI #$pai_number"
        return 1
    }

    if [[ "$TIMING_AFTER_PAI" -gt 0 ]]; then
        log_info "Waiting ${TIMING_AFTER_PAI}s for indexing..."
        sleep "$TIMING_AFTER_PAI"
    fi

    save_state "3" '{"completed": true, "paiNumber": '$pai_number', "repository": "'$repo_full'", "created": true, "stableId": "'$pai_stable_id'"}'
    log_success "STAGE 3 complete - PAI #$pai_number"
    return 0
}

# STAGE 4
stage_create_children() {
    log_stage "4" "EXECUTE - Upsert Issues from sync-helper artifacts"
    
    local pai_data=$(get_stage_data "3")
    [[ $(echo "$pai_data" | jq -r '.completed // false') != "true" ]] && { log_error "STAGE 3 not completed"; return 1; }
    
    local pai_number
    pai_number=$(echo "$pai_data" | jq -r '.paiNumber // empty')
    local repo_full=$(echo "$pai_data" | jq -r '.repository')
    
    local prep_data=$(get_stage_data "2")
    local sync_config
    sync_config=$(echo "$prep_data" | jq -r '.syncConfig // empty')
    local engine_output_path
    engine_output_path=$(echo "$prep_data" | jq -r '.engineOutputPath // empty')
    local metadata_file
    metadata_file=$(echo "$prep_data" | jq -r '.metadataFile // empty')
    local item_count
    item_count=$(echo "$prep_data" | jq -r '.itemCount // 0')
    
    [[ -z "$sync_config" ]] && { log_error "syncConfig missing. Run STAGE 2."; return 1; }
    [[ -z "$engine_output_path" ]] && { log_error "engineOutputPath missing. Run STAGE 2."; return 1; }
    [[ ! -f "$metadata_file" ]] && { log_error "metadataFile missing. Run STAGE 2."; return 1; }

    log_info "Repo: $repo_full"
    log_info "Items: $item_count"
    log_info "Running executor (server/executor.js)..."

    if [[ "$DRY_RUN" == "true" ]]; then
        node "$PROJECT_ROOT/server/executor.js" --config "$sync_config" --dry-run >/dev/null
    else
        node "$PROJECT_ROOT/server/executor.js" --config "$sync_config" >/dev/null
    fi

    [[ ! -f "$engine_output_path" ]] && { log_error "engine-output not found: $engine_output_path"; return 1; }

    local created_count
    created_count=$(jq -r '[.results[0].tasks[]? | select(.created == true)] | length' "$engine_output_path" 2>/dev/null || echo 0)
    log_success "Executor complete (created=$created_count)"

    if [[ "$DRY_RUN" != "true" && "$TIMING_AFTER_CHILDREN" -gt 0 ]]; then
        log_info "Waiting ${TIMING_AFTER_CHILDREN}s for indexing..."
        sleep "$TIMING_AFTER_CHILDREN"
    fi
    
    save_state "4" '{"completed": true, "createdCount": '$created_count', "engineOutputPath": "'$engine_output_path'", "metadataFile": "'$metadata_file'"}'
    log_success "STAGE 4 complete"
    return 0
}

# STAGE 5
stage_link_hierarchy() {
    log_stage "5" "LINK HIERARCHY - Create Relationships"
    
    local pai_data
    pai_data=$(get_stage_data "3")

    local repo_full
    repo_full=$(echo "$pai_data" | jq -r '.repository // empty')
    if [[ -z "$repo_full" ]]; then
        resolve_repo_full || return 1
        repo_full="$SELECTED_REPO_FULL"
    fi

    local pai_number
    pai_number=$(echo "$pai_data" | jq -r '.paiNumber // empty')
    [[ -n "$PARENT_ISSUE_NUMBER" ]] && pai_number="$PARENT_ISSUE_NUMBER"
    [[ -z "$pai_number" ]] && { log_error "PAI number missing. Provide --parent-number or complete STAGE 3."; return 1; }

    local stage4_data
    stage4_data=$(get_stage_data "4")
    local stage2_data
    stage2_data=$(get_stage_data "2")

    local engine_output_path=""
    local metadata_file=""

    # Engine output resolution priority:
    # 1) explicit CLI override
    # 2) stage 4 state (executor)
    # 3) stage 2 state (prepare)
    # 4) sync-helper config outputs.engineOutputPath
    if [[ -n "$ENGINE_OUTPUT_FILE_OVERRIDE" ]]; then
        engine_output_path="$ENGINE_OUTPUT_FILE_OVERRIDE"
    else
        engine_output_path=$(echo "$stage4_data" | jq -r '.engineOutputPath // empty')
        if [[ -z "$engine_output_path" || "$engine_output_path" == "null" ]]; then
            engine_output_path=$(echo "$stage2_data" | jq -r '.engineOutputPath // empty')
        fi
        if [[ -z "$engine_output_path" || "$engine_output_path" == "null" ]]; then
            local cfg
            cfg=$(resolve_sync_config_for_repo "$repo_full" || true)
            if [[ -n "$cfg" && -f "$cfg" ]]; then
                engine_output_path=$(jq -r '.outputs.engineOutputPath // empty' "$cfg" 2>/dev/null || true)
            fi
        fi
    fi

    # Metadata resolution priority:
    # 1) explicit CLI override
    # 2) stage 4 state
    # 3) stage 2 state
    # 4) resolve_metadata_file() candidates
    if [[ -n "$METADATA_FILE" ]]; then
        metadata_file="$METADATA_FILE"
    else
        metadata_file=$(echo "$stage4_data" | jq -r '.metadataFile // empty')
        if [[ -z "$metadata_file" || "$metadata_file" == "null" ]]; then
            metadata_file=$(echo "$stage2_data" | jq -r '.metadataFile // empty')
        fi
        if [[ -z "$metadata_file" || "$metadata_file" == "null" ]]; then
            resolve_metadata_file || true
            metadata_file="$METADATA_FILE"
        fi
    fi

    if [[ -z "$metadata_file" || "$metadata_file" == "null" || ! -f "$metadata_file" ]]; then
        log_error "metadata.json not found. Provide --metadata-file or ensure it exists under tmp/<repo>/metadata.json."
        return 1
    fi
    if [[ -z "$engine_output_path" || "$engine_output_path" == "null" || ! -f "$engine_output_path" ]]; then
        log_error "engine-output.json not found. Provide --engine-output-file or ensure outputs.engineOutputPath exists in sync-helper config."
        return 1
    fi

    log_info "Building link plan from metadata.json + engine-output.json (stableId-based)..."

    local owner="${repo_full%/*}"
    local repo="${repo_full#*/}"

        local link_count=0
        local skip_count=0
        local fail_count=0

        # Create a deterministic link plan:
        # - All top-level tasks become sub-issues of the PAI
        # - All subtasks become sub-issues of their parentStableId
        local link_plan
        link_plan=$(REPO_FULL="$repo_full" PAI_NUMBER="$pai_number" METADATA_FILE="$metadata_file" ENGINE_OUTPUT_FILE="$engine_output_path" node - <<'NODE'
const fs = require('fs');

const repoFull = process.env.REPO_FULL;
const paiNumber = parseInt(process.env.PAI_NUMBER, 10);
const metadataFile = process.env.METADATA_FILE;
const engineOutputFile = process.env.ENGINE_OUTPUT_FILE;

const metadata = JSON.parse(fs.readFileSync(metadataFile, 'utf8'));
const engineOut = JSON.parse(fs.readFileSync(engineOutputFile, 'utf8'));

function buildStableMap(out) {
    const map = new Map();
    const results = Array.isArray(out && out.results) ? out.results : [];
    for (const r of results) {
        const tasks = Array.isArray(r && r.tasks) ? r.tasks : [];
        for (const t of tasks) {
            if (!t || !t.stableId) continue;
            // Prefer entries that have issueNumber (dry-run will have null)
            const prev = map.get(t.stableId);
            if (!prev || (!prev.issueNumber && t.issueNumber)) {
                map.set(t.stableId, {
                    stableId: t.stableId,
                    issueNumber: t.issueNumber ?? null,
                    issueNodeId: t.issueNodeId ?? null,
                    parentStableId: t.parentStableId ?? null,
                });
            }
        }
    }
    return map;
}

const stableMap = buildStableMap(engineOut);
const tasks = Array.isArray(metadata.tasks) ? metadata.tasks : [];
const subtasks = Array.isArray(metadata.subtasks) ? metadata.subtasks : [];

const plan = [];

for (const t of tasks) {
    if (!t || !t.stableId) continue;
    const hit = stableMap.get(t.stableId) || {};
    plan.push({
        kind: 'task->pai',
        repoFull,
        parentType: 'pai',
        parentIssueNumber: paiNumber,
        parentStableId: null,
        childStableId: t.stableId,
        childIssueNumber: hit.issueNumber ?? null,
        childNodeId: hit.issueNodeId ?? null,
    });
}

for (const s of subtasks) {
    if (!s || !s.stableId || !s.parentStableId) continue;
    const child = stableMap.get(s.stableId) || {};
    const parent = stableMap.get(s.parentStableId) || {};
    plan.push({
        kind: 'subtask->parent',
        repoFull,
        parentType: 'stable',
        parentStableId: s.parentStableId,
        parentIssueNumber: parent.issueNumber ?? null,
        parentNodeId: parent.issueNodeId ?? null,
        childStableId: s.stableId,
        childIssueNumber: child.issueNumber ?? null,
        childNodeId: child.issueNodeId ?? null,
    });
}

process.stdout.write(JSON.stringify(plan));
NODE
        )

        local link_total
        link_total=$(echo "$link_plan" | jq -r 'length' 2>/dev/null || echo 0)
        log_info "Planned links: $link_total"

        log_info "Linking sub-issues via GraphQL addSubIssue..."

    local replace_parent_value
    replace_parent_value=$([[ "$REPLACE_PARENT" == "true" ]] && echo true || echo false)

    local pai_id=""
    if [[ "$DRY_RUN" != "true" ]]; then
        pai_id=$(gh api graphql -f query='query($owner:String!,$repo:String!,$number:Int!){repository(owner:$owner,name:$repo){issue(number:$number){id}}}' \
            -f owner="$owner" -f repo="$repo" -F number="$pai_number" --jq '.data.repository.issue.id' 2>/dev/null)
        [[ -z "$pai_id" || "$pai_id" == "null" ]] && { log_error "Failed to resolve PAI node id for #$pai_number"; return 1; }
    fi

    while IFS= read -r link; do
        local kind
        kind=$(echo "$link" | jq -r '.kind')
        local parent_type
        parent_type=$(echo "$link" | jq -r '.parentType')
        local parent_stable
        parent_stable=$(echo "$link" | jq -r '.parentStableId // empty')

        local parent_number
        parent_number=$(echo "$link" | jq -r '.parentIssueNumber // empty')
        local parent_node
        parent_node=$(echo "$link" | jq -r '.parentNodeId // empty')

        local child_number
        child_number=$(echo "$link" | jq -r '.childIssueNumber // empty')
        local child_node
        child_node=$(echo "$link" | jq -r '.childNodeId // empty')
        local child_stable
        child_stable=$(echo "$link" | jq -r '.childStableId')

        if [[ "$parent_type" == "pai" ]]; then
            parent_number="$pai_number"
        fi

        if [[ -z "$child_number" || "$child_number" == "null" ]]; then
            if [[ "$DRY_RUN" == "true" ]]; then
                log_warning "[DRY-RUN] Would link (missing child issueNumber) stableId=${child_stable:0:10} kind=$kind"
                continue
            fi
            log_error "Missing child issueNumber for stableId=${child_stable:0:10} (kind=$kind). Re-run STAGE 4 without --dry-run."
            fail_count=$((fail_count + 1))
            continue
        fi

        if [[ "$DRY_RUN" == "true" ]]; then
            if [[ "$parent_type" == "pai" ]]; then
                log_warning "[DRY-RUN] Would link #$child_number as sub-issue of PAI #$pai_number"
            else
                log_warning "[DRY-RUN] Would link #$child_number as sub-issue of parentStableId=${parent_stable:0:10} (#${parent_number:-?})"
            fi
            continue
        fi

        # Resolve parent node id
        local parent_id=""
        if [[ "$parent_type" == "pai" ]]; then
            parent_id="$pai_id"
        else
            if [[ -n "$parent_node" && "$parent_node" != "null" ]]; then
                parent_id="$parent_node"
            else
                if [[ -z "$parent_number" || "$parent_number" == "null" ]]; then
                    log_error "Missing parent issueNumber for parentStableId=${parent_stable:0:10} (child #$child_number)"
                    fail_count=$((fail_count + 1))
                    continue
                fi
                parent_id=$(gh api graphql -f query='query($owner:String!,$repo:String!,$number:Int!){repository(owner:$owner,name:$repo){issue(number:$number){id}}}' \
                    -f owner="$owner" -f repo="$repo" -F number="$parent_number" --jq '.data.repository.issue.id' 2>/dev/null)
                if [[ -z "$parent_id" || "$parent_id" == "null" ]]; then
                    log_error "Failed to resolve parent node id for #$parent_number (parentStableId=${parent_stable:0:10})"
                    fail_count=$((fail_count + 1))
                    continue
                fi
            fi
        fi

        # Resolve child node id
        local child_id=""
        if [[ -n "$child_node" && "$child_node" != "null" ]]; then
            child_id="$child_node"
        else
            child_id=$(gh api graphql -f query='query($owner:String!,$repo:String!,$number:Int!){repository(owner:$owner,name:$repo){issue(number:$number){id parent{number}}}}' \
                -f owner="$owner" -f repo="$repo" -F number="$child_number" --jq '.data.repository.issue.id' 2>/dev/null)
            if [[ -z "$child_id" || "$child_id" == "null" ]]; then
                log_error "Failed to resolve child node id for #$child_number"
                fail_count=$((fail_count + 1))
                continue
            fi
        fi

        local resp
        resp=$(gh api graphql \
            -f query='mutation($issueId:ID!,$subIssueId:ID!,$replaceParent:Boolean){addSubIssue(input:{issueId:$issueId,subIssueId:$subIssueId,replaceParent:$replaceParent}){issue{number} subIssue{number}}}' \
            -f issueId="$parent_id" \
            -f subIssueId="$child_id" \
            -F replaceParent="$replace_parent_value" \
            2>&1)

        if echo "$resp" | jq -e '.data.addSubIssue.subIssue.number' >/dev/null 2>&1; then
            log_success "Linked #$child_number"
            link_count=$((link_count + 1))
            audit_log "subissue_link" '{"parent":'"${parent_number:-$pai_number}"',"child":'$child_number',"replaceParent":'$replace_parent_value',"kind":'"$(echo "$kind" | jq -Rs '.')"'}'
        else
            local msg
            msg=$(echo "$resp" | jq -r '.errors[0].message // empty' 2>/dev/null)
            
            # Retry with replaceParent=true if failure is due to multiple parents or duplicate sub-issues
            if [[ -n "$msg" ]] && { echo "$msg" | grep -qi 'only have one parent'; }; then
                 log_warning "Linking failed. Retrying with replaceParent=true for #$child_number..."
                 resp=$(gh api graphql \
                    -f query='mutation($issueId:ID!,$subIssueId:ID!,$replaceParent:Boolean){addSubIssue(input:{issueId:$issueId,subIssueId:$subIssueId,replaceParent:$replaceParent}){issue{number} subIssue{number}}}' \
                    -f issueId="$parent_id" \
                    -f subIssueId="$child_id" \
                    -F replaceParent=true \
                    2>&1)
                 
                 if echo "$resp" | jq -e '.data.addSubIssue.subIssue.number' >/dev/null 2>&1; then
                    log_success "Linked #$child_number (parent replaced)"
                    link_count=$((link_count + 1))
                    audit_log "subissue_link" '{"parent":'"${parent_number:-$pai_number}"',"child":'$child_number',"replaceParent":true,"kind":'"$(echo "$kind" | jq -Rs '.')"'}'
                    continue
                 fi
                 # Update msg if retry failed too
                 msg=$(echo "$resp" | jq -r '.errors[0].message // empty' 2>/dev/null)
            fi

            if [[ -n "$msg" ]] && echo "$msg" | grep -qi 'already'; then
                log_info "Already linked (#$child_number)"
                skip_count=$((skip_count + 1))
            else
                log_error "Failed to link #$child_number: ${msg:-$resp}"
                fail_count=$((fail_count + 1))
            fi
        fi

        sleep 0.2
    done < <(echo "$link_plan" | jq -c '.[]')

    log_success "Sub-issue linking complete (linked=$link_count, skipped=$skip_count, failed=$fail_count)"

    if [[ "$DRY_RUN" != "true" && "$TIMING_AFTER_LINK" -gt 0 ]]; then
        log_info "Waiting ${TIMING_AFTER_LINK}s for indexing..."
        sleep "$TIMING_AFTER_LINK"
    fi

    save_state "5" '{"completed": true, "linkedCount": '$link_count', "skippedCount": '$skip_count', "failedCount": '$fail_count'}'
    log_success "STAGE 5 complete"
    return 0
}

# STAGE 6
stage_sync_projectv2() {
    log_stage "6" "SYNC PROJECTV2 - Metadata"

    if [[ "$ENABLE_PROJECT_SYNC" != "true" ]]; then
        log_warning "ProjectV2 sync disabled. Enable with --project <ownerOrOrg>/<number> and --enable-project-sync."
        save_state "6" '{"completed": true, "enabled": false, "note": "Skipped"}'
        log_success "STAGE 6 complete"
        return 0
    fi

    local project_id
    project_id=$(resolve_project_id) || return 1

    local pai_data
    pai_data=$(get_stage_data "3")
    local repo_full
    repo_full=$(echo "$pai_data" | jq -r '.repository // empty')
    [[ -z "$repo_full" ]] && { resolve_repo_full || return 1; repo_full="$SELECTED_REPO_FULL"; }

    local owner="${repo_full%/*}"
    local repo="${repo_full#*/}"

    local pai_number
    pai_number=$(echo "$pai_data" | jq -r '.paiNumber // empty')
    [[ -n "$PARENT_ISSUE_NUMBER" ]] && pai_number="$PARENT_ISSUE_NUMBER"

    local children_data
    children_data=$(get_stage_data "4")
    [[ $(echo "$children_data" | jq -r '.completed // false') != "true" ]] && { log_error "STAGE 4 not completed. Stage 6 requires engine-output.json."; return 1; }

    local engine_output_path
    engine_output_path=$(echo "$children_data" | jq -r '.engineOutputPath // empty')
    [[ -z "$engine_output_path" || ! -f "$engine_output_path" ]] && { log_error "engine-output.json not found. Run STAGE 4."; return 1; }

    # Build a map: issueNumber -> nodeId (when available)
    local number_to_node
    number_to_node=$(ENGINE_OUTPUT_FILE="$engine_output_path" node - <<'NODE'
const fs = require('fs');
const p = process.env.ENGINE_OUTPUT_FILE;
const out = JSON.parse(fs.readFileSync(p, 'utf8'));
const map = {};
for (const r of (out.results || [])) {
  for (const t of (r.tasks || [])) {
    if (!t || !t.issueNumber) continue;
    const num = String(t.issueNumber);
    if (!map[num] && t.issueNodeId) map[num] = t.issueNodeId;
  }
}
process.stdout.write(JSON.stringify(map));
NODE
    )

    local issue_numbers
    issue_numbers=$(jq -c '[.results[].tasks[]? | .issueNumber] | map(select(. != null)) | unique' "$engine_output_path" 2>/dev/null || echo '[]')
    if [[ -n "$pai_number" && "$pai_number" != "null" ]]; then
        issue_numbers=$(echo "$issue_numbers" | jq -c --argjson pai "$pai_number" '. + [$pai] | unique')
    fi
    local added=0
    local skipped=0
    local failed=0

    log_info "Adding issues to ProjectV2 ($project_id)..."

    while IFS= read -r issue_number; do
        [[ -z "$issue_number" || "$issue_number" == "null" ]] && { skipped=$((skipped + 1)); continue; }

        if [[ "$DRY_RUN" == "true" ]]; then
            log_warning "[DRY-RUN] Would add #$issue_number to ProjectV2"
            skipped=$((skipped + 1))
            continue
        fi

        local content_id
        content_id=$(echo "$number_to_node" | jq -r --arg n "$issue_number" '.[$n] // empty' 2>/dev/null || true)
        if [[ -z "$content_id" || "$content_id" == "null" ]]; then
            content_id=$(gh api graphql \
                -f query='query($owner:String!,$repo:String!,$number:Int!){repository(owner:$owner,name:$repo){issue(number:$number){id}}}' \
                -f owner="$owner" -f repo="$repo" -F number="$issue_number" --jq '.data.repository.issue.id' 2>/dev/null || true)
        fi

        if [[ -z "$content_id" || "$content_id" == "null" ]]; then
            log_error "Failed to resolve issue node id for #$issue_number"
            failed=$((failed + 1))
            continue
        fi

        local resp
        resp=$(gh api graphql \
            -f query='mutation($projectId:ID!,$contentId:ID!){addProjectV2ItemById(input:{projectId:$projectId,contentId:$contentId}){item{id}}}' \
            -f projectId="$project_id" -f contentId="$content_id" 2>&1)

        if echo "$resp" | jq -e '.data.addProjectV2ItemById.item.id' >/dev/null 2>&1; then
            log_success "Added #$issue_number"
            added=$((added + 1))
            audit_log "project_add_item" '{"projectId":"'$project_id'","issue":'$issue_number'}'
        else
            local msg
            msg=$(echo "$resp" | jq -r '.errors[0].message // empty' 2>/dev/null)
            if [[ -n "$msg" ]] && echo "$msg" | grep -qi 'already'; then
                log_info "Already in project (#$issue_number)"
                skipped=$((skipped + 1))
            else
                log_error "Failed to add #$issue_number to project: ${msg:-$resp}"
                failed=$((failed + 1))
            fi
        fi

        sleep 0.2
    done < <(echo "$issue_numbers" | jq -r '.[]')

    log_success "ProjectV2 sync complete (added=$added, skipped=$skipped, failed=$failed)"
    save_state "6" '{"completed": true, "enabled": true, "projectId": "'$project_id'", "added": '$added', "skipped": '$skipped', "failed": '$failed'}'
    log_success "STAGE 6 complete"
    return 0
}

# STAGE 7
stage_progress_tracking() {
    log_stage "7" "PROGRESS TRACKING - Checklist"
    
    local children_data=$(get_stage_data "4")
    [[ $(echo "$children_data" | jq -r '.completed // false') != "true" ]] && { log_error "STAGE 4 not completed"; return 1; }
    
    local pai_data=$(get_stage_data "3")
    local pai_number=$(echo "$pai_data" | jq -r '.paiNumber')
    local repo_full=$(echo "$pai_data" | jq -r '.repository')

    local engine_output_path
    engine_output_path=$(echo "$children_data" | jq -r '.engineOutputPath // empty')
    local metadata_file
    metadata_file=$(echo "$children_data" | jq -r '.metadataFile // empty')
    [[ -n "$METADATA_FILE" ]] && metadata_file="$METADATA_FILE"

    [[ -z "$engine_output_path" || ! -f "$engine_output_path" ]] && { log_error "engine-output.json not found. Run STAGE 4."; return 1; }
    [[ -z "$metadata_file" || ! -f "$metadata_file" ]] && { log_error "metadata.json not found. Run STAGE 2 or provide --metadata-file."; return 1; }

    local prep_data
    prep_data=$(get_stage_data "2")
    local plan_hash
    plan_hash=$(echo "$prep_data" | jq -r '.planHash // empty')
    
    local simulated
    simulated=$(echo "$pai_data" | jq -r '.simulated // false')
    [[ "$simulated" == "true" ]] && { log_warning "DRY-RUN simulated run. Skipping PAI body updates."; }

    log_info "Generating checklist from metadata.json + engine-output.json..."
    
    local checklist_file="$OUTPUT_DIR/progress-tracking.md"
    
        local checklist_json
        checklist_json=$(REPO_FULL="$repo_full" METADATA_FILE="$metadata_file" ENGINE_OUTPUT_FILE="$engine_output_path" node - <<'NODE'
const fs = require('fs');

const repoFull = process.env.REPO_FULL;
const metadataFile = process.env.METADATA_FILE;
const engineOutputFile = process.env.ENGINE_OUTPUT_FILE;

const metadata = JSON.parse(fs.readFileSync(metadataFile, 'utf8'));
const engineOut = JSON.parse(fs.readFileSync(engineOutputFile, 'utf8'));

function buildStableToNumber(out) {
    const map = new Map();
    for (const r of (out.results || [])) {
        for (const t of (r.tasks || [])) {
            if (!t || !t.stableId) continue;
            if (t.issueNumber != null) map.set(t.stableId, t.issueNumber);
        }
    }
    return map;
}

const stableToNumber = buildStableToNumber(engineOut);
const tasks = Array.isArray(metadata.tasks) ? metadata.tasks : [];
const subtasks = Array.isArray(metadata.subtasks) ? metadata.subtasks : [];

let total = 0;
let completed = 0;
const lines = [];

function fmtLine(checked, num, text, extra) {
    const box = checked ? 'x' : ' ';
    const safeText = String(text || '').trim() || '(no text)';
    if (num != null) {
        const url = `https://github.com/${repoFull}/issues/${num}`;
        return `- [${box}] [#${num}](${url}) ${safeText}${extra ? ' ' + extra : ''}`;
    }
    return `- [${box}] (missing issue) ${safeText}${extra ? ' ' + extra : ''}`;
}

for (const t of tasks) {
    if (!t || !t.stableId) continue;
    const num = stableToNumber.get(t.stableId) ?? null;
    const checked = !!t.checked;
    total += 1;
    if (checked) completed += 1;
    lines.push(fmtLine(checked, num, t.text, `(StableId: ${String(t.stableId).slice(0, 10)})`));
}

for (const s of subtasks) {
    if (!s || !s.stableId) continue;
    const num = stableToNumber.get(s.stableId) ?? null;
    const parentNum = s.parentStableId ? (stableToNumber.get(s.parentStableId) ?? null) : null;
    const checked = !!s.checked;
    total += 1;
    if (checked) completed += 1;
    const parentExtra = parentNum != null ? `(parent #${parentNum})` : (s.parentStableId ? `(parentStableId: ${String(s.parentStableId).slice(0, 10)})` : '');
    lines.push(fmtLine(checked, num, s.text, parentExtra));
}

const percent = total ? Math.round((completed / total) * 100) : 0;
process.stdout.write(JSON.stringify({ total, completed, percent, markdownLines: lines }));
NODE
        )

        local total_count
        total_count=$(echo "$checklist_json" | jq -r '.total' 2>/dev/null || echo 0)
        local completed_count
        completed_count=$(echo "$checklist_json" | jq -r '.completed' 2>/dev/null || echo 0)
        local percent
        percent=$(echo "$checklist_json" | jq -r '.percent' 2>/dev/null || echo 0)

        cat > "$checklist_file" << EOF
## Progress Tracking

**Total:** $total_count  
**Completed:** $completed_count / $total_count (${percent}%)

---

EOF

        echo "$checklist_json" | jq -r '.markdownLines[]' >> "$checklist_file"
    
    log_success "Checklist generated"
    
    if [[ "$DRY_RUN" != "true" && "$simulated" != "true" ]]; then
        log_info "Updating PAI managed progress section..."
        local current_body
        current_body=$(gh issue view "$pai_number" --repo "$repo_full" --json body --jq '.body')
        local merged_body
        merged_body=$(merge_managed_section "$current_body" "<!-- E2E:PROGRESS_TRACKING:BEGIN -->" "<!-- E2E:PROGRESS_TRACKING:END -->" "$(cat "$checklist_file")")
        echo "$merged_body" | gh issue edit "$pai_number" --repo "$repo_full" --body-file - &>/dev/null
        log_success "PAI updated"

        if [[ "$ENFORCE_PAI_CONTENT_MATCH" == "true" ]]; then
            if [[ -z "$plan_hash" ]]; then
                log_error "Plan hash missing; cannot verify PAI content."
                return 1
            fi
            local updated_body
            updated_body=$(gh issue view "$pai_number" --repo "$repo_full" --json body --jq '.body')
            # Back-compat: older PAIs might not include the raw plan hash string.
            # Accept either the plan hash or the stable id (plan-<hash>) in the body.
            local expected_sid
            expected_sid="plan-${plan_hash}"
            echo "$updated_body" | grep -Fq "$plan_hash" || echo "$updated_body" | grep -Fq "$expected_sid" || {
                log_error "PAI content validation failed (plan hash/stableId not found)."
                return 1
            }
            log_success "PAI content validation passed"
        fi
    fi
    
    save_state "7" '{"completed": true, "checklistFile": "'$checklist_file'"}'
    log_success "STAGE 7 complete"
    return 0
}

# STAGE 8
stage_reporting() {
    log_stage "8" "REPORTING - Audit Trail"
    
    local pai_data=$(get_stage_data "3")
    local children_data=$(get_stage_data "4")
    
    local pai_number=$(echo "$pai_data" | jq -r '.paiNumber // empty')
    local repo_full=$(echo "$pai_data" | jq -r '.repository // empty')
    local created_count=$(echo "$children_data" | jq -r '.createdCount')
    
    log_info "Generating report..."
    
    local report_file="$OUTPUT_DIR/e2e-execution-report.md"
    
    cat > "$report_file" << EOF
# E2E Flow Execution Report

**Generated:** $(date +'%Y-%m-%d %H:%M:%S')  
**Repository:** $repo_full  
**Plan:** ${SELECTED_PLAN_FILE:-$SELECTED_PLAN}

---

## Summary

- ✅ PAI: #$pai_number
- ✅ Sub-Issues: $created_count
- ✅ Linked
- ⚠️  ProjectV2: Manual sync

---

**URL:** https://github.com/$repo_full/issues/$pai_number
EOF
    
    log_success "Report: $report_file"
    
    echo ""
    log_stage "✨" "COMPLETE"
    echo ""
    log_success "PAI: #$pai_number"
    log_success "Sub-Issues: $created_count"
    echo ""
    log_info "https://github.com/$repo_full/issues/$pai_number"
    echo ""
    
    save_state "8" '{"completed": true, "reportFile": "'$report_file'"}'
    log_success "Done! 🎉"
    return 0
}

# Navigation
show_navigation_menu() {
    local current=$1
    local stage_name=${STAGE_NAMES[$current-1]:-"UNKNOWN"}
    
    # Print menu to stderr so it is visible to the user and not captured by command substitution
    {
        echo ""
        echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
        echo -e "${CYAN}  Stage $current: $stage_name - Complete${NC}"
        echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
        echo ""
        echo "Actions:"
        echo "  [c] Continue (default)"
        echo "  [r] Re-run stage"
        echo "  [s] Show state"
        [[ $current -gt 1 ]] && echo "  [b] Back"
        echo "  [q] Quit"
        echo ""
    } >&2
    
    local input
    read -p "Select action: " input
    echo "${input:-c}"
}

run_stage() {
    case $1 in
        1) stage_setup ;;
        2) stage_prepare ;;
        3) stage_create_pai ;;
        4) stage_create_children ;;
        5) stage_link_hierarchy ;;
        6) stage_sync_projectv2 ;;
        7) stage_progress_tracking ;;
        8) stage_reporting ;;
        *) log_error "Invalid stage"; return 1 ;;
    esac
}

show_current_state() {
    log_info "State:"
    for i in {1..8}; do
        local completed=$(get_stage_data "$i" | jq -r '.completed // false')
        local status="❌"
        [[ "$completed" == "true" ]] && status="✅"
        echo "  $status Stage $i (${STAGE_NAMES[$i-1]})"
    done
    echo ""
}

# Main
main() {
    echo -e "${MAGENTA}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════════════════╗
║                   E2E FLOW - ISSUE HIERARCHY GENERATOR                    ║
║                              Version 2.0                                  ║
╚═══════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
                        --repo) SELECTED_REPO="$2"; parse_repo_input "$2"; shift 2 ;;
                        --repo-id) SELECTED_REPO_ID="$2"; SELECTED_REPO_FULL=""; shift 2 ;;
                        --plan) SELECTED_PLAN="$2"; shift 2 ;;
                        --plan-file) SELECTED_PLAN_FILE="$2"; shift 2 ;;
                        --parent-number) PARENT_ISSUE_NUMBER="$2"; shift 2 ;;
                        --children-file) CHILDREN_FILE="$2"; shift 2 ;;
                        --replace-parent) REPLACE_PARENT=true; shift ;;
                        --include-parent-in-body) INCLUDE_PARENT_IN_BODY=true; shift ;;
                        --no-include-parent-in-body) INCLUDE_PARENT_IN_BODY=false; shift ;;
                        --project) PROJECT_SPEC="$2"; shift 2 ;;
                        --project-id) PROJECT_ID="$2"; shift 2 ;;
                        --enable-project-sync) ENABLE_PROJECT_SYNC=true; shift ;;
                        --metadata-file) METADATA_FILE="$2"; shift 2 ;;
                        --engine-output-file) ENGINE_OUTPUT_FILE_OVERRIDE="$2"; shift 2 ;;
                        --allow-missing-metadata) METADATA_REQUIRED=false; shift ;;
            --config) CONFIG_FILE="$2"; shift 2 ;;
            --dry-run) DRY_RUN=true; shift ;;
            --stage) CURRENT_STAGE="$2"; RUN_SINGLE_STAGE=true; shift 2 ;;
            --resume) CURRENT_STAGE=$(($(get_last_completed_stage) + 1)); shift ;;
            --non-interactive) INTERACTIVE=false; shift ;;
                        --help)
                                cat << EOF
Usage: $0 [options]

Targets:
    --repo <owner/name>            Target repository (recommended)
    --repo <id> | --repo-id <id>   Config repository id (back-compat)

Inputs:
    --plan <filename>              Plan filename resolved via config docsPath (interactive mode)
    --plan-file <path>             Absolute/relative path to plan file (portable)
    --parent-number <n>            Use existing parent issue instead of creating one
    --children-file <path>         JSON array file: [{"number":123}, ...] (enables standalone Stage 5/6)
    --metadata-file <path>         Path to metadata.json produced by sync-helper
    --engine-output-file <path>     Path to engine-output.json (for standalone Stage 5)
    --allow-missing-metadata        Continue without metadata validations

Sub-issues:
    --replace-parent               Replace existing parent when linking sub-issues

ProjectV2:
    --project <ownerOrOrg>/<n>     Target ProjectV2 by owner and number (e.g. Axodus/23)
    --project-id <nodeId>          Target ProjectV2 by node id
    --enable-project-sync          Enable Stage 6 to add issues to ProjectV2

Execution:
    --stage <n>                    Run a single stage (non-interactive recommended)
    --resume                       Resume from last completed stage
    --dry-run                      No GitHub writes
    --non-interactive              Run without navigation prompts
EOF
                                exit 0
                                ;;
            *) log_error "Unknown: $1"; exit 1 ;;
        esac
    done
    
    [[ -z "$SELECTED_REPO" && -z "$SELECTED_REPO_ID" && -z "$SELECTED_REPO_FULL" ]] && {
        log_prompt "Repository:"
        prompt_for_repo_selection
        parse_repo_input "$SELECTED_REPO"
    }

    resolve_repo_full || exit 1

    # Load defaults from sync-helper config if available
    local sync_cfg
    sync_cfg=$(resolve_sync_config_for_repo "$SELECTED_REPO_FULL")
    if [[ -n "$sync_cfg" ]]; then
        log_info "Found sync-helper config: $(basename "$sync_cfg")"
        if [[ "$ENABLE_PROJECT_SYNC" != "true" ]]; then
            local eps
            eps=$(jq -r '.enableProjectSync // false' "$sync_cfg")
            [[ "$eps" == "true" ]] && { ENABLE_PROJECT_SYNC=true; log_info "Auto-enabled ProjectSync"; }
        fi
        if [[ -z "$PROJECT_SPEC" ]]; then
            local p_owner p_num
            p_owner=$(jq -r '.owner // empty' "$sync_cfg")
            p_num=$(jq -r '.project.number // empty' "$sync_cfg")
            if [[ -n "$p_owner" && -n "$p_num" && "$p_num" != "null" ]]; then
                PROJECT_SPEC="${p_owner}/${p_num}"
                log_info "Auto-set project: $PROJECT_SPEC"
            fi
        fi
        if [[ -z "$METADATA_FILE" ]]; then
             local lpath
             lpath=$(jq -r '.localPath // empty' "$sync_cfg")
             if [[ -n "$lpath" && -f "$lpath/metadata.json" ]]; then
                 METADATA_FILE="$lpath/metadata.json"
                 log_info "Auto-set metadata: $METADATA_FILE"
             fi
        fi
    fi

    # Update STATE_FILE to be repo-specific once repo is resolved.
    # This prevents state/plan leakage between different repositories.
    if [[ -n "$SELECTED_REPO_FULL" ]]; then
        mkdir -p "$OUTPUT_DIR"
        STATE_FILE="$OUTPUT_DIR/execution-state-${SELECTED_REPO_FULL//\//-}.json"
        
        # If --resume was used, re-calculate based on the now-repo-specific state.
        if [[ $CURRENT_STAGE -gt 1 && -f "$STATE_FILE" ]]; then
             CURRENT_STAGE=$(($(get_last_completed_stage) + 1))
        fi
    fi

    # Non-interactive / stage re-runs: reuse previously selected plan file from state when available.
    if [[ -z "$SELECTED_PLAN" && -z "$SELECTED_PLAN_FILE" && -f "$STATE_FILE" ]]; then
        local saved_plan_file
        saved_plan_file=$(jq -r '.stages["2"].planFile // empty' "$STATE_FILE" 2>/dev/null || true)
        if [[ -n "$saved_plan_file" && "$saved_plan_file" != "null" ]]; then
            SELECTED_PLAN_FILE="$saved_plan_file"
        fi
    fi
    
    [[ -z "$SELECTED_PLAN" && -z "$SELECTED_PLAN_FILE" ]] && {
        log_prompt "Plan:"
        echo "  [1] PLAN.md  [2] SPRINT.md  [3] Custom"
        read -p "Choice: " plan_choice
        case $plan_choice in
            1) SELECTED_PLAN="PLAN.md" ;;
            2) SELECTED_PLAN="SPRINT.md" ;;
            3) read -p "Filename: " SELECTED_PLAN ;;
            *) SELECTED_PLAN="SPRINT.md" ;;
        esac
    }
    
    log_info "Repo: $SELECTED_REPO_FULL"
    [[ -n "$SELECTED_PLAN_FILE" ]] && log_info "Plan file: $SELECTED_PLAN_FILE" || log_info "Plan: $SELECTED_PLAN"
    [[ -n "$PARENT_ISSUE_NUMBER" ]] && log_info "Parent: #$PARENT_ISSUE_NUMBER"
    [[ -n "$CHILDREN_FILE" ]] && log_info "Children file: $CHILDREN_FILE"
    [[ -n "$METADATA_FILE" ]] && log_info "Metadata file: $METADATA_FILE"
    [[ "$DRY_RUN" == "true" ]] && log_warning "DRY-RUN MODE"
    
    if [[ "$INTERACTIVE" == "true" ]]; then
        while [[ $CURRENT_STAGE -le 8 ]]; do
            run_stage $CURRENT_STAGE && {
                [[ $CURRENT_STAGE -eq 8 ]] && break
                choice=$(show_navigation_menu $CURRENT_STAGE)
                case $choice in
                    c|C|"") CURRENT_STAGE=$((CURRENT_STAGE + 1)) ;;
                    b|B) [[ $CURRENT_STAGE -gt 1 ]] && CURRENT_STAGE=$((CURRENT_STAGE - 1)) ;;
                    r|R) : ;;
                    s|S) show_current_state ;;
                    q|Q) exit 0 ;;
                    *) CURRENT_STAGE=$((CURRENT_STAGE + 1)) ;;
                esac
            } || {
                log_error "Stage failed"
                read -p "Retry? [y/N]: " retry
                [[ "$retry" =~ ^[Yy]$ ]] || exit 1
            }
        done
    else
        if [[ "$RUN_SINGLE_STAGE" == "true" ]]; then
            run_stage $CURRENT_STAGE || exit 1
        else
            for stage in $(seq $CURRENT_STAGE 8); do
                run_stage $stage || exit 1
            done
        fi
    fi
    
    log_success "E2E Flow complete! 🎉"
}

main "$@"
