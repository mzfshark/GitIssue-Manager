#!/bin/bash
set -euo pipefail

MANAGER_PATH="/opt/GitIssue-Manager"
LOG_FILE="${LOG_FILE:-/var/log/gitissuer/daemon-$(date +%Y%m%d).log}"

# Default values
repo_path=""
repo_owner=""
repo_name=""
auto_deploy="false"
config_path=""

# Simple CLI parsing to accept: --repo <path> [--auto-deploy]
while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)
      shift
      config_path="$1"
      shift
      ;;
    --repo)
      shift
      repo_path="$1"
      shift
      ;;
    --auto-deploy)
      auto_deploy="true"
      shift
      ;;
    --owner)
      shift
      repo_owner="$1"
      shift
      ;;
    --name)
      shift
      repo_name="$1"
      shift
      ;;
    -h|--help)
      echo "Usage: $(basename "$0") --repo <path> [--auto-deploy] [--owner <owner>] [--name <name>]"
      exit 0
      ;;
    *)
      # accept plain positional repo path as fallback
      if [[ -z "$repo_path" ]]; then
        repo_path="$1"
        shift
      else
        shift
      fi
      ;;
  esac
done

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: Missing dependency: $cmd" >&2
    exit 1
  fi
}

resolve_from_config() {
  require_cmd jq

  if [[ -z "$config_path" ]]; then
    return 0
  fi
  if [[ ! -f "$config_path" ]]; then
    echo "ERROR: --config file not found: $config_path" >&2
    exit 2
  fi

  local repo_full
  repo_full=$(jq -r '.repo // empty' "$config_path")
  if [[ -n "$repo_full" && "$repo_full" == */* ]]; then
    [[ -z "$repo_owner" ]] && repo_owner="${repo_full%%/*}"
    [[ -z "$repo_name" ]] && repo_name="${repo_full##*/}"
  fi

  local local_path
  local_path=$(jq -r '.localPath // empty' "$config_path")
  if [[ -z "$repo_path" && -n "$local_path" ]]; then
    # localPath is relative to GitIssue-Manager root in /opt unless absolute.
    if [[ "$local_path" = /* ]]; then
      repo_path="$local_path"
    else
      repo_path="$MANAGER_PATH/$local_path"
    fi
  fi

  # Default auto_deploy from config if not explicitly set
  if [[ "$auto_deploy" != "true" ]]; then
    local cfg_auto
    cfg_auto=$(jq -r '.gitissuer.autoDeploy // true' "$config_path")
    if [[ "$cfg_auto" == "true" ]]; then
      auto_deploy="true"
    fi
  fi
}

resolve_from_config

# Derive repo_name and repo_owner if missing
if [[ -n "$repo_path" && -z "$repo_name" ]]; then
  repo_name=$(basename "$repo_path")
fi
if [[ -n "$repo_path" && -z "$repo_owner" ]]; then
  # Try to read git remote origin to infer owner
  if [[ -d "$repo_path/.git" ]]; then
    remote_url=$(git -C "$repo_path" remote get-url origin 2>/dev/null || true)
    if [[ -n "$remote_url" ]]; then
      # support git@github.com:owner/repo.git and https://github.com/owner/repo.git
      if [[ "$remote_url" =~ [:/]+([^/]+)/[^/]+(\.git)?$ ]]; then
        repo_owner=${BASH_REMATCH[1]}
      fi
    fi
  fi
fi

# Final sanity check
if [[ -z "$repo_path" ]]; then
  echo "ERROR: --repo <path> is required" >&2
  exit 2
fi

log() {
  local level="$1"
  shift
  local msg="$*"
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$timestamp] [$level] $msg" | tee -a "$LOG_FILE"
}

run_cmd() {
  local label="$1"
  shift
  log "INFO" "$label"
  if "$@" >>"$LOG_FILE" 2>&1; then
    log "INFO" "SUCCESS: $label"
    return 0
  fi
  log "ERROR" "FAILED: $label"
  return 1
}

if [[ ! -d "$repo_path" ]]; then
  log "ERROR" "Repository path not found: $repo_path"
  exit 1
fi

if [[ ! -d "$repo_path/.git" ]]; then
  log "ERROR" "Not a git repository: $repo_path"
  exit 1
fi

cd "$repo_path"

mkdir -p ".gitissuer"
updates_dir=".gitissuer/updates"
mkdir -p "$updates_dir"
repo_state_file=".gitissuer/state.json"

gitignore_file="$repo_path/.gitignore"
if [[ -f "$gitignore_file" ]]; then
  if ! grep -q "^\.gitissuer/state\.json$" "$gitignore_file"; then
    echo ".gitissuer/state.json" >>"$gitignore_file"
  fi
else
  echo ".gitissuer/state.json" >"$gitignore_file"
fi

cat >"$repo_state_file" <<EOF
{
  "last_run": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "status": "processing",
  "steps": ["add", "prepare", "deploy", "registry", "apply", "e2e"],
  "repo": "${repo_owner}/${repo_name}"
}
EOF

if [[ ! -f "ISSUE_UPDATES.md" ]]; then
  log "WARN" "ISSUE_UPDATES.md not found in $repo_path"
  cat >"$repo_state_file" <<EOF
{
  "last_run": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "status": "skipped",
  "reason": "ISSUE_UPDATES.md not found",
  "repo": "${repo_owner}/${repo_name}"
}
EOF
  exit 0
fi

update_file="$updates_dir/${repo_name}_$(date +%Y%m%d_%H%M%S)_UPDATE.md"
run_cmd "Step 1/6: ADD - Load updates" \
  /bin/bash "$MANAGER_PATH/scripts/gitissuer.sh" add --file ISSUE_UPDATES.md --output "$update_file"

run_cmd "Step 2/6: PREPARE - Validate changes (dry-run)" \
  /bin/bash "$MANAGER_PATH/scripts/gitissuer.sh" prepare --repo "${repo_owner}/${repo_name}" ${config_path:+--config "$config_path"} --dry-run || true

if [[ "$auto_deploy" == "true" ]]; then
  run_cmd "Step 3/6: DEPLOY - Apply changes" \
    /bin/bash "$MANAGER_PATH/scripts/gitissuer.sh" deploy --repo "${repo_owner}/${repo_name}" ${config_path:+--config "$config_path"} --batch --confirm

  run_cmd "Step 4/6: REGISTRY - Update per-repo registry" \
    /bin/bash "$MANAGER_PATH/scripts/gitissuer.sh" registry:update --repo "${repo_owner}/${repo_name}" ${config_path:+--config "$config_path"}

  run_cmd "Step 5/6: APPLY - Validate ISSUE_UPDATES (dry-run)" \
    /bin/bash "$MANAGER_PATH/scripts/gitissuer.sh" apply --repo "${repo_owner}/${repo_name}" ${config_path:+--config "$config_path"} --dry-run || true

  run_cmd "Step 6/6: E2E - Run validation" \
    /bin/bash "$MANAGER_PATH/scripts/gitissuer.sh" e2e:run --repo "${repo_owner}/${repo_name}" ${config_path:+--config "$config_path"} --non-interactive --dry-run || true
else
  log "INFO" "AUTO_DEPLOY disabled for ${repo_owner}/${repo_name}. Skipping deploy and e2e."
fi

cat >"$repo_state_file" <<EOF
{
  "last_run": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "status": "success",
  "steps": ["add", "prepare", "deploy", "registry", "apply", "e2e"],
  "auto_deploy": $auto_deploy,
  "repo": "${repo_owner}/${repo_name}"
}
EOF
