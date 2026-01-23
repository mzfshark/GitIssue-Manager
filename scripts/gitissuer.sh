#!/usr/bin/env bash
set -euo pipefail

# Minimal GitIssuer wrapper to support daemon steps.
# Commands: add, prepare, deploy, registry:update, apply, e2e:run, link:hierarchy

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_DIR="$PROJECT_ROOT/sync-helper/configs"

usage() {
  cat <<'EOF'
Usage: gitissuer.sh <command> [options]

Commands:
  add --file <path> --output <path>        Copy ISSUE_UPDATES.md into a timestamped update file
  prepare --repo <owner/name> [--config <path>] [--dry-run]
                                           Generate engine input from Markdown plans
  deploy --repo <owner/name> [--config <path>] [--batch] --confirm [--link-hierarchy|--no-link-hierarchy] [--parent-number <n>] [--replace-parent]
                                           Execute GitHub writes (issues + optional ProjectV2)
  registry:update --repo <owner/name> [--config <path>]
                                           Update per-repo registry from engine-input + engine-output
  apply --repo <owner/name> [--config <path>] [--file <ISSUE_UPDATES.md>] [--dry-run|--confirm]
                                           Parse bounded updates section and apply safe actions using the registry
  e2e:run --repo <owner/name> [--config <path>] [--dry-run] [--non-interactive]
                                           Run E2E validation flow (dry-run by default)
  link:hierarchy --repo <owner/name> [--config <path>] [--parent-number <n>] [--metadata-file <path>] [--engine-output-file <path>] [--dry-run|--confirm] [--replace-parent] [--non-interactive]
                                           Link parent↔child hierarchy using E2E stage 5 only
EOF
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: Missing dependency: $cmd" >&2
    exit 1
  fi
}

