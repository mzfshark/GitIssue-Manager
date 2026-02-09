#!/usr/bin/env bash
set -euo pipefail

# Minimal GitIssuer wrapper to support daemon steps.
# Commands: add, prepare, sync, deploy, registry:update, apply, e2e:run, link:hierarchy

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_DIR="$PROJECT_ROOT/sync-helper/configs"

usage() {
  cat <<'EOF'
Usage: gitissuer.sh <command> [options]

Commands:
  add --file <path> --output <path>        Copy ISSUE_UPDATES.md into a timestamped update file
  rekey --repo <owner/name> [--config <path>] [--dry-run|--confirm] [--plan <file>|--plans <csv>] [--plans-dir <path>]
                                           Inject missing [key:<ULID>] tags into Markdown planning files
  prepare --repo <owner/name> [--config <path>] [--dry-run] [--plan <file>|--plans <csv>] [--plans-dir <path>]
                                           Generate engine input from Markdown plans
  sync --repo <owner/name> [--config <path>] [--dry-run|--confirm] [--update-only] [--force] [--skip-fetch] [--plan <file>|--plans <csv>] [--plans-dir <path>] [--link-hierarchy|--no-link-hierarchy] [--parent-number <n>] [--replace-parent]
                                           Convenience command: prepare + deploy + registry:update
  deploy --repo <owner/name> [--config <path>] [--batch] [--dry-run|--confirm] [--update-only] [--force] [--skip-fetch] [--plan <file>|--plans <csv>] [--plans-dir <path>] [--no-prepare] [--link-hierarchy|--no-link-hierarchy] [--parent-number <n>] [--replace-parent]
                                           Execute GitHub writes (issues + optional ProjectV2)
  registry:update --repo <owner/name> [--config <path>]
                                           Update per-repo registry from engine-input + engine-output
  apply --repo <owner/name> [--config <path>] [--file <ISSUE_UPDATES.md>] [--dry-run|--confirm]
                                           Parse bounded updates section and apply safe actions using the registry
  e2e:run --repo <owner/name> [--config <path>] [--dry-run] [--non-interactive] [--plan <file>|--plan-file <path>]
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
  local plan_arg=""
  local plans_arg=""
  local plans_dir_arg=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo) repo_full="$2"; shift 2 ;;
      --config) config_path="$2"; shift 2 ;;
      --dry-run) dry_run="true"; shift ;;
      --plan) plan_arg="$2"; shift 2 ;;
      --plans) plans_arg="$2"; shift 2 ;;
      --plans-dir) plans_dir_arg="$2"; shift 2 ;;
      -h|--help) usage; exit 0 ;;
      *) echo "ERROR: Unknown arg: $1"; usage; exit 1 ;;
    esac
  done

  local cfg
  cfg=$(resolve_config_path "$repo_full" "$config_path")

  # prepare.js already is deterministic; dry-run is informational for compatibility.
  local -a prepare_args=(--config "$cfg")
  if [[ -n "$plans_arg" ]]; then
    prepare_args+=(--plans "$plans_arg")
  elif [[ -n "$plan_arg" ]]; then
    prepare_args+=(--plan "$plan_arg")
  fi
  if [[ -n "$plans_dir_arg" ]]; then
    prepare_args+=(--plans-dir "$plans_dir_arg")
  fi
  node "$PROJECT_ROOT/client/prepare.js" "${prepare_args[@]}"
  if [[ "$dry_run" == "true" ]]; then
    echo "OK: prepare (dry-run) completed for $repo_full"
  else
    echo "OK: prepare completed for $repo_full"
  fi
}

