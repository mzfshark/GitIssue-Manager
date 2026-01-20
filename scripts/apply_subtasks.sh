#!/usr/bin/env bash
# Usage: ./apply_subtasks.sh <SCHEMA.json> <MAPPING.json>
SCHEMA="$1"
MAPPING="$2"

if [[ -z "$SCHEMA" || -z "$MAPPING" ]]; then
  echo "Usage: $0 <SCHEMA.json> <MAPPING.json>"
  exit 1
fi

node "$(dirname "$0")/apply_subtasks.js" --schema "$SCHEMA" --mapping "$MAPPING"