resolve_config_path() {
  local repo_full="$1"
  local config_path="${2:-}"

  if [[ -n "$config_path" ]]; then
    if [[ -f "$config_path" ]]; then
      printf '%s' "$config_path"
      return 0
    fi
    echo "ERROR: Config file not found: $config_path" >&2
    return 1
  fi

  if [[ -z "$repo_full" || "$repo_full" != */* ]]; then
    echo "ERROR: --repo <owner/name> is required" >&2
    return 1
  fi

  local owner="${repo_full%%/*}"
  local name="${repo_full##*/}"
  local guessed="$CONFIG_DIR/${owner}-${name}.json"
  if [[ -f "$guessed" ]]; then
    printf '%s' "$guessed"
    return 0
  fi

  # Fallback: scan configs by .repo match
  local repo_full_lc
  repo_full_lc="$(printf '%s' "$repo_full" | tr '[:upper:]' '[:lower:]')"
  local cfg
  for cfg in "$CONFIG_DIR"/*.json; do
    [[ -f "$cfg" ]] || continue
    local r
    r=$(jq -r '.repo // empty' "$cfg" 2>/dev/null || true)
    if [[ -n "$r" ]]; then
      local r_lc
      r_lc="$(printf '%s' "$r" | tr '[:upper:]' '[:lower:]')"
      if [[ "$r_lc" == "$repo_full_lc" ]]; then
      printf '%s' "$cfg"
      return 0
      fi
    fi
  done

  echo "ERROR: Unable to resolve sync config for repo: $repo_full" >&2
  echo "HINT: Expected $guessed or a config with .repo == '$repo_full'" >&2
  return 1
}

cmd_add() {
  local input_file=""
  local output_file=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --file) input_file="$2"; shift 2 ;;
      --output) output_file="$2"; shift 2 ;;
      -h|--help) usage; exit 0 ;;
      *) echo "ERROR: Unknown arg: $1"; usage; exit 1 ;;
    esac
  done

  if [[ -z "$input_file" || -z "$output_file" ]]; then
    echo "ERROR: --file and --output are required" >&2
    exit 2
  fi

  if [[ ! -f "$input_file" ]]; then
    echo "ERROR: Input file not found: $input_file" >&2
    exit 3
  fi

  mkdir -p "$(dirname "$output_file")"
  cp "$input_file" "$output_file"
  echo "OK: Update file written to $output_file"
}

cmd_prepare() {
  require_cmd node
  require_cmd jq

  local repo_full=""
  local config_path=""
  local dry_run="false"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo) repo_full="$2"; shift 2 ;;
      --config) config_path="$2"; shift 2 ;;
      --dry-run) dry_run="true"; shift ;;
      -h|--help) usage; exit 0 ;;
      *) echo "ERROR: Unknown arg: $1"; usage; exit 1 ;;
    esac
  done

  local cfg
  cfg=$(resolve_config_path "$repo_full" "$config_path")

  # prepare.js already is deterministic; dry-run is informational for compatibility.
  node "$PROJECT_ROOT/client/prepare.js" --config "$cfg"
  if [[ "$dry_run" == "true" ]]; then
    echo "OK: prepare (dry-run) completed for $repo_full"
  else
    echo "OK: prepare completed for $repo_full"
  fi
}

cmd_deploy() {
  require_cmd node
  require_cmd jq
  require_cmd gh

  local repo_full=""
  local config_path=""
  local confirm="false"
  local link_hierarchy="true"
  local parent_number=""
  local replace_parent="false"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo) repo_full="$2"; shift 2 ;;
      --config) config_path="$2"; shift 2 ;;
      --confirm) confirm="true"; shift ;;
      --link-hierarchy) link_hierarchy="true"; shift ;;
      --no-link-hierarchy) link_hierarchy="false"; shift ;;
      --parent-number) parent_number="$2"; shift 2 ;;
      --replace-parent) replace_parent="true"; shift ;;
      --batch) shift ;; # accepted for compatibility; executor is non-interactive
      -h|--help) usage; exit 0 ;;
      *) echo "ERROR: Unknown arg: $1"; usage; exit 1 ;;
    esac
  done

  if [[ "$confirm" != "true" ]]; then
    echo "ERROR: Refusing to deploy without --confirm" >&2
    exit 2
  fi

  local cfg
  cfg=$(resolve_config_path "$repo_full" "$config_path")
  node "$PROJECT_ROOT/server/executor.js" --config "$cfg"
  echo "OK: deploy completed for $repo_full"

  # Natural flow: link hierarchy right after deploy (when confirmed), if we can resolve the parent.
  if [[ "$link_hierarchy" == "true" ]]; then
    if [[ -z "$parent_number" ]]; then
      parent_number=$(jq -r '.gitissuer.hierarchy.parentIssueNumber // .gitissuer.parentIssueNumber // empty' "$cfg" 2>/dev/null || true)
    fi

    if [[ -z "$parent_number" || "$parent_number" == "null" ]]; then
      echo "WARN: link-hierarchy skipped: missing parent issue number." >&2
      echo "HINT: Provide --parent-number <n>, set gitissuer.hierarchy.parentIssueNumber in $cfg, or run manually:" >&2
      echo "      gitissuer link-hierarchy --repo $repo_full --parent-number <n> --confirm" >&2
      return 0
    fi

    echo "INFO: Linking hierarchy under parent #$parent_number..." >&2

    local -a link_args=(--repo "$repo_full" --parent-number "$parent_number" --confirm --non-interactive)
    if [[ "$replace_parent" == "true" ]]; then
      link_args+=(--replace-parent)
    fi
    cmd_link_hierarchy "${link_args[@]}"
    echo "OK: hierarchy linked for $repo_full" >&2
  fi
}

cmd_registry_update() {
  require_cmd node

  local repo_full=""
  local config_path=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo) repo_full="$2"; shift 2 ;;
      --config) config_path="$2"; shift 2 ;;
      -h|--help) usage; exit 0 ;;
      *) echo "ERROR: Unknown arg: $1"; usage; exit 1 ;;
    esac
  done

  local cfg
  cfg=$(resolve_config_path "$repo_full" "$config_path")
  node "$PROJECT_ROOT/server/registry-update.js" --config "$cfg"
  echo "OK: registry updated for $repo_full"
}

cmd_apply() {
  require_cmd node
  require_cmd gh

  local repo_full=""
  local config_path=""
  local file_path=""
  local confirm="false"
  local dry_run="true"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo) repo_full="$2"; shift 2 ;;
      --config) config_path="$2"; shift 2 ;;
      --file) file_path="$2"; shift 2 ;;
      --confirm) confirm="true"; dry_run="false"; shift ;;
      --dry-run) dry_run="true"; shift ;;
      -h|--help) usage; exit 0 ;;
      *) echo "ERROR: Unknown arg: $1"; usage; exit 1 ;;
    esac
  done

  local cfg
  cfg=$(resolve_config_path "$repo_full" "$config_path")

  local args=("--config" "$cfg")
  if [[ -n "$file_path" ]]; then
    args+=("--file" "$file_path")
  fi
  if [[ "$confirm" == "true" ]]; then
    args+=("--confirm")
  else
    args+=("--dry-run")
  fi

  node "$PROJECT_ROOT/server/apply-issue-updates.js" "${args[@]}"
  if [[ "$dry_run" == "true" ]]; then
    echo "OK: apply (dry-run) completed for $repo_full"
  else
    echo "OK: apply completed for $repo_full"
  fi
}

cmd_e2e() {
  require_cmd bash
  require_cmd jq
  require_cmd gh

  local repo_full=""
  local config_path=""
  local dry_run="true"
  local non_interactive="true"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo) repo_full="$2"; shift 2 ;;
      --config) config_path="$2"; shift 2 ;;
      --dry-run) dry_run="true"; shift ;;
      --confirm) dry_run="false"; shift ;;
      --non-interactive) non_interactive="true"; shift ;;
      -h|--help) usage; exit 0 ;;
      *) echo "ERROR: Unknown arg: $1"; usage; exit 1 ;;
    esac
  done

  # If config was provided, validate it resolves, even though e2e flow will re-resolve by repo.
  if [[ -n "$config_path" ]]; then
    resolve_config_path "$repo_full" "$config_path" >/dev/null
  fi

  local args=("--repo" "$repo_full")
  if [[ "$non_interactive" == "true" ]]; then
    args+=("--non-interactive")
  fi
  if [[ "$dry_run" == "true" ]]; then
    args+=("--dry-run")
  fi

  bash "$PROJECT_ROOT/scripts/e2e-flow-v2.sh" "${args[@]}"
}

cmd_link_hierarchy() {
  local repo_full=""
  local config_path=""
  local dry_run="true"
  local non_interactive="true"

  local parent_number=""
  local metadata_file=""
  local engine_output_file=""
  local replace_parent="false"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo) repo_full="$2"; shift 2 ;;
      --config) config_path="$2"; shift 2 ;;
      --confirm) dry_run="false"; shift ;;
      --dry-run) dry_run="true"; shift ;;
      --non-interactive) non_interactive="true"; shift ;;
      --parent-number) parent_number="$2"; shift 2 ;;
      --metadata-file) metadata_file="$2"; shift 2 ;;
      --engine-output-file) engine_output_file="$2"; shift 2 ;;
      --replace-parent) replace_parent="true"; shift ;;
      -h|--help) usage; exit 0 ;;
      *) echo "ERROR: Unknown arg: $1"; usage; exit 1 ;;
    esac
  done

  if [[ -z "$repo_full" ]]; then
    echo "ERROR: --repo <owner/name> is required" >&2
    exit 2
  fi

  # If config was provided, validate it resolves, even though e2e flow will re-resolve by repo.
  if [[ -n "$config_path" ]]; then
    resolve_config_path "$repo_full" "$config_path" >/dev/null
  fi

  local args=("--repo" "$repo_full" "--stage" "5")
  if [[ "$non_interactive" == "true" ]]; then
    args+=("--non-interactive")
  fi
  if [[ "$dry_run" == "true" ]]; then
    args+=("--dry-run")
  fi
  if [[ -n "$parent_number" ]]; then
    args+=("--parent-number" "$parent_number")
  fi
  if [[ -n "$metadata_file" ]]; then
    args+=("--metadata-file" "$metadata_file")
  fi
  if [[ -n "$engine_output_file" ]]; then
    args+=("--engine-output-file" "$engine_output_file")
  fi
  if [[ "$replace_parent" == "true" ]]; then
    args+=("--replace-parent")
  fi

  bash "$PROJECT_ROOT/scripts/e2e-flow-v2.sh" "${args[@]}"
}

main() {
  local cmd="${1-}"
  shift || true

  case "$cmd" in
    add) cmd_add "$@" ;;
    prepare) cmd_prepare "$@" ;;
    deploy) cmd_deploy "$@" ;;
    registry:update) cmd_registry_update "$@" ;;
    apply) cmd_apply "$@" ;;
    e2e:run) cmd_e2e "$@" ;;
    link:hierarchy|link-hierarchy) cmd_link_hierarchy "$@" ;;
    -h|--help|"") usage; exit 0 ;;
    *) echo "ERROR: Unknown command: $cmd"; usage; exit 1 ;;
  esac
}

main "$@"