cmd_rekey() {
  require_cmd node
  require_cmd jq

  local repo_full=""
  local config_path=""
  local confirm="false"
  local dry_run="false"
  local plan_arg=""
  local plans_arg=""
  local plans_dir_arg=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo) repo_full="$2"; shift 2 ;;
      --config) config_path="$2"; shift 2 ;;
      --dry-run) dry_run="true"; shift ;;
      --confirm) confirm="true"; shift ;;
      --plan) plan_arg="$2"; shift 2 ;;
      --plans) plans_arg="$2"; shift 2 ;;
      --plans-dir) plans_dir_arg="$2"; shift 2 ;;
      -h|--help) usage; exit 0 ;;
      *) echo "ERROR: Unknown arg: $1"; usage; exit 1 ;;
    esac
  done

  if [[ "$confirm" == "true" && "$dry_run" == "true" ]]; then
    echo "ERROR: Choose one: --dry-run or --confirm" >&2
    exit 2
  fi

  if [[ "$confirm" != "true" && "$dry_run" != "true" ]]; then
    echo "ERROR: Refusing to modify files without --confirm (or preview with --dry-run)" >&2
    exit 2
  fi

  local cfg
  cfg=$(resolve_config_path "$repo_full" "$config_path")

  local -a rekey_args=(--config "$cfg")
  if [[ -n "$plans_arg" ]]; then
    rekey_args+=(--plans "$plans_arg")
  elif [[ -n "$plan_arg" ]]; then
    rekey_args+=(--plan "$plan_arg")
  fi
  if [[ -n "$plans_dir_arg" ]]; then
    rekey_args+=(--plans-dir "$plans_dir_arg")
  fi
  if [[ "$dry_run" == "true" ]]; then
    rekey_args+=(--dry-run)
  else
    rekey_args+=(--confirm)
  fi

  node "$PROJECT_ROOT/client/rekey.js" "${rekey_args[@]}"
  if [[ "$dry_run" == "true" ]]; then
    echo "OK: rekey (dry-run) completed for $repo_full"
  else
    echo "OK: rekey completed for $repo_full"
  fi
}

cmd_sync() {
  require_cmd bash
  require_cmd jq

  local repo_full=""
  local config_path=""

  local confirm="false"
  local dry_run="false"

  local update_only="false"
  local force="false"
  local skip_fetch="false"

  local plan_arg=""
  local plans_arg=""
  local plans_dir_arg=""

  local link_hierarchy="true"
  local parent_number=""
  local replace_parent="false"
  local batch_size=""
  local delay_ms=""
  local max_retries=""
  local max_backoff_ms=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo) repo_full="$2"; shift 2 ;;
      --config) config_path="$2"; shift 2 ;;
      --dry-run) dry_run="true"; shift ;;
      --confirm) confirm="true"; shift ;;
      --update-only) update_only="true"; shift ;;
      --force) force="true"; shift ;;
      --skip-fetch) skip_fetch="true"; shift ;;
      --plan) plan_arg="$2"; shift 2 ;;
      --plans) plans_arg="$2"; shift 2 ;;
      --plans-dir) plans_dir_arg="$2"; shift 2 ;;
      --link-hierarchy) link_hierarchy="true"; shift ;;
      --no-link-hierarchy) link_hierarchy="false"; shift ;;
      --parent-number) parent_number="$2"; shift 2 ;;
      --batch-size) batch_size="$2"; shift 2 ;;
      --delay-ms) delay_ms="$2"; shift 2 ;;
      --max-retries) max_retries="$2"; shift 2 ;;
      --max-backoff-ms) max_backoff_ms="$2"; shift 2 ;;
      --replace-parent) replace_parent="true"; shift ;;
      --batch) shift ;; # accepted for compatibility; sub-steps are non-interactive
      -h|--help) usage; exit 0 ;;
      *) echo "ERROR: Unknown arg: $1"; usage; exit 1 ;;
    esac
  done

  if [[ "$confirm" == "true" && "$dry_run" == "true" ]]; then
    echo "ERROR: Choose one: --dry-run or --confirm" >&2
    exit 2
  fi

  if [[ "$confirm" != "true" && "$dry_run" != "true" ]]; then
    echo "ERROR: Refusing to sync without --confirm (or preview with --dry-run)" >&2
    exit 2
  fi

  # 1) Prepare artifacts
  local -a prepare_args=(--repo "$repo_full")
  if [[ -n "$config_path" ]]; then
    prepare_args+=(--config "$config_path")
  fi
  if [[ "$dry_run" == "true" ]]; then
    prepare_args+=(--dry-run)
  fi
  if [[ -n "$plans_arg" ]]; then
    prepare_args+=(--plans "$plans_arg")
  elif [[ -n "$plan_arg" ]]; then
    prepare_args+=(--plan "$plan_arg")
  fi
  if [[ -n "$plans_dir_arg" ]]; then
    prepare_args+=(--plans-dir "$plans_dir_arg")
  fi
  cmd_prepare "${prepare_args[@]}"

  # 2) Deploy (dry-run or confirmed write)
  local -a deploy_args=(--repo "$repo_full")
  if [[ -n "$config_path" ]]; then
    deploy_args+=(--config "$config_path")
  fi
  if [[ "$dry_run" == "true" ]]; then
    deploy_args+=(--dry-run)
  else
    deploy_args+=(--confirm)
  fi
  if [[ "$update_only" == "true" ]]; then
    deploy_args+=(--update-only)
  fi
  if [[ "$force" == "true" ]]; then
    deploy_args+=(--force)
  fi
  if [[ "$skip_fetch" == "true" ]]; then
    deploy_args+=(--skip-fetch)
  fi
  # deploy runs prepare by default; avoid double-preparing here.
  deploy_args+=(--no-prepare)
  if [[ "$link_hierarchy" == "true" ]]; then
    deploy_args+=(--link-hierarchy)
  else
    deploy_args+=(--no-link-hierarchy)
  fi
  if [[ -n "$parent_number" ]]; then
    deploy_args+=(--parent-number "$parent_number")
  fi
  if [[ "$replace_parent" == "true" ]]; then
    deploy_args+=(--replace-parent)
  fi
  cmd_deploy "${deploy_args[@]}"

  # 3) Update registry locally (required for later `apply` workflows)
  # IMPORTANT: Do not update registry during --dry-run to avoid phantom entries.
  if [[ "$dry_run" == "true" ]]; then
    echo "INFO: registry:update skipped (dry-run) for $repo_full" >&2
  else
    local -a reg_args=(--repo "$repo_full")
    if [[ -n "$config_path" ]]; then
      reg_args+=(--config "$config_path")
    fi
    cmd_registry_update "${reg_args[@]}"
  fi

  echo "OK: sync completed for $repo_full"
}

