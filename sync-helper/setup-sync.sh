#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CFG_FILE="$ROOT_DIR/sync-helper/sync-config.json"

echo "Sync helper setup"
read -p "Repo (default mzfshark/REPO_NAME): " REPO
REPO=${REPO:-mzfshark/REPO_NAME}
read -p "Project number (default 15): " PROJECT_NUMBER
PROJECT_NUMBER=${PROJECT_NUMBER:-15}
read -p "Default estimate hours per subtask (default 1): " DEFAULT_ESTIMATE
DEFAULT_ESTIMATE=${DEFAULT_ESTIMATE:-1}
read -p "Path for tasks.json (default ./tmp/tasks.json): " TASKS_PATH
TASKS_PATH=${TASKS_PATH:-./tmp/tasks.json}
read -p "Path for subtasks.json (default ./tmp/subtasks.json): " SUBTASKS_PATH
SUBTASKS_PATH=${SUBTASKS_PATH:-./tmp/subtasks.json}

echo
echo "Will write config to: $CFG_FILE"
mkdir -p "$(dirname "$CFG_FILE")"
cat > "$CFG_FILE" <<EOF
{
  "repo": "$REPO",
  "projectNumber": $PROJECT_NUMBER,
  "defaultEstimateHours": $DEFAULT_ESTIMATE,
  "tasksPath": "$TASKS_PATH",
  "subtasksPath": "$SUBTASKS_PATH",
  "projectFieldIds": {
    "statusFieldId": "",
    "priorityFieldId": "",
    "estimateFieldId": "251668000",
    "startDateFieldId": "",
    "endDateFieldId": ""
  }
}
EOF

echo "Created $CFG_FILE"
echo "Next: edit the file and set your field IDs and ensure GH_PAT is available as env or secret."
