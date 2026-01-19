#!/usr/bin/env bash
set -eo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_DIR="$ROOT_DIR/sync-helper/configs"
mkdir -p "$CONFIG_DIR"

select_project_for_owner() {
  # returns a line: <number>|<title>|<url>
  # usage: select_project_for_owner <OWNER>
  require_cmd gh
  local OWNER_LOOKUP="${1:-}"
  if [ -z "$OWNER_LOOKUP" ]; then
    echo "select_project_for_owner requires owner argument" >&2
    return 1
  fi

  echo
  echo "Fetching Projects V2 for owner: $OWNER_LOOKUP"
  local raw
  # Try organization first
  raw=$(gh api graphql -f query="query{ organization(login:\"$OWNER_LOOKUP\"){ projectsV2(first:50){nodes{number title url}} } }" --jq '.data.organization.projectsV2.nodes[] | "\(.number)|\(.title)|\(.url)"' 2>/dev/null || true)

  # If not organization or none, try user projects
  if [ -z "$raw" ]; then
    raw=$(gh api graphql -f query="query{ user(login:\"$OWNER_LOOKUP\"){ projectsV2(first:50){nodes{number title url}} } }" --jq '.data.user.projectsV2.nodes[] | "\(.number)|\(.title)|\(.url)"' 2>/dev/null || true)
  fi

  if [ -z "$raw" ]; then
    echo "No projects found for $OWNER_LOOKUP or error fetching." >&2
    return 1
  fi

  echo
  echo "Select a project:"
  local i=1
  local arr=()
  while IFS= read -r line; do
    arr+=("$line")
    local num=$(echo "$line" | cut -d'|' -f1)
    local title=$(echo "$line" | cut -d'|' -f2)
    echo "  $i) #$num - $title"
    i=$((i+1))
  done <<< "$raw"

  read -p "Enter number [1]: " sel
  sel=${sel:-1}
  local idx=$((sel-1))
  if [ $idx -lt 0 ] || [ $idx -ge ${#arr[@]} ]; then
    echo "Invalid selection" >&2
    return 1
  fi
  echo "${arr[$idx]}"
}

is_organization() {
  local OWNER_LOOKUP="${1:-}"
  require_cmd gh
  # Try to query organization; if present return 0, else return 1
  local res
  res=$(gh api graphql -f query="query{ organization(login:\"$OWNER_LOOKUP\"){ id } }" --jq '.data.organization.id' 2>/dev/null || true)
  if [ -n "$res" ] && [ "$res" != "null" ]; then
    return 0
  fi
  return 1
}


extract_project_number_from_url() {
  local url="$1"
  echo "$url" | sed -n 's|.*/projects/\([0-9]\+\).*|\1|p'
}

get_viewer_login() {
  gh api user --jq '.login' 2>/dev/null || echo ""
}

default_project_url_for_user() {
  local user="$1"
  local number="$2"
  echo "https://github.com/users/$user/projects/$number"
}

default_project_url_for_org() {
  local org="$1"
  local number="$2"
  echo "https://github.com/orgs/$org/projects/$number"
}

default_project_url_for_owner() {
  local owner="$1"
  local number="$2"
  if is_organization "$owner"; then
    default_project_url_for_org "$owner" "$number"
  else
    default_project_url_for_user "$owner" "$number"
  fi
}

echo "============================================"
echo "  GitIssue-Manager - Repository Setup"
echo "============================================"
echo

# Show existing configs and ask if user wants to edit or add new
if list_configured_repos; then
  echo
  echo "Options:"
  echo "  1) Configure a new repository"
  echo "  2) Edit an existing repository configuration"
  read -p "Choose (1/2) [1]: " SETUP_MODE
  SETUP_MODE=${SETUP_MODE:-1}
  
  if [ "$SETUP_MODE" = "2" ]; then
    read -p "Enter config name to edit (e.g., mzfshark-AragonOSX): " EXISTING_CONFIG
    EXISTING_CONFIG_PATH="$CONFIG_DIR/${EXISTING_CONFIG}.json"
    if [ -f "$EXISTING_CONFIG_PATH" ]; then
      echo "Editing: $EXISTING_CONFIG_PATH"
      echo "Opening in default editor..."
      ${EDITOR:-nano} "$EXISTING_CONFIG_PATH"
      echo "Configuration updated."
      exit 0
    else
      echo "Config file not found: $EXISTING_CONFIG_PATH"
      exit 1
    fi
  fi
fi

echo
echo "=== Repository Configuration ==="
read -p "Owner (GitHub user or organization) [default: mzfshark]: " OWNER
OWNER=${OWNER:-mzfshark}

read -p "Repository name (without owner) [default: AragonOSX]: " REPO_NAME
REPO_NAME=${REPO_NAME:-AragonOSX}

# Auto-detect owner type (organization or user) to drive ProjectV2 queries and URL examples.
# We do this early so prompts can show the correct URL format automatically.
OWNER_TYPE="user"
if command -v gh >/dev/null 2>&1; then
  if is_organization "$OWNER"; then
    OWNER_TYPE="organization"
  else
    OWNER_TYPE="user"
  fi
fi

REPO="${OWNER}/${REPO_NAME}"
echo "Full repo: $REPO"
echo

read -p "Local path to scan for *.md [default: ../${REPO_NAME}]: " LOCAL_PATH
LOCAL_PATH=${LOCAL_PATH:-../${REPO_NAME}}

echo
echo "=== Project Sync Configuration ==="
read -p "Enable Project sync for this repo? [y/N]: " ENABLE_PROJECT_SYNC
ENABLE_PROJECT_SYNC=${ENABLE_PROJECT_SYNC:-N}

PROJECT_URL=""
PROJECT_NUMBER=0

if [[ "$ENABLE_PROJECT_SYNC" =~ ^[Yy]$ ]]; then
  require_cmd gh
  echo
  echo "Project selection (owner Projects V2 — detected: $OWNER_TYPE)"
  echo "  1) List projects via gh and select"
  echo "  2) Paste project URL (https://github.com/users/<user>/projects/<id>)"
  read -p "Choose (1/2) [1]: " PROJECT_MODE
  PROJECT_MODE=${PROJECT_MODE:-1}

  if [ "$PROJECT_MODE" = "2" ]; then
    read -p "Project URL: " PROJECT_URL
    PROJECT_NUMBER=$(extract_project_number_from_url "$PROJECT_URL")
    if [ -z "$PROJECT_NUMBER" ]; then
      echo "Could not extract project number from URL" >&2
      exit 1
    fi
  else
    sel=$(select_project_for_owner "$OWNER")
    PROJECT_NUMBER=$(echo "$sel" | cut -d'|' -f1)
    PROJECT_URL=$(echo "$sel" | cut -d'|' -f3)
  fi
else
  echo
  read -p "Store a custom Project reference for metadata anyway? (y/N): " STORE_PROJECT
  STORE_PROJECT=${STORE_PROJECT:-N}
  if [[ "$STORE_PROJECT" =~ ^[Yy]$ ]]; then
    require_cmd gh
    echo
    echo "Project reference:" 
    echo "  1) List projects via gh and select (owner projects V2)"
    echo "  2) Paste project URL"
    echo "  3) Enter project number (will build URL for the owner)"
    read -p "Choose (1/2/3) [1]: " PROJECT_MODE
    PROJECT_MODE=${PROJECT_MODE:-1}

    if [ "$PROJECT_MODE" = "2" ]; then
      if [ "$OWNER_TYPE" = "organization" ]; then
        hint="https://github.com/orgs/$OWNER/projects/<id>"
      else
        hint="https://github.com/users/$OWNER/projects/<id>"
      fi
      read -p "Project URL (e.g. $hint): " PROJECT_URL
      PROJECT_NUMBER=$(extract_project_number_from_url "$PROJECT_URL")
      if [ -z "$PROJECT_NUMBER" ]; then
        echo "Could not extract project number from URL" >&2
        exit 1
      fi

    elif [ "$PROJECT_MODE" = "3" ]; then
      read -p "Project number: " PROJECT_NUMBER
      PROJECT_URL=$(default_project_url_for_owner "$OWNER" "$PROJECT_NUMBER")

    else
      # Try to list projects for the owner (org or user). If listing fails, fall back to asking for URL/number.
      if sel=$(select_project_for_owner "$OWNER" 2>/dev/null); then
        PROJECT_NUMBER=$(echo "$sel" | cut -d'|' -f1)
        PROJECT_URL=$(echo "$sel" | cut -d'|' -f3)
      else
        echo "Could not list projects for owner '$OWNER' (permissions or none). Please paste URL or enter number." >&2
        read -p "Project URL (leave empty to enter number): " PROJECT_URL
        if [ -n "$PROJECT_URL" ]; then
          PROJECT_NUMBER=$(extract_project_number_from_url "$PROJECT_URL")
          if [ -z "$PROJECT_NUMBER" ]; then
            echo "Could not extract project number from URL" >&2
            exit 1
          fi
        else
          read -p "Project number: " PROJECT_NUMBER
          PROJECT_URL=$(default_project_url_for_owner "$OWNER" "$PROJECT_NUMBER")
        fi
      fi
    fi
fi

read -p "Default estimate hours per subtask (default 1): " DEFAULT_ESTIMATE
DEFAULT_ESTIMATE=${DEFAULT_ESTIMATE:-1}
read -p "Default priority (e.g., URGENT, HIGH, NORMAL) [NORMAL]: " DEFAULT_PRIORITY
DEFAULT_PRIORITY=${DEFAULT_PRIORITY:-NORMAL}
read -p "Default status [TODO]: " DEFAULT_STATUS
DEFAULT_STATUS=${DEFAULT_STATUS:-TODO}
read -p "Default start date [TBD]: " DEFAULT_START_DATE
DEFAULT_START_DATE=${DEFAULT_START_DATE:-TBD}
read -p "Default end date [TBD]: " DEFAULT_END_DATE
DEFAULT_END_DATE=${DEFAULT_END_DATE:-TBD}
read -p "Default labels (comma-separated) [plan]: " DEFAULT_LABELS
DEFAULT_LABELS=${DEFAULT_LABELS:-plan}

DEFAULT_LABELS_JSON=""
IFS=',' read -ra LABELS_ARR <<< "$DEFAULT_LABELS"
for lbl in "${LABELS_ARR[@]}"; do
  lbl_trim=$(echo "$lbl" | xargs)
  if [ -n "$lbl_trim" ]; then
    if [ -n "$DEFAULT_LABELS_JSON" ]; then
      DEFAULT_LABELS_JSON="$DEFAULT_LABELS_JSON, "
    fi
    DEFAULT_LABELS_JSON="$DEFAULT_LABELS_JSON\"$lbl_trim\""
  fi
done
if [ -z "$DEFAULT_LABELS_JSON" ]; then
  DEFAULT_LABELS_JSON="\"plan\""
fi

# Generate config filename from owner and repo
CONFIG_NAME="${OWNER}-${REPO_NAME}"
CFG_FILE="$CONFIG_DIR/${CONFIG_NAME}.json"

# Set per-repo output paths
REPO_TMP_DIR="$ROOT_DIR/tmp/${CONFIG_NAME}"
TASKS_PATH="${REPO_TMP_DIR}/tasks.json"
SUBTASKS_PATH="${REPO_TMP_DIR}/subtasks.json"
ENGINE_INPUT_PATH="${REPO_TMP_DIR}/engine-input.json"
ENGINE_OUTPUT_PATH="${REPO_TMP_DIR}/engine-output.json"

echo
echo "Will write config to: $CFG_FILE"
mkdir -p "$(dirname "$CFG_FILE")"
cat > "$CFG_FILE" <<EOF
{
  "owner": "$OWNER",
  "repo": "$REPO",
  "localPath": "$LOCAL_PATH",
  "enableProjectSync": $( [[ "$ENABLE_PROJECT_SYNC" =~ ^[Yy]$ ]] && echo true || echo false ),
  "project": {
    "url": "${PROJECT_URL}",
    "number": $PROJECT_NUMBER,
    "fieldIds": {
      "statusFieldId": "",
      "priorityFieldId": "",
      "estimateHoursFieldId": "251668000",
      "startDateFieldId": "",
      "endDateFieldId": ""
    }
  },
  "defaults": {
    "defaultEstimateHours": $DEFAULT_ESTIMATE,
    "defaultPriority": "$DEFAULT_PRIORITY",
    "defaultStatus": "$DEFAULT_STATUS",
    "defaultStartDate": "$DEFAULT_START_DATE",
    "defaultEndDate": "$DEFAULT_END_DATE",
    "defaultLabels": [ $DEFAULT_LABELS_JSON ]
  },
  "outputs": {
    "tasksPath": "$TASKS_PATH",
    "subtasksPath": "$SUBTASKS_PATH",
    "engineInputPath": "$ENGINE_INPUT_PATH",
    "engineOutputPath": "$ENGINE_OUTPUT_PATH"
  }
}
EOF

echo "✓ Created $CFG_FILE"
echo
echo "Repository '$CONFIG_NAME' configured successfully!"
echo
echo "Output directory: $REPO_TMP_DIR"
echo
if [[ "$ENABLE_PROJECT_SYNC" =~ ^[Yy]$ ]]; then
  echo "Running ProjectV2 field discovery to populate field IDs and project node ID..."
  require_cmd bash
  require_cmd gh
  require_cmd jq

  # Run discovery which writes a config with field IDs; write to same CFG_FILE
  bash "$ROOT_DIR/sync-helper/discover-project-fields.sh" --owner "$OWNER" --repo "$REPO_NAME" --project-number $PROJECT_NUMBER --out "$CFG_FILE" || {
    echo "Field discovery script failed; leaving generated config for manual edit." >&2
  }

  # Attempt to resolve the ProjectV2 node id and write it into the config
  echo "Resolving ProjectV2 node ID for $OWNER/projects/$PROJECT_NUMBER..."
  if is_organization "$OWNER"; then
    PVT_ID=$(gh api graphql -f query="query{ organization(login:\"$OWNER\"){ projectV2(number:$PROJECT_NUMBER){ id } } }" --jq '.data.organization.projectV2.id' 2>/dev/null || true)
  else
    PVT_ID=$(gh api graphql -f query="query{ user(login:\"$OWNER\"){ projectV2(number:$PROJECT_NUMBER){ id } } }" --jq '.data.user.projectV2.id' 2>/dev/null || true)
  fi

  if [ -n "$PVT_ID" ] && [ "$PVT_ID" != "null" ]; then
    tmpcfg="$(mktemp)"
    jq --arg id "$PVT_ID" '.project.projectNodeId=$id' "$CFG_FILE" > "$tmpcfg" && mv "$tmpcfg" "$CFG_FILE"
    echo "Wrote projectNodeId=$PVT_ID into $CFG_FILE"
  else
    echo "Could not resolve projectNodeId automatically; you may need to set it manually: ${EDITOR:-nano} $CFG_FILE" >&2
  fi
  echo
fi
echo "To prepare and execute for this repo:"
echo "  npm run prepare -- --config $CFG_FILE"
echo "  npm run execute -- --config $CFG_FILE"
echo
echo "Or use the helper scripts (see package.json for all options)"
