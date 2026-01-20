#!/usr/bin/env bash
# Usage: ./setup_capture.sh <OWNER> <PROJECT_NUMBER> [OUT]
OWNER="$1"
NUMBER="$2"
OUT="${3:-tmp/project-schema.json}"

if [[ -z "$OWNER" || -z "$NUMBER" ]]; then
  echo "Usage: $0 <OWNER> <PROJECT_NUMBER> [OUT]"
  exit 1
fi

mkdir -p "$(dirname "$OUT")"
node "$(dirname "$0")/register_project_fields.js" --owner "$OWNER" --number "$NUMBER" --out "$OUT"
echo "Schema written to $OUT"
