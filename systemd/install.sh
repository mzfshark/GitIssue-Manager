#!/bin/bash
set -euo pipefail

MANAGER_PATH="/opt/GitIssue-Manager"
SYSTEMD_PATH="/etc/systemd/system"

echo "==============================================="
echo "GitIssuer - systemd integration installer"
echo "==============================================="

if [[ "$EUID" -ne 0 ]]; then
  echo "ERROR: This script must be run as root."
  exit 1
fi

if [[ ! -d "$MANAGER_PATH" ]]; then
  echo "ERROR: $MANAGER_PATH not found. Copy this repo to $MANAGER_PATH first."
  exit 1
fi

echo "[1/7] Creating gitissuer user"
if ! id "gitissuer" >/dev/null 2>&1; then
  useradd -r -s /bin/bash -d /var/lib/gitissuer gitissuer
  echo "OK: gitissuer user created"
else
  echo "OK: gitissuer user already exists"
fi

echo "[2/7] Creating directories"
mkdir -p /var/lib/gitissuer/.gitissuer
mkdir -p /var/log/gitissuer
mkdir -p "$MANAGER_PATH/daemon"
mkdir -p "$MANAGER_PATH/config"

if [[ -d "$MANAGER_PATH/systemd" ]]; then
  chmod 755 "$MANAGER_PATH/systemd"/*.sh || true
fi

if [[ -d "$MANAGER_PATH/daemon" ]]; then
  chmod 755 "$MANAGER_PATH/daemon"/*.sh || true
fi

echo "[3/7] Installing systemd unit files"
cp "$MANAGER_PATH/systemd/gitissuer.service" "$SYSTEMD_PATH/"
cp "$MANAGER_PATH/systemd/gitissuer.timer" "$SYSTEMD_PATH/"
cp "$MANAGER_PATH/systemd/gitissuer-watch.service" "$SYSTEMD_PATH/"
chmod 644 "$SYSTEMD_PATH/gitissuer.service"
chmod 644 "$SYSTEMD_PATH/gitissuer.timer"
chmod 644 "$SYSTEMD_PATH/gitissuer-watch.service"

if compgen -G "$MANAGER_PATH/sync-helper/configs/*.json" >/dev/null; then
  echo "OK: Found per-repo configs under $MANAGER_PATH/sync-helper/configs"
else
  echo "WARN: No per-repo configs found under $MANAGER_PATH/sync-helper/configs"
  echo "HINT: Create one with: $MANAGER_PATH/bin/gitissuer config create --repo <owner/name> --local-path <path>"
fi

echo "[4/7] Setting ownership and permissions"
chown -R gitissuer:gitissuer /var/lib/gitissuer
chown -R gitissuer:gitissuer /var/log/gitissuer
chmod 750 /var/lib/gitissuer
chmod 750 /var/log/gitissuer

if command -v gh >/dev/null 2>&1; then
  echo "[5/7] GitHub CLI authentication"
  sudo -u gitissuer gh auth status || sudo -u gitissuer gh auth login
else
  echo "WARN: GitHub CLI (gh) not found. Install it before running the service."
fi

echo "[6/7] Reloading systemd"
systemctl daemon-reload
systemctl enable gitissuer.timer

echo "[7/7] Installation complete"
echo "Next steps:"
echo "- Ensure per-repo configs exist under $MANAGER_PATH/sync-helper/configs/*.json"
echo "- Start timer: systemctl start gitissuer.timer"
echo "- Check status: systemctl status gitissuer.timer"

echo "Optional: enable real-time watcher (ISSUE_UPDATES.md):"
echo "- systemctl enable --now gitissuer-watch.service"
