#!/usr/bin/env bash
set -eo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_DIR="$ROOT_DIR/sync-helper/configs"
mkdir -p "$CONFIG_DIR"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

list_configured_repos() {
  if [ ! -d "$CONFIG_DIR" ] || [ -z "$(ls -A "$CONFIG_DIR" 2>/dev/null)" ]; then
    return 1
  fi
  echo "Configured repositories:"
  local i=1
  for cfg in "$CONFIG_DIR"/*.json; do
    [ -f "$cfg" ] || continue
    local basename=$(basename "$cfg" .json)
    echo "  $i) $basename"
    i=$((i+1))
  done
  return 0
}

select_project_via_gh() {
  # returns a line: <number>|<title>|<url>
  require_cmd gh

  echo
  echo "Fetching your Projects (Projects V2)..."
  local raw
  raw=$(gh api graphql -f query='query{viewer{projectsV2(first:20){nodes{number title url}}}}' --jq '.data.viewer.projectsV2.nodes[]|"\(.number)|\(.title)|\(.url)"')
  
  if [ -z "$raw" ]; then
    echo "No projects found or error fetching." >&2
    exit 1
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
    exit 1
  fi
  echo "${arr[$idx]}"
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
  echo "Project selection (user projects V2):"
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
    sel=$(select_project_via_gh)
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
    echo "  1) List projects via gh and select"
    echo "  2) Paste project URL"
    echo "  3) Enter project number (will use your viewer login to build URL)"
    read -p "Choose (1/2/3) [1]: " PROJECT_MODE
    PROJECT_MODE=${PROJECT_MODE:-1}

    if [ "$PROJECT_MODE" = "2" ]; then
      read -p "Project URL: " PROJECT_URL
      PROJECT_NUMBER=$(extract_project_number_from_url "$PROJECT_URL")
      if [ -z "$PROJECT_NUMBER" ]; then
        echo "Could not extract project number from URL" >&2
        exit 1
      fi
    elif [ "$PROJECT_MODE" = "3" ]; then
      read -p "Project number: " PROJECT_NUMBER
      VIEWER=$(get_viewer_login)
      if [ -z "$VIEWER" ]; then
        echo "Could not resolve viewer login via gh" >&2
        exit 1
      fi
      PROJECT_URL=$(default_project_url_for_user "$VIEWER" "$PROJECT_NUMBER")
    else
      sel=$(select_project_via_gh)
      PROJECT_NUMBER=$(echo "$sel" | cut -d'|' -f1)
      PROJECT_URL=$(echo "$sel" | cut -d'|' -f3)
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
  echo "⚠️  Next: edit the config file to set Project field IDs:"
  echo "    ${EDITOR:-nano} $CFG_FILE"
  echo
fi
echo "To prepare and execute for this repo:"
echo "  npm run prepare -- --config $CFG_FILE"
echo "  npm run execute -- --config $CFG_FILE"
echo
echo "Or use the helper scripts (see package.json for all options)"
