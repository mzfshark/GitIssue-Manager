#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CFG_FILE="$ROOT_DIR/sync-helper/sync-config.json"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

select_project_via_gh() {
  # returns a line: <number>|<title>|<url>
  require_cmd gh

  echo
  echo "Fetching your Projects (Projects V2)..."
  local raw
  raw=$(gh api graphql -f query='query($n:Int!){ viewer { login projectsV2(first:$n){ nodes { number title url } } } }' -f variables='{"n":50}' --jq '.data.viewer.projectsV2.nodes[] | "\(.number)|\(.title)|\(.url)"' 2>/dev/null || true)
  if [ -z "$raw" ]; then
    echo "No projects found (or missing permissions)." >&2
    return 1
  fi

  echo
  echo "Available projects:"
  echo "$raw" | awk -F'|' '{ printf "  [%s] %s\n", $1, $2 }'
  echo
  read -p "Select project number: " sel
  if [ -z "$sel" ]; then
    echo "No project selected" >&2
    return 1
  fi

  echo "$raw" | awk -F'|' -v n="$sel" '$1==n {print $0; found=1} END{exit found?0:1}'
}

extract_project_number_from_url() {
  local url="$1"
  # https://github.com/users/<user>/projects/<id>
  echo "$url" | sed -nE 's#^https://github.com/users/[^/]+/projects/([0-9]+).*$#\1#p'
}

default_project_url_for_user() {
  local user="$1"
  local number="$2"
  echo "https://github.com/users/${user}/projects/${number}"
}

get_viewer_login() {
  require_cmd gh
  gh api graphql -f query='query{ viewer{ login } }' --jq '.data.viewer.login' 2>/dev/null || true
}

echo "Sync helper setup"
read -p "Target repo (default mzfshark/REPO_NAME): " REPO
REPO=${REPO:-mzfshark/REPO_NAME}
read -p "Local path to scan for *.md (default .): " LOCAL_PATH
LOCAL_PATH=${LOCAL_PATH:-.}

read -p "Enable Project sync for this repo? (y/N): " ENABLE_PROJECT_SYNC
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
read -p "Output tasks.json path (default ./tmp/tasks.json): " TASKS_PATH
TASKS_PATH=${TASKS_PATH:-./tmp/tasks.json}
read -p "Output subtasks.json path (default ./tmp/subtasks.json): " SUBTASKS_PATH
SUBTASKS_PATH=${SUBTASKS_PATH:-./tmp/subtasks.json}
read -p "Output engine-input.json path (default ./tmp/engine-input.json): " ENGINE_INPUT_PATH
ENGINE_INPUT_PATH=${ENGINE_INPUT_PATH:-./tmp/engine-input.json}

echo
echo "Will write config to: $CFG_FILE"
mkdir -p "$(dirname "$CFG_FILE")"
cat > "$CFG_FILE" <<EOF
{
  "owner": "mzfshark",
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
    "defaultEstimateHours": $DEFAULT_ESTIMATE
  },
  "targets": [
    {
      "repo": "$REPO",
      "localPath": "$LOCAL_PATH",
      "enableProjectSync": $( [[ "$ENABLE_PROJECT_SYNC" =~ ^[Yy]$ ]] && echo true || echo false ),
      "outputs": {
        "tasksPath": "$TASKS_PATH",
        "subtasksPath": "$SUBTASKS_PATH",
        "engineInputPath": "$ENGINE_INPUT_PATH"
      }
    }
  ]
}
EOF

echo "Created $CFG_FILE"
echo "Next: edit the file and set your field IDs and ensure GH_PAT is available as env or secret."
