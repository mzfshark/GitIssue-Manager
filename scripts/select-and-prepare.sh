#!/usr/bin/env bash
set -e

CONFIG_DIR="./sync-helper/configs"

# Parse --repo flag
SELECTED_REPO=""
if [ "$1" = "--repo" ] && [ -n "$2" ]; then
  SELECTED_REPO="$2"
fi

if [ ! -d "$CONFIG_DIR" ] || [ -z "$(ls -A "$CONFIG_DIR" 2>/dev/null)" ]; then
  echo "No repositories configured. Run: npm run setup"
  exit 1
fi

# If --repo specified, find and use that config
if [ -n "$SELECTED_REPO" ]; then
  # Try as config name first (e.g., "Axodus-aragon-app")
  config="$CONFIG_DIR/${SELECTED_REPO}.json"
  if [ ! -f "$config" ]; then
    # Try finding by repo path (e.g., "Axodus/aragon-app")
    for cfg in "$CONFIG_DIR"/*.json; do
      repo=$(jq -r '.repo' "$cfg")
      if [ "$repo" = "$SELECTED_REPO" ]; then
        config="$cfg"
        break
      fi
    done
  fi
  
  if [ ! -f "$config" ]; then
    echo "Error: Repository '$SELECTED_REPO' not found in configs"
    echo "Available repos:"
    for cfg in "$CONFIG_DIR"/*.json; do
      echo "  - $(jq -r '.repo' "$cfg") ($(basename "$cfg" .json))"
    done
    exit 1
  fi
  
  repo=$(jq -r '.repo' "$config")
  localPath=$(jq -r '.localPath // ""' "$config")
  echo "Using: $repo"
  echo "Config: $config"
  if [ -n "$localPath" ] && [ -d "$localPath/docs/plans" ]; then
    echo
    echo "Select plans to include (comma-separated numbers):"
    mapfile -t plan_files < <(ls "$localPath/docs/plans"/*.md 2>/dev/null)
    i=1
    for f in "${plan_files[@]}"; do
      echo "  $i) $(basename "$f")"
      i=$((i+1))
    done
    read -p "Choose (e.g. 1,3,5): " plan_choice
    if [ -n "$plan_choice" ]; then
      selected=""
      IFS=',' read -ra picks <<< "$plan_choice"
      for p in "${picks[@]}"; do
        idx=$((p-1))
        if [ $idx -ge 0 ] && [ $idx -lt ${#plan_files[@]} ]; then
          name=$(basename "${plan_files[$idx]}")
          selected="${selected}${selected:+,}${name}"
        fi
      done
      if [ -n "$selected" ]; then
        echo
        node client/prepare.js --config "$config" --plans "$selected" --plans-dir "$localPath/docs/plans"
        exit 0
      fi
    fi
  fi
  echo
  node client/prepare.js --config "$config"
  exit 0
fi

# Count configs
count=$(ls -1 "$CONFIG_DIR"/*.json 2>/dev/null | wc -l)

if [ "$count" -eq 0 ]; then
  echo "No repositories configured. Run: npm run setup"
  exit 1
elif [ "$count" -eq 1 ]; then
  # Only one config, use it automatically
  config=$(ls "$CONFIG_DIR"/*.json)
  repo=$(jq -r '.repo' "$config")
  localPath=$(jq -r '.localPath // ""' "$config")
  echo "Using: $repo"
  echo "Config: $config"
  if [ -n "$localPath" ] && [ -d "$localPath/docs/plans" ]; then
    echo
    echo "Select plans to include (comma-separated numbers):"
    mapfile -t plan_files < <(ls "$localPath/docs/plans"/*.md 2>/dev/null)
    i=1
    for f in "${plan_files[@]}"; do
      echo "  $i) $(basename "$f")"
      i=$((i+1))
    done
    read -p "Choose (e.g. 1,3,5): " plan_choice
    if [ -n "$plan_choice" ]; then
      selected=""
      IFS=',' read -ra picks <<< "$plan_choice"
      for p in "${picks[@]}"; do
        idx=$((p-1))
        if [ $idx -ge 0 ] && [ $idx -lt ${#plan_files[@]} ]; then
          name=$(basename "${plan_files[$idx]}")
          selected="${selected}${selected:+,}${name}"
        fi
      done
      if [ -n "$selected" ]; then
        echo
        node client/prepare.js --config "$config" --plans "$selected" --plans-dir "$localPath/docs/plans"
        exit 0
      fi
    fi
  fi
  echo
  node client/prepare.js --config "$config"
else
  # Multiple configs, let user choose
  echo "Select a repository to prepare:"
  echo
  
  configs=()
  i=1
  for cfg in "$CONFIG_DIR"/*.json; do
    repo=$(jq -r '.repo' "$cfg")
    basename=$(basename "$cfg" .json)
    echo "  $i) $repo"
    configs+=("$cfg")
    i=$((i+1))
  done
  echo "  a) All repositories"
  echo
  
  read -p "Choose (1-$((i-1))/a): " choice
  
  if [ "$choice" = "a" ] || [ "$choice" = "A" ]; then
    # Process all
    for cfg in "${configs[@]}"; do
      repo=$(jq -r '.repo' "$cfg")
      localPath=$(jq -r '.localPath // ""' "$cfg")
      echo
      echo "========================================"
      echo "Preparing: $repo"
      echo "========================================"
      if [ -n "$localPath" ] && [ -d "$localPath/docs/plans" ]; then
        echo
        echo "Select plans to include (comma-separated numbers):"
        mapfile -t plan_files < <(ls "$localPath/docs/plans"/*.md 2>/dev/null)
        i=1
        for f in "${plan_files[@]}"; do
          echo "  $i) $(basename "$f")"
          i=$((i+1))
        done
        read -p "Choose (e.g. 1,3,5): " plan_choice
        if [ -n "$plan_choice" ]; then
          selected=""
          IFS=',' read -ra picks <<< "$plan_choice"
          for p in "${picks[@]}"; do
            idx=$((p-1))
            if [ $idx -ge 0 ] && [ $idx -lt ${#plan_files[@]} ]; then
              name=$(basename "${plan_files[$idx]}")
              selected="${selected}${selected:+,}${name}"
            fi
          done
          if [ -n "$selected" ]; then
            node client/prepare.js --config "$cfg" --plans "$selected" --plans-dir "$localPath/docs/plans"
            continue
          fi
        fi
      fi
      node client/prepare.js --config "$cfg"
    done
  else
    # Process selected
    idx=$((choice-1))
    if [ $idx -lt 0 ] || [ $idx -ge ${#configs[@]} ]; then
      echo "Invalid selection"
      exit 1
    fi
    config="${configs[$idx]}"
    repo=$(jq -r '.repo' "$config")
    localPath=$(jq -r '.localPath // ""' "$config")
    echo "Selected: $repo"
    echo
    if [ -n "$localPath" ] && [ -d "$localPath/docs/plans" ]; then
      echo
      echo "Select plans to include (comma-separated numbers):"
      mapfile -t plan_files < <(ls "$localPath/docs/plans"/*.md 2>/dev/null)
      i=1
      for f in "${plan_files[@]}"; do
        echo "  $i) $(basename "$f")"
        i=$((i+1))
      done
      read -p "Choose (e.g. 1,3,5): " plan_choice
      if [ -n "$plan_choice" ]; then
        selected=""
        IFS=',' read -ra picks <<< "$plan_choice"
        for p in "${picks[@]}"; do
          idx=$((p-1))
          if [ $idx -ge 0 ] && [ $idx -lt ${#plan_files[@]} ]; then
            name=$(basename "${plan_files[$idx]}")
            selected="${selected}${selected:+,}${name}"
          fi
        done
        if [ -n "$selected" ]; then
          node client/prepare.js --config "$config" --plans "$selected" --plans-dir "$localPath/docs/plans"
          exit 0
        fi
      fi
    fi
    node client/prepare.js --config "$config"
  fi
fi