cmd_deploy() {
  require_cmd node
  require_cmd jq
  require_cmd gh

  local repo_full=""
  local config_path=""
  local confirm="false"
  local dry_run="false"
  local update_only="false"
  local do_prepare="true"
  local force="false"
  local skip_fetch="false"

  local plan_arg=""
  local plans_arg=""
  local plans_dir_arg=""

  local link_hierarchy="true"
  local parent_number=""
  local replace_parent="false"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo) repo_full="$2"; shift 2 ;;
      --config) config_path="$2"; shift 2 ;;
      --dry-run) dry_run="true"; shift ;;
      --confirm) confirm="true"; shift ;;
      --update-only) update_only="true"; shift ;;
      --force) force="true"; shift ;;
      --skip-fetch) skip_fetch="true"; shift ;;
      --plan) plan_arg="$2"; shift 2 ;;
      --plans) plans_arg="$2"; shift 2 ;;
      --plans-dir) plans_dir_arg="$2"; shift 2 ;;
      --no-prepare) do_prepare="false"; shift ;;
      --link-hierarchy) link_hierarchy="true"; shift ;;
      --no-link-hierarchy) link_hierarchy="false"; shift ;;
      --parent-number) parent_number="$2"; shift 2 ;;
      --batch-size) batch_size="$2"; shift 2 ;;
      --delay-ms) delay_ms="$2"; shift 2 ;;
      --max-retries) max_retries="$2"; shift 2 ;;
      --max-backoff-ms) max_backoff_ms="$2"; shift 2 ;;
      --replace-parent) replace_parent="true"; shift ;;
      --batch) shift ;; # accepted for compatibility; executor is non-interactive
      -h|--help) usage; exit 0 ;;
      *) echo "ERROR: Unknown arg: $1"; usage; exit 1 ;;
    esac
  done

  if [[ "$confirm" == "true" && "$dry_run" == "true" ]]; then
    echo "ERROR: Choose one: --dry-run or --confirm" >&2
    exit 2
  fi

  if [[ "$confirm" != "true" && "$dry_run" != "true" ]]; then
    echo "ERROR: Refusing to deploy without --confirm (or preview with --dry-run)" >&2
    exit 2
  fi

  local cfg
  cfg=$(resolve_config_path "$repo_full" "$config_path")

  # Always regenerate artifacts before deploying (avoids stale metadata/engine-input/engine-output).
  # Can be disabled with --no-prepare.
  if [[ "$do_prepare" == "true" ]]; then
    local -a prepare_args=(--repo "$repo_full" --config "$cfg")
    if [[ "$dry_run" == "true" ]]; then
      prepare_args+=(--dry-run)
    fi
    if [[ -n "$plans_arg" ]]; then
      prepare_args+=(--plans "$plans_arg")
    elif [[ -n "$plan_arg" ]]; then
      prepare_args+=(--plan "$plan_arg")
    fi
    if [[ -n "$plans_dir_arg" ]]; then
      prepare_args+=(--plans-dir "$plans_dir_arg")
    fi
    cmd_prepare "${prepare_args[@]}"
  fi

  # Preflight: fetch current GitHub state before any mutations (helps prevent clobbering manual edits).
  # Can be disabled with --skip-fetch.
  if [[ "$skip_fetch" != "true" ]]; then
    echo "INFO: Preflight fetch (sync-md issues snapshot)..." >&2
    node "$PROJECT_ROOT/server/preflight-fetch.js" --config "$cfg" >/dev/null
    echo "OK: Preflight fetch completed." >&2
  else
    echo "INFO: Preflight fetch skipped (--skip-fetch)." >&2
  fi

  if [[ "$dry_run" == "true" ]]; then
    if [[ "$update_only" == "true" ]]; then
      if [[ "$force" == "true" ]]; then
        node "$PROJECT_ROOT/server/executor.js" --config "$cfg" --dry-run --update-only --force
      else
        node "$PROJECT_ROOT/server/executor.js" --config "$cfg" --dry-run --update-only
      fi
    else
      if [[ "$force" == "true" ]]; then
        node "$PROJECT_ROOT/server/executor.js" --config "$cfg" --dry-run --force
      else
        node "$PROJECT_ROOT/server/executor.js" --config "$cfg" --dry-run
      fi
    fi
    echo "OK: deploy (dry-run) completed for $repo_full"
  else
    if [[ "$update_only" == "true" ]]; then
      if [[ "$force" == "true" ]]; then
        node "$PROJECT_ROOT/server/executor.js" --config "$cfg" --update-only --force
      else
        node "$PROJECT_ROOT/server/executor.js" --config "$cfg" --update-only
      fi
    else
      if [[ "$force" == "true" ]]; then
        node "$PROJECT_ROOT/server/executor.js" --config "$cfg" --force
      else
        node "$PROJECT_ROOT/server/executor.js" --config "$cfg"
      fi
    fi
    echo "OK: deploy completed for $repo_full"
  fi

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

    # Ensure link-hierarchy consumes artifacts from this exact run.
    local repo_slug
    repo_slug="${repo_full//\//-}"
    local engine_output_file
    local metadata_file
    engine_output_file=$(jq -r '.outputs.engineOutputPath // empty' "$cfg" 2>/dev/null || true)
    metadata_file=$(jq -r '.outputs.metadataPath // empty' "$cfg" 2>/dev/null || true)
    if [[ -z "$engine_output_file" || "$engine_output_file" == "null" ]]; then
      engine_output_file="./tmp/${repo_slug}/engine-output.json"
    fi
    if [[ -z "$metadata_file" || "$metadata_file" == "null" ]]; then
      metadata_file="./tmp/${repo_slug}/metadata.json"
    fi

    local -a link_args=(--repo "$repo_full" --parent-number "$parent_number" --non-interactive)
    if [[ "$dry_run" == "true" ]]; then
      link_args+=(--dry-run)
    else
      link_args+=(--confirm)
    fi
    link_args+=(--engine-output-file "$engine_output_file" --metadata-file "$metadata_file")
    if [[ "$replace_parent" == "true" ]]; then
      link_args+=(--replace-parent)
    fi
    if [[ -n "$batch_size" ]]; then
      link_args+=(--batch-size "$batch_size")
    fi
    if [[ -n "$delay_ms" ]]; then
      link_args+=(--delay-ms "$delay_ms")
    fi
    if [[ -n "$max_retries" ]]; then
      link_args+=(--max-retries "$max_retries")
    fi
    if [[ -n "$max_backoff_ms" ]]; then
      link_args+=(--max-backoff-ms "$max_backoff_ms")
    fi
    if [[ -n "$batch_size" ]]; then
      link_args+=(--batch-size "$batch_size")
    fi
    if [[ -n "$delay_ms" ]]; then
      link_args+=(--delay-ms "$delay_ms")
    fi
    if [[ -n "$max_retries" ]]; then
      link_args+=(--max-retries "$max_retries")
    fi
    if [[ -n "$max_backoff_ms" ]]; then
      link_args+=(--max-backoff-ms "$max_backoff_ms")
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
  local plan_arg=""
  local plan_file_arg=""
  local metadata_file_arg=""
  local engine_output_file_arg=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo) repo_full="$2"; shift 2 ;;
      --config) config_path="$2"; shift 2 ;;
      --dry-run) dry_run="true"; shift ;;
      --confirm) dry_run="false"; shift ;;
      --non-interactive) non_interactive="true"; shift ;;
      --plan) plan_arg="$2"; shift 2 ;;
      --plan-file) plan_file_arg="$2"; shift 2 ;;
      --metadata-file) metadata_file_arg="$2"; shift 2 ;;
      --engine-output-file) engine_output_file_arg="$2"; shift 2 ;;
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
  if [[ -n "$plan_file_arg" ]]; then
    args+=("--plan-file" "$plan_file_arg")
  elif [[ -n "$plan_arg" ]]; then
    args+=("--plan" "$plan_arg")
  fi
  if [[ -n "$metadata_file_arg" ]]; then
    args+=("--metadata-file" "$metadata_file_arg")
  fi
  if [[ -n "$engine_output_file_arg" ]]; then
    args+=("--engine-output-file" "$engine_output_file_arg")
  fi

  bash "$PROJECT_ROOT/scripts/e2e-flow-v2.sh" "${args[@]}"
}

