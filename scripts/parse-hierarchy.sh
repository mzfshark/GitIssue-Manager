#!/bin/bash

###############################################################################
# parse-hierarchy.sh
# Parse .md files and extract hierarchical structure for issue creation
###############################################################################

set -euo pipefail

# Colors for output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Logging functions
info() {
    echo -e "${BLUE}ℹ️  $*${NC}"
}

success() {
    echo -e "${GREEN}✅ $*${NC}"
}

warn() {
    echo -e "${YELLOW}⚠️  $*${NC}"
}

error() {
    echo -e "${RED}❌ $*${NC}" >&2
}

###############################################################################
# PARSE MARKDOWN HIERARCHY
###############################################################################

# Extract checklist items from markdown and determine hierarchy level
# Input: file_path
# Output: JSON array with structure
parse_md_file() {
    local file_path=$1
    
    if [[ ! -f "$file_path" ]]; then
        error "File not found: $file_path"
        return 1
    fi
    
    info "Parsing: $file_path"
    
    local output_json="["
    local first=true
    local current_level=0
    local prev_level=0
    
    while IFS= read -r line; do
        # Skip empty lines and headings
        [[ -z "$line" || "$line" =~ ^# ]] && continue
        
        # Match checklist items: - [ ] or - [x]
        if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*\[([ x])\][[:space:]]*(.*) ]]; then
            local status="${BASH_REMATCH[1]}"
            local title="${BASH_REMATCH[2]}"
            local indent_level=$((${#line} - ${#line#*-} / 2))
            
            # Determine hierarchy level (0 = root, 1 = sub, 2 = sub-sub)
            local level=0
            if [[ "$line" =~ ^[[:space:]]{2,4}- ]]; then
                level=1
            elif [[ "$line" =~ ^[[:space:]]{4,8}- ]]; then
                level=2
            elif [[ "$line" =~ ^[[:space:]]{8,}- ]]; then
                level=3
            fi
            
            local is_done=false
            [[ "$status" == "x" ]] && is_done=true
            
            # Build JSON object
            if [[ "$first" == false ]]; then
                output_json+=","
            fi
            first=false
            
            # Extract issue number if present (e.g., #456)
            local issue_num=""
            if [[ "$title" =~ #([0-9]+) ]]; then
                issue_num="${BASH_REMATCH[1]}"
            fi
            
            output_json+="{\"title\":\"${title//\"/\\\"}\",\"done\":$is_done,\"level\":$level,\"issue\":\"$issue_num\"}"
        fi
    done < "$file_path"
    
    output_json+="]"
    echo "$output_json"
}

# Merge multiple markdown files into single hierarchy
# Input: file_paths...
# Output: JSON with merged hierarchy
merge_md_hierarchy() {
    local merged="{"
    local first=true
    
    for file_path in "$@"; do
        local file_name=$(basename "$file_path" .md)
        
        if [[ "$first" == false ]]; then
            merged+=","
        fi
        first=false
        
        local content=$(parse_md_file "$file_path")
        merged+="\"$file_name\":$content"
    done
    
    merged+="}"
    echo "$merged"
}

###############################################################################
# DETECT HIERARCHY LEVEL
###############################################################################

# Count leading spaces to determine indent level
# Input: line
# Output: level (0, 1, 2, 3...)
detect_indent_level() {
    local line=$1
    local spaces=0
    
    for (( i=0; i<${#line}; i++ )); do
        if [[ "${line:$i:1}" == " " ]]; then
            ((spaces++))
        else
            break
        fi
    done
    
    # Convert spaces to levels (2-4 spaces = level 1, 4-8 = level 2, etc.)
    local level=$((spaces / 2))
    [[ $level -gt 3 ]] && level=3
    
    echo "$level"
}

###############################################################################
# BUILD ISSUE TREE
###############################################################################

# Create hierarchical structure for issue linking
# Input: parsed JSON
# Output: Tree structure with parent/child relationships
build_issue_tree() {
    local json_input=$1
    local repo=$2
    
    info "Building issue tree for $repo"
    
    # Parse and build relationships
    # This would process the JSON and create parent-child linkages
    # For now, output the structure
    echo "$json_input" | jq '.'
}

###############################################################################
# MAIN
###############################################################################

main() {
    local repo_path=${1:-.}
    
    info "Starting hierarchy parse for: $repo_path"
    
    # Find .md files to parse
    local plan_file="$repo_path/PLAN.md"
    local sprint_file="$repo_path/SPRINT.md"
    
    # Check which files exist
    local files_to_parse=()
    [[ -f "$plan_file" ]] && files_to_parse+=("$plan_file")
    [[ -f "$sprint_file" ]] && files_to_parse+=("$sprint_file")
    
    if [[ ${#files_to_parse[@]} -eq 0 ]]; then
        error "No .md files found in $repo_path"
        return 1
    fi
    
    # Parse files
    local hierarchy=$(merge_md_hierarchy "${files_to_parse[@]}")
    
    # Output hierarchy
    success "Hierarchy parsed successfully"
    echo "$hierarchy" | jq '.'
}

main "$@"
