# GitIssuer systemd guide

This guide explains how to install and operate the GitIssuer automation with systemd.

## Prerequisites

- Linux host with systemd
- GitHub CLI (`gh`) installed and authenticated
- `jq` installed
- Optional: `inotifywait` from `inotify-tools` (for file watcher)

## Install

1. Copy this repository to `/opt/GitIssue-Manager`.
2. Ensure per-repo configs exist under `/opt/GitIssue-Manager/sync-helper/configs/*.json`.
3. Run the installer:

   ```bash
   sudo /opt/GitIssue-Manager/systemd/install.sh
   ```

## Start

```bash
sudo systemctl start gitissuer.timer
```

Optional file watcher:

```bash
sudo systemctl enable --now gitissuer-watch.service
```

### Watch targets (per-repo)

The watcher reads watched repositories from `sync-helper/configs/*.json`.

- A repo is watched when:
   - `gitissuer.enabled == true` (defaults to true if missing)
   - `gitissuer.watch.enabled == true` (defaults to false if missing)

Enable/disable watch per repo:

```bash
cd /opt/GitIssue-Manager
./bin/gitissuer watch enable --repo <owner/name>
./bin/gitissuer watch disable --repo <owner/name>
./bin/gitissuer watch list --include-disabled
```

Note: If you change configs, `gitissuer-watch.service` restarts itself to reload the watch list.

## Status & Logs

```bash
systemctl status gitissuer.timer
systemctl status gitissuer.service
journalctl -u gitissuer.service -f
```

## Troubleshooting

- Ensure `gh auth status` works for user `gitissuer`.
- Ensure `sync-helper/configs/*.json` has correct `localPath` values.
- Check logs in `/var/log/gitissuer/`.
