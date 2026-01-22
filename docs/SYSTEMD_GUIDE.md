# GitIssuer systemd guide

This guide explains how to install and operate the GitIssuer automation with systemd.

## Prerequisites

- Linux host with systemd
- GitHub CLI (`gh`) installed and authenticated
- `jq` installed
- Optional: `inotifywait` from `inotify-tools` (for file watcher)

## Install

1. Copy this repository to `/opt/GitIssue-Manager`.
2. Edit `/opt/GitIssue-Manager/config/repos.config.json` with the correct repository paths.
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

## Status & Logs

```bash
systemctl status gitissuer.timer
systemctl status gitissuer.service
journalctl -u gitissuer.service -f
```

## Troubleshooting

- Ensure `gh auth status` works for user `gitissuer`.
- Ensure the `repos.config.json` paths are correct.
- Check logs in `/var/log/gitissuer/`.
