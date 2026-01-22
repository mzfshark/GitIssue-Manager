#!/usr/bin/env bash
set -eo pipefail

# Some environments export a `read` shell function/alias which can break scripts that rely on
# the bash builtin `read` (e.g. turning `read -p ...` into an attempt to execute `-p`).
unalias read 2>/dev/null || true
unset -f read 2>/dev/null || true

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_DIR="$ROOT_DIR/sync-helper/configs"
mkdir -p "$CONFIG_DIR"

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Required command '$cmd' not found. Please install or ensure it's in PATH." >&2
    return 1
  fi
  return 0
}

# Global requirements
require_cmd "gh" || exit 1
require_cmd "jq" || exit 1

select_repo_for_owner() {
  local owner="$1"
  require_cmd gh
  require_cmd jq

  printf "Fetching repositories for owner: %s\n" "$owner" >&2
  local err_file
  err_file="$(mktemp)"

  # `gh repo list` works for both users and orgs.
  local raw
  raw=$(gh repo list "$owner" --limit 200 --json name 2>"$err_file" || true)
  local repos
  repos=$(echo "$raw" | jq -r '.[].name' 2>>"$err_file" || true)

  if [ -z "$repos" ]; then
    if [ -s "$err_file" ]; then
      echo "Failed to fetch repositories for $owner:" >&2
      cat "$err_file" >&2
    else
      echo "No repositories found for $owner or error fetching." >&2
    fi
    rm -f "$err_file"
    return 1
  fi

  echo >&2
  echo "Select a repository:" >&2
  local i=1
  local arr=()
  while IFS= builtin read -r line; do
    if [ -z "$line" ] || [ "$line" = "null" ]; then
      continue
    fi
    arr+=("$line")
    printf "  %s) %s\n" "$i" "$line" >&2
    i=$((i + 1))
  done <<< "$repos"

  if [ ${#arr[@]} -eq 0 ]; then
    rm -f "$err_file"
    return 1
  fi

  printf "Enter number [1]: " >&2
  local sel
  builtin read -r sel
  sel=${sel:-1}
  local idx=$((sel - 1))
  if [ $idx -lt 0 ] || [ $idx -ge ${#arr[@]} ]; then
    echo "Invalid selection" >&2
    rm -f "$err_file"
    return 1
  fi

  rm -f "$err_file"
  echo "${arr[$idx]}"
}

list_configured_repos() {
  shopt -s nullglob
  local files=("$CONFIG_DIR"/*.json)
  if [ ${#files[@]} -eq 0 ]; then
    return 1
  fi
  echo "Current Configurations:"
  printf "  %-30s | %-20s\n" "Config ID" "Repository"
  echo "  ------------------------------------------------------------"
  for f in "${files[@]}"; do
    local repo
    repo=$(jq -r '.repo // empty' "$f" 2>/dev/null || echo "???")
    printf "  %-30s | %-20s\n" "$(basename "$f" .json)" "$repo"
  done
  return 0
}

show_config_details() {
  local config_name="$1"
  local f="$CONFIG_DIR/${config_name}.json"
  if [ ! -f "$f" ]; then
    echo "Config not found: $f"
    return 1
  fi

  echo
  echo "--- Configuration: $config_name ---"
  jq -r '"Repo: " + .repo + "\nOwner: " + .owner + "\nLocal Path: " + .localPath + "\nProject Sync: " + (.enableProjectSync|tostring) + "\nProject URL: " + (.project.url // "N/A")' "$f"
  echo "-----------------------------------"
}

select_and_manage_configs() {
  while true; do
    echo
    echo "Select a configuration to manage:"
    local i=1
    local arr=()
    shopt -s nullglob
    local files=("$CONFIG_DIR"/*.json)
    
    for f in "${files[@]}"; do
      local name
      name=$(basename "$f" .json)
      arr+=("$name")
      local repo
      repo=$(jq -r '.repo // empty' "$f" 2>/dev/null || echo "???")
      printf "  %s) %-30s (%s)\n" "$i" "$name" "$repo"
      i=$((i + 1))
    done

    echo "  n) Configure a NEW repository"
    echo "  q) Quit"
    printf "Choice: "
    builtin read -r sel

    if [[ "$sel" == "n" ]]; then
      return 1 # Fall through to new config logic
    fi
    if [[ "$sel" == "q" ]]; then
      exit 0
    fi

    local idx=$((sel - 1))
    if [ $idx -lt 0 ] || [ $idx -ge ${#arr[@]} ]; then
      echo "Invalid selection"
      continue
    fi

    local selected_name="${arr[$idx]}"
    manage_single_config "$selected_name"
  done
}

manage_single_config() {
  local config_name="$1"
  local config_path="$CONFIG_DIR/${config_name}.json"

  while true; do
    show_config_details "$config_name"
    echo "Actions:"
    echo "  1) Prepare (generate metadata & artifacts)"
    echo "  2) Execute (create/sync issues based on artifacts)"
    echo "  3) Edit (open JSON in default editor)"
    echo "  4) Back to configuration list"
    printf "Choice [1]: "
    builtin read -r action
    action=${action:-1}

    case "$action" in
      1)
        echo "Running Prepare for $config_name..."
        node "$ROOT_DIR/client/prepare.js" --config "$config_path"
        ;;
      2)
        echo "Running Execute for $config_name..."
        node "$ROOT_DIR/server/executor.js" --config "$config_path"
        ;;
      3)
        echo "Opening $config_path in editor..."
        ${EDITOR:-nano} "$config_path"
        ;;
      4)
        return 0
        ;;
      *)
        echo "Invalid option"
        ;;
    esac
    echo
    printf "Press Enter to continue..."
    builtin read -r
  done
}

# ... (main entry point later)

is_organization() {
  local owner="${1:-}"
  require_cmd gh
  require_cmd jq

  # Avoid relying on `gh --jq` because in some environments it may return raw JSON (including errors)
  # which breaks downstream logic.
  local raw
  raw=$(gh api graphql -f query="query($login:String!){ organization(login:$login){ id } }" -F login="$owner" 2>/dev/null || true)
  if [ -z "$raw" ]; then
    return 1
  fi

  # If the response contains GraphQL errors, treat as not-an-organization.
  if echo "$raw" | jq -e '.errors and (.errors|length>0)' >/dev/null 2>&1; then
    return 1
  fi

  local id
  id=$(echo "$raw" | jq -r '.data.organization.id // empty' 2>/dev/null || true)
  if [ -n "$id" ] && [ "$id" != "null" ]; then
    return 0
  fi
  return 1
}

owner_type() {
  local owner="${1:-}"
  if command -v gh >/dev/null 2>&1; then
    if is_organization "$owner"; then
      echo "organization"
      return 0
    fi
  fi
  echo "user"
}

extract_project_number_from_url() {
  local url="$1"
  echo "$url" | sed -n 's|.*/projects/\([0-9]\+\).*|\1|p'
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

select_project_for_owner() {
  # returns a line: <number>|<title>|<url>
  # usage: select_project_for_owner <OWNER>
  require_cmd gh
  local owner="${1:-}"
  local err_file
  if [ -z "$owner" ]; then
    echo "select_project_for_owner requires owner argument" >&2
    return 1
  fi

  echo >&2
  printf "Fetching Projects V2 for owner: %s\n" "$owner" >&2
  local raw
  err_file="$(mktemp)"
  # IMPORTANT: Do not query organization(login) when owner is a user.
  # GitHub may emit GraphQL errors/warnings for unknown organizations which can leak to stderr.
  if is_organization "$owner"; then
    raw=$(gh api graphql \
      -f query='query($login:String!){ organization(login:$login){ projectsV2(first:50){nodes{number title url}} } }' \
      -F login="$owner" 2>"$err_file" || true)
    raw=$(echo "$raw" | jq -r '(.data.organization.projectsV2.nodes // []) | map(select(.number != null and .title != null and .url != null)) | map("\(.number)|\(.title)|\(.url)") | .[]' 2>>"$err_file" || true)
  else
    raw=$(gh api graphql \
      -f query='query($login:String!){ user(login:$login){ projectsV2(first:50){nodes{number title url}} } }' \
      -F login="$owner" 2>"$err_file" || true)
    raw=$(echo "$raw" | jq -r '(.data.user.projectsV2.nodes // []) | map(select(.number != null and .title != null and .url != null)) | map("\(.number)|\(.title)|\(.url)") | .[]' 2>>"$err_file" || true)
  fi

  if [ -z "$raw" ]; then
    if [ -s "$err_file" ]; then
      echo "Failed to fetch Projects V2 for $owner:" >&2
      cat "$err_file" >&2
    else
      echo "No projects found for $owner or error fetching." >&2
    fi
    rm -f "$err_file"
    return 1
  fi

  echo >&2
  echo "Select a project:" >&2
  local i=1
  local arr=()
  while IFS= builtin read -r line; do
    if [ -z "$line" ] || [ "$line" = "null" ]; then
      continue
    fi
    arr+=("$line")
    local num
    num=$(echo "$line" | cut -d'|' -f1)
    local title
    title=$(echo "$line" | cut -d'|' -f2)
    printf "  %s) #%s - %s\n" "$i" "$num" "$title" >&2
    i=$((i + 1))
  done <<< "$raw"

  if [ ${#arr[@]} -eq 0 ]; then
    if [ -s "$err_file" ]; then
      echo "Failed to fetch Projects V2 for $owner:" >&2
      cat "$err_file" >&2
    else
      echo "No projects found for $owner or error fetching." >&2
    fi
    rm -f "$err_file"
    return 1
  fi

  printf "Enter number [1]: " >&2
  builtin read -r sel
  sel=${sel:-1}
  local idx=$((sel - 1))
  if [ $idx -lt 0 ] || [ $idx -ge ${#arr[@]} ]; then
    echo "Invalid selection" >&2
    return 1
  fi
  rm -f "$err_file"
  echo "${arr[$idx]}"
}

prompt_project_reference() {
  local owner="$1"
  local owner_kind="$2"
  local project_url=""
  local project_number=""

  echo
  echo "Project reference:"
  echo "  1) List projects via gh and select (owner projects V2)"
  echo "  2) Paste project URL"
  echo "  3) Enter project number (will build URL for the owner)"
  builtin read -r -p "Choose (1/2/3) [1]: " PROJECT_MODE
  PROJECT_MODE=${PROJECT_MODE:-1}

  if [ "$PROJECT_MODE" = "2" ]; then
    local hint
    if [ "$owner_kind" = "organization" ]; then
      hint="https://github.com/orgs/$owner/projects/<id>"
    else
      hint="https://github.com/users/$owner/projects/<id>"
    fi
    builtin read -r -p "Project URL (e.g. $hint): " project_url
    project_number=$(extract_project_number_from_url "$project_url")
    if [ -z "$project_number" ]; then
      echo "Could not extract project number from URL" >&2
      return 1
    fi
  elif [ "$PROJECT_MODE" = "3" ]; then
    builtin read -r -p "Project number: " project_number
    project_url=$(default_project_url_for_owner "$owner" "$project_number")
  else
    if sel=$(select_project_for_owner "$owner" 2>/dev/null); then
      project_number=$(echo "$sel" | cut -d'|' -f1)
      project_url=$(echo "$sel" | cut -d'|' -f3)
    else
      echo "Could not list projects for owner '$owner' (permissions or none). Please paste URL or enter number." >&2
      builtin read -r -p "Project URL (leave empty to enter number): " project_url
      if [ -n "$project_url" ]; then
        project_number=$(extract_project_number_from_url "$project_url")
        if [ -z "$project_number" ]; then
          echo "Could not extract project number from URL" >&2
          return 1
        fi
      else
        builtin read -r -p "Project number: " project_number
        project_url=$(default_project_url_for_owner "$owner" "$project_number")
      fi
    fi
  fi

  echo "$project_url|$project_number"
}

echo "============================================"
echo "  GitIssue-Manager - Repository Setup"
echo "============================================"
echo
echo "TIP: Use 'pnpm run configure' at any time to add a new repository or configuration."
echo

# If we have existing configs, enter management menu.
# select_and_manage_configs will return (fall through) if user chooses to create NEW.
if shopt -s nullglob; files=("$CONFIG_DIR"/*.json); [ ${#files[@]} -gt 0 ]; then
  if ! select_and_manage_configs; then
    # if it returns 1, user chose "Configure a NEW repository"
    SETUP_MODE=1
  else
    exit 0
  fi
else
  echo "No existing configurations found."
  SETUP_MODE=1
fi

echo
echo "=== New Repository Configuration ==="
builtin read -r -p "Owner (GitHub user or organization) [default: mzfshark]: " OWNER
OWNER=${OWNER:-mzfshark}

echo
echo "Repository selection"
echo "  1) List repositories via gh and select"
echo "  2) Type repository name"
builtin read -r -p "Choose (1/2) [1]: " REPO_MODE
REPO_MODE=${REPO_MODE:-1}

REPO_NAME=""
if [ "$REPO_MODE" = "1" ]; then
  if selected_repo=$(select_repo_for_owner "$OWNER"); then
    REPO_NAME="$selected_repo"
  else
    echo "Could not list repositories automatically; falling back to manual entry." >&2
  fi
fi

if [ -z "$REPO_NAME" ]; then
  builtin read -r -p "Repository name (without owner) [default: AragonOSX]: " REPO_NAME
  REPO_NAME=${REPO_NAME:-AragonOSX}
fi

OWNER_TYPE=$(owner_type "$OWNER")
REPO="${OWNER}/${REPO_NAME}"
echo "Full repo: $REPO"
echo

SUGGESTED_LOCAL_PATH="/opt/${REPO_NAME}"
builtin read -r -p "Local path to scan for *.md [default: ${SUGGESTED_LOCAL_PATH}]: " LOCAL_PATH
LOCAL_PATH=${LOCAL_PATH:-$SUGGESTED_LOCAL_PATH}

echo
echo "=== Project Sync Configuration ==="
builtin read -r -p "Enable Project sync for this repo? [y/N]: " ENABLE_PROJECT_SYNC
ENABLE_PROJECT_SYNC=${ENABLE_PROJECT_SYNC:-N}

PROJECT_URL=""
PROJECT_NUMBER=0

if [[ "$ENABLE_PROJECT_SYNC" =~ ^[Yy]$ ]]; then
  require_cmd gh
  echo
  echo "Project selection (owner Projects V2 — detected: $OWNER_TYPE)"
  echo "  1) List projects via gh and select"
  echo "  2) Paste project URL (https://github.com/users/<user>/projects/<id>)"
  builtin read -r -p "Choose (1/2) [1]: " PROJECT_MODE
  PROJECT_MODE=${PROJECT_MODE:-1}

  if [ "$PROJECT_MODE" = "2" ]; then
    builtin read -r -p "Project URL: " PROJECT_URL
    PROJECT_NUMBER=$(extract_project_number_from_url "$PROJECT_URL")
    if [ -z "$PROJECT_NUMBER" ]; then
      echo "Could not extract project number from URL" >&2
      exit 1
    fi
  else
    if sel=$(select_project_for_owner "$OWNER"); then
      PROJECT_NUMBER=$(echo "$sel" | cut -d'|' -f1)
      PROJECT_URL=$(echo "$sel" | cut -d'|' -f3)
    else
      echo "Could not list projects automatically; please paste a project URL." >&2
      builtin read -r -p "Project URL: " PROJECT_URL
      PROJECT_NUMBER=$(extract_project_number_from_url "$PROJECT_URL")
      if [ -z "$PROJECT_NUMBER" ]; then
        echo "Could not extract project number from URL" >&2
        exit 1
      fi
    fi
  fi
else
  echo
  builtin read -r -p "Store a custom Project reference for metadata anyway? (y/N): " STORE_PROJECT
  STORE_PROJECT=${STORE_PROJECT:-N}
  if [[ "$STORE_PROJECT" =~ ^[Yy]$ ]]; then
    require_cmd gh
    project_ref=$(prompt_project_reference "$OWNER" "$OWNER_TYPE")
    PROJECT_URL=$(echo "$project_ref" | cut -d'|' -f1)
    PROJECT_NUMBER=$(echo "$project_ref" | cut -d'|' -f2)
  fi
fi

builtin read -r -p "Default estimate hours per subtask (default 1): " DEFAULT_ESTIMATE
DEFAULT_ESTIMATE=${DEFAULT_ESTIMATE:-1}
builtin read -r -p "Default priority (e.g., URGENT, HIGH, NORMAL) [NORMAL]: " DEFAULT_PRIORITY
DEFAULT_PRIORITY=${DEFAULT_PRIORITY:-NORMAL}
builtin read -r -p "Default status [TODO]: " DEFAULT_STATUS
DEFAULT_STATUS=${DEFAULT_STATUS:-TODO}
builtin read -r -p "Default start date [TBD]: " DEFAULT_START_DATE
DEFAULT_START_DATE=${DEFAULT_START_DATE:-TBD}
builtin read -r -p "Default end date [TBD]: " DEFAULT_END_DATE
DEFAULT_END_DATE=${DEFAULT_END_DATE:-TBD}
builtin read -r -p "Default labels (comma-separated) [plan]: " DEFAULT_LABELS
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

CONFIG_NAME="${OWNER}-${REPO_NAME}"
CFG_FILE="$CONFIG_DIR/${CONFIG_NAME}.json"

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

echo "Created $CFG_FILE"
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

  bash "$ROOT_DIR/sync-helper/discover-project-fields.sh" --owner "$OWNER" --repo "$REPO_NAME" --project-number $PROJECT_NUMBER --out "$CFG_FILE" || {
    echo "Field discovery script failed; leaving generated config for manual edit." >&2
  }

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
