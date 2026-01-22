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

PROJECT_URL=""

# Determine whether OWNER is an org or a user
ORG_ID=$(gh api graphql -f query='query($login:String!){ organization(login:$login){ id } }' -F login="$OWNER" --jq '.data.organization.id' 2>/dev/null || true)
OWNER_KIND="user"
if [ -n "$ORG_ID" ] && [ "$ORG_ID" != "null" ]; then
  OWNER_KIND="org"
  PROJECT_URL="https://github.com/orgs/$OWNER/projects/$PROJECT_NUMBER"
else
  PROJECT_URL="https://github.com/users/$OWNER/projects/$PROJECT_NUMBER"
fi
CONFIG_NAME="$OWNER-$REPO_NAME"
OUT=${OUT:-"$CONFIGS_DIR/${CONFIG_NAME}.json"}

echo "Discovering ProjectV2 fields for $PROJECT_URL (owner=$OWNER repo=$REPO_NAME)"

# Query project fields directly (avoids needing a sample item and avoids union selection errors).
FIELDS_QUERY_COMMON='fields(first:50){ nodes{ __typename ... on ProjectV2FieldCommon{ id name } ... on ProjectV2SingleSelectField{ id name } ... on ProjectV2IterationField{ id name } } }'

if [ "$OWNER_KIND" = "org" ]; then
  Q_FIELDS="query{ organization(login:\"$OWNER\"){ projectV2(number:$PROJECT_NUMBER){ $FIELDS_QUERY_COMMON } } }"
else
  Q_FIELDS="query{ user(login:\"$OWNER\"){ projectV2(number:$PROJECT_NUMBER){ $FIELDS_QUERY_COMMON } } }"
fi

RESP=$(gh api graphql -f query="$Q_FIELDS")

if [ "$OWNER_KIND" = "org" ]; then
  FIELDS=$(echo "$RESP" | jq -r '.data.organization.projectV2.fields.nodes[]? | select(.id != null and .name != null) | (.id + "|" + (.name|tostring))')
else
  FIELDS=$(echo "$RESP" | jq -r '.data.user.projectV2.fields.nodes[]? | select(.id != null and .name != null) | (.id + "|" + (.name|tostring))')
fi

# Extract field id by fuzzy name match (case-insensitive)
ESTIMATE_FIELD_ID=$(echo "$FIELDS" | grep -i "estimate" | head -1 | cut -d'|' -f1 || true)
STATUS_FIELD_ID=$(echo "$FIELDS" | grep -i "status" | head -1 | cut -d'|' -f1 || true)
PRIORITY_FIELD_ID=$(echo "$FIELDS" | grep -i "priority" | head -1 | cut -d'|' -f1 || true)
START_DATE_FIELD_ID=$(echo "$FIELDS" | grep -i "start" | grep -i "date" | head -1 | cut -d'|' -f1 || true)
END_DATE_FIELD_ID=$(echo "$FIELDS" | grep -i "end" | grep -i "date" | head -1 | cut -d'|' -f1 || true)

echo "Found: estimate=$ESTIMATE_FIELD_ID status=$STATUS_FIELD_ID priority=$PRIORITY_FIELD_ID startDate=$START_DATE_FIELD_ID endDate=$END_DATE_FIELD_ID"

CFG_DIR=$(dirname "$OUT")
mkdir -p "$CFG_DIR"

# Update existing config in-place if it exists; otherwise, create a minimal config.
if [ -f "$OUT" ]; then
  tmpcfg="$(mktemp)"
  jq \
    --arg url "$PROJECT_URL" \
    --argjson number "$PROJECT_NUMBER" \
    --arg status "$STATUS_FIELD_ID" \
    --arg priority "$PRIORITY_FIELD_ID" \
    --arg estimate "$ESTIMATE_FIELD_ID" \
    --arg startDate "$START_DATE_FIELD_ID" \
    --arg endDate "$END_DATE_FIELD_ID" \
    '(.project.url |= (if (. == null or . == "") then $url else . end))
     | (.project.number |= (if (. == null or . == 0) then $number else . end))
     | .project.fieldIds.statusFieldId=$status
     | .project.fieldIds.priorityFieldId=$priority
     | .project.fieldIds.estimateHoursFieldId=$estimate
     | .project.fieldIds.startDateFieldId=$startDate
     | .project.fieldIds.endDateFieldId=$endDate
    ' "$OUT" > "$tmpcfg" && mv "$tmpcfg" "$OUT"
  echo "Updated config: $OUT"
else
  cat > "$OUT" <<EOF
{
  "owner": "$OWNER",
  "repo": "$OWNER/$REPO_NAME",
  "localPath": "/opt/$REPO_NAME",
  "enableProjectSync": true,
  "project": {
    "url": "$PROJECT_URL",
    "number": $PROJECT_NUMBER,
    "projectNodeId": "",
    "fieldIds": {
      "statusFieldId": "$STATUS_FIELD_ID",
      "priorityFieldId": "$PRIORITY_FIELD_ID",
      "estimateHoursFieldId": "$ESTIMATE_FIELD_ID",
      "startDateFieldId": "$START_DATE_FIELD_ID",
      "endDateFieldId": "$END_DATE_FIELD_ID"
    }
  }
}
EOF
  echo "Wrote config: $OUT"
fi

if [ "$OWNER_KIND" = "org" ]; then
  echo "If projectNodeId is required, run: gh api graphql -f query='query{ organization(login:\"$OWNER\"){ projectV2(number:$PROJECT_NUMBER){ id } } }' --jq '.data.organization.projectV2.id'"
else
  echo "If projectNodeId is required, run: gh api graphql -f query='query{ user(login:\"$OWNER\"){ projectV2(number:$PROJECT_NUMBER){ id } } }' --jq '.data.user.projectV2.id'"
fi

exit 0
