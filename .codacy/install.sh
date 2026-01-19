#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
BIN_DIR="$ROOT_DIR/.codacy/bin"
mkdir -p "$BIN_DIR"

detect_os() {
  local os
  os=$(uname -s | tr '[:upper:]' '[:lower:]')
  case "$os" in
    linux*) echo linux ;;
    darwin*) echo macosx ;;
    msys*|mingw*|cygwin*) echo win ;;
    *) echo linux ;;
  esac
}

OS_FILTER=$(detect_os)
echo "Detecting latest Codacy CLI release for: $OS_FILTER"

# Prefer GitHub latest/download endpoints to avoid requiring jq
BASE_DL="https://github.com/codacy/codacy-analysis-cli/releases/latest/download"
case "$OS_FILTER" in
  linux)  FILENAME="codacy-analysis-cli-linux" ;;
  macosx) FILENAME="codacy-analysis-cli-macosx" ;;
  win)    FILENAME="codacy-analysis-cli-win-64bit.exe" ;;
  *)      FILENAME="codacy-analysis-cli-linux" ;;
esac

TMP_DEST="$BIN_DIR/$FILENAME"
URL="$BASE_DL/$FILENAME"

echo "Downloading $URL -> $TMP_DEST"
curl -fL "$URL" -o "$TMP_DEST"
chmod +x "$TMP_DEST" || true

if [[ "$FILENAME" == *.exe || "$OS_FILTER" == "win" ]]; then
  mv -f "$TMP_DEST" "$BIN_DIR/codacy-analysis-cli.exe"
else
  mv -f "$TMP_DEST" "$BIN_DIR/codacy-analysis-cli"
fi

echo "Codacy CLI installed under $BIN_DIR"
"$ROOT_DIR/.codacy/codacy" --version || true
