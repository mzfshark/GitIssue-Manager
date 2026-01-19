#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGS_DIR="$ROOT_DIR/sync-helper/configs"
mkdir -p "$CONFIGS_DIR"

usage() {
  cat <<EOF
Usage: $0 --owner <owner> --repo <repo> --project-number <n> [--out <config-path>]

Discover ProjectV2 field node IDs (Estimate, Status, Priority) and write a config JSON.
Requires: gh, jq
EOF
  exit 1
}

require_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "Missing: $1" >&2; exit 2; } }
require_cmd gh
require_cmd jq

OWNER=""
REPO_NAME=""
PROJECT_NUMBER=""
OUT=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --owner) OWNER="$2"; shift 2;;
    --repo) REPO_NAME="$2"; shift 2;;
    --project-number) PROJECT_NUMBER="$2"; shift 2;;
    --out) OUT="$2"; shift 2;;
    -h|--help) usage;;
    *) echo "Unknown arg: $1" >&2; usage;;
  esac
done

if [ -z "$OWNER" ] || [ -z "$REPO_NAME" ] || [ -z "$PROJECT_NUMBER" ]; then
  usage
fi

VIEWER_LOGIN="$OWNER"
PROJECT_URL=""
ITEM_ID=""

# Try organization first, then user
Q_ORG="query{ organization(login:\"$OWNER\"){ projectV2(number:$PROJECT_NUMBER){ items(first:1){ nodes{ id } } } } }"
ITEM_ID=$(gh api graphql -f query="$Q_ORG" --jq '.data.organization.projectV2.items.nodes[0].id' 2>/dev/null || true)
if [ -n "$ITEM_ID" ] && [ "$ITEM_ID" != "null" ]; then
  PROJECT_URL="https://github.com/orgs/$OWNER/projects/$PROJECT_NUMBER"
else
  Q_USER="query{ user(login:\"$OWNER\"){ projectV2(number:$PROJECT_NUMBER){ items(first:1){ nodes{ id } } } } }"
  ITEM_ID=$(gh api graphql -f query="$Q_USER" --jq '.data.user.projectV2.items.nodes[0].id' 2>/dev/null || true)
  if [ -n "$ITEM_ID" ] && [ "$ITEM_ID" != "null" ]; then
    PROJECT_URL="https://github.com/users/$OWNER/projects/$PROJECT_NUMBER"
  fi
fi
CONFIG_NAME="$OWNER-$REPO_NAME"
OUT=${OUT:-"$CONFIGS_DIR/${CONFIG_NAME}.json"}

echo "Discovering ProjectV2 fields for $PROJECT_URL (owner=$OWNER repo=$REPO_NAME)"

# Get first project item id
Q1="query{ user(login:\"$VIEWER_LOGIN\"){ projectV2(number:$PROJECT_NUMBER){ items(first:1){ nodes{ id } } } } }"
ITEM_ID=$(gh api graphql -f query="$Q1" --jq '.data.user.projectV2.items.nodes[0].id')
if [ -z "$ITEM_ID" ] || [ "$ITEM_ID" = "null" ]; then
  echo "No project items found or failed to resolve item id for owner '$OWNER' project #$PROJECT_NUMBER" >&2
  exit 3
fi

echo "Sample project item: $ITEM_ID"

# Query fieldValues for that item and extract fields
Q2="query{ node(id:\"$ITEM_ID\"){ ... on ProjectV2Item{ id fieldValues(first:50){ nodes{ __typename ... on ProjectV2ItemFieldNumberValue{ number field{ id name } } ... on ProjectV2ItemFieldTextValue{ text field{ id name } } ... on ProjectV2ItemFieldSingleSelectValue{ optionId field{ id name } } } } } } }"
RESP=$(gh api graphql -f query="$Q2")

# Extract field id by fuzzy name match (case-insensitive)
ESTIMATE_FIELD_ID=$(echo "$RESP" | jq -r '.data.node.fieldValues.nodes[] | select(.field!=null) | .field as $f | ($f.id + "|" + ($f.name|tostring))' | grep -i "estimate" | head -1 | cut -d'|' -f1 || true)
STATUS_FIELD_ID=$(echo "$RESP" | jq -r '.data.node.fieldValues.nodes[] | select(.field!=null) | .field as $f | ($f.id + "|" + ($f.name|tostring))' | grep -i "status" | head -1 | cut -d'|' -f1 || true)
PRIORITY_FIELD_ID=$(echo "$RESP" | jq -r '.data.node.fieldValues.nodes[] | select(.field!=null) | .field as $f | ($f.id + "|" + ($f.name|tostring))' | grep -i "priority" | head -1 | cut -d'|' -f1 || true)

echo "Found: estimate=$ESTIMATE_FIELD_ID status=$STATUS_FIELD_ID priority=$PRIORITY_FIELD_ID"

CFG_DIR=$(dirname "$OUT")
mkdir -p "$CFG_DIR"

cat > "$OUT" <<EOF
{
  "owner": "$OWNER",
  "repo": "$OWNER/$REPO_NAME",
  "localPath": "../$REPO_NAME",
  "enableProjectSync": true,
  "project": {
    "url": "$PROJECT_URL",
    "number": $PROJECT_NUMBER,
    "projectNodeId": "",
    "fieldIds": {
      "statusFieldId": "$STATUS_FIELD_ID",
      "priorityFieldId": "$PRIORITY_FIELD_ID",
      "estimateHoursFieldId": "$ESTIMATE_FIELD_ID",
      "startDateFieldId": "",
      "endDateFieldId": ""
    }
  },
  "defaults": {
    "defaultEstimateHours": 1,
    "defaultPriority": "NORMAL",
    "defaultStatus": "TODO",
    "defaultStartDate": "TBD",
    "defaultEndDate": "TBD",
    "defaultLabels": [ "plan" ]
  },
  "outputs": {
    "tasksPath": "./tmp/$CONFIG_NAME/tasks.json",
    "subtasksPath": "./tmp/$CONFIG_NAME/subtasks.json",
    "engineInputPath": "./tmp/$CONFIG_NAME/engine-input.json",
    "engineOutputPath": "./tmp/$CONFIG_NAME/engine-output.json"
  }
}
EOF

echo "Wrote config: $OUT"
if [[ "$PROJECT_URL" == *"/orgs/"* ]]; then
  echo "If projectNodeId is required, run: gh api graphql -f query='query{ organization(login:\"$OWNER\"){ projectV2(number:$PROJECT_NUMBER){ id } } }' --jq '.data.organization.projectV2.id'"
else
  echo "If projectNodeId is required, run: gh api graphql -f query='query{ user(login:\"$OWNER\"){ projectV2(number:$PROJECT_NUMBER){ id } } }' --jq '.data.user.projectV2.id'"
fi

exit 0