cmd_link_hierarchy() {
  require_cmd node
  require_cmd jq
  require_cmd gh

  local repo_full=""
  local config_path=""
  local dry_run="true"
  local parent_number=""
  local metadata_file=""
  local engine_output_file=""
  local replace_parent="false"
  local plan_arg=""


  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo) repo_full="$2"; shift 2 ;;
      --config) config_path="$2"; shift 2 ;;
      --confirm) dry_run="false"; shift ;;
      --dry-run) dry_run="true"; shift ;;
      --non-interactive) shift ;; # accepted for compatibility
      --parent-number) parent_number="$2"; shift 2 ;;
      --plan) plan_arg="$2"; shift 2 ;;
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

  local cfg
  cfg=$(resolve_config_path "$repo_full" "$config_path")

  # Build args for the new Node-based link-hierarchy script
  local -a link_args=(--config "$cfg")
  
  if [[ "$dry_run" == "true" ]]; then
    link_args+=(--dry-run)
  fi
  if [[ -n "$parent_number" ]]; then
    link_args+=(--parent-number "$parent_number")
  fi
  if [[ -n "$plan_arg" ]]; then
    link_args+=(--plan "$plan_arg")
  fi
  if [[ -n "$engine_output_file" ]]; then
    link_args+=(--engine-output-file "$engine_output_file")
  fi
  if [[ -n "$metadata_file" ]]; then
    link_args+=(--metadata-file "$metadata_file")
  fi
  if [[ "$replace_parent" == "true" ]]; then
    link_args+=(--replace-parent)
  fi
  # Batch controls (optional)
  # Default batch-size=10, delay-ms=5000
  link_args+=(--batch-size "${LINK_BATCH_SIZE:-10}")
  link_args+=(--delay-ms "${LINK_DELAY_MS:-5000}")
  link_args+=(--max-retries "${LINK_MAX_RETRIES:-5}")
  link_args+=(--max-backoff-ms "${LINK_MAX_BACKOFF_MS:-60000}")

  node "$PROJECT_ROOT/server/link-hierarchy.js" "${link_args[@]}"

  if [[ "$dry_run" == "true" ]]; then
    echo "OK: link-hierarchy (dry-run) completed for $repo_full"
  else
    echo "OK: link-hierarchy completed for $repo_full"
  fi
}

main() {
  local cmd="${1-}"
  shift || true

  case "$cmd" in
    add) cmd_add "$@" ;;
    rekey) cmd_rekey "$@" ;;
    prepare) cmd_prepare "$@" ;;
    sync) cmd_sync "$@" ;;
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