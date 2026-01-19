# Quick Start - Multi-Repository Setup

## Overview

GitIssue-Manager now supports managing multiple repositories with isolated configurations and outputs.

## Structure

```
GitIssue-Manager/
├── sync-helper/
│   └── configs/
│       ├── mzfshark-AragonOSX.json      # Config for AragonOSX
│       ├── mzfshark-aragon-app.json     # Config for aragon-app
│       └── mzfshark-Backend.json        # Config for Backend
└── tmp/
    ├── mzfshark-AragonOSX/              # Outputs for AragonOSX
    │   ├── tasks.json
    │   ├── subtasks.json
    │   ├── engine-input.json
    │   └── engine-output.json
    ├── mzfshark-aragon-app/             # Outputs for aragon-app
    └── mzfshark-Backend/                # Outputs for Backend
```

## Quick Commands

### Setup & List

```bash
# Configure a new repository
npm run setup

# List all configured repositories
npm run repos

# Get commands for specific repo
npm run repos -- --commands mzfshark-AragonOSX
```

### Single Repository Workflow

```bash
# Full path to config
npm run prepare -- --config sync-helper/configs/mzfshark-AragonOSX.json
npm run execute -- --config sync-helper/configs/mzfshark-AragonOSX.json

# Short version (copy from `npm run repos -- --commands <name>`)
CONFIG=sync-helper/configs/mzfshark-AragonOSX.json
npm run prepare -- --config $CONFIG && npm run execute -- --config $CONFIG
```

### Multiple Repositories

Process all configured repos:

```bash
# Simple loop
for config in sync-helper/configs/*.json; do
  npm run prepare -- --config "$config"
  npm run execute -- --config "$config"
done
```

### Inspect Outputs

```bash
# View tasks for specific repo
jq '.targets[0].tasks[:5]' tmp/mzfshark-AragonOSX/engine-input.json

# Count issues created
jq '[.results[0].tasks[] | select(.created)] | length' tmp/mzfshark-AragonOSX/engine-output.json

# View errors
jq '[.results[0].tasks[] | select(.error)]' tmp/mzfshark-AragonOSX/engine-output.json
```

## Common Workflows

### 1. First Time Setup

```bash
# Step 1: Configure AragonOSX
npm run setup
# Owner: mzfshark
# Repo: AragonOSX
# Path: ../AragonOSX
# Project sync: N

# Step 2: Configure aragon-app
npm run setup
# Choose option 1: Configure a new repository
# Owner: mzfshark
# Repo: aragon-app
# Path: ../aragon-app
# Project sync: N

# Step 3: List configured repos
npm run repos
```

### 2. Daily Work - Single Repo

```bash
# Update from latest Markdown changes
npm run prepare -- --config sync-helper/configs/mzfshark-AragonOSX.json

# Create/update issues on GitHub
npm run execute -- --config sync-helper/configs/mzfshark-AragonOSX.json
```

### 3. Weekly Sync - All Repos

```bash
# Process all repos
for cfg in sync-helper/configs/*.json; do
  echo "Processing: $(jq -r .repo $cfg)"
  npm run prepare -- --config "$cfg"
  npm run execute -- --config "$cfg"
  echo "---"
done
```

### 4. Edit Configuration

```bash
# Via setup script
npm run setup
# Choose option 2: Edit an existing repository

# Or direct edit
nano sync-helper/configs/mzfshark-AragonOSX.json
```

## Defaults Reference

All prompts support defaults (press Enter to use):

- **Owner**: `mzfshark`
- **Repo name**: `AragonOSX`
- **Local path**: `../<repo-name>`
- **Project sync**: `N` (disabled)
- **Default estimate**: `1` hour

## Troubleshooting

**Error**: "Target localPath does not exist"
```bash
# Fix: Update localPath in config
nano sync-helper/configs/mzfshark-AragonOSX.json
# Change "localPath": "../correct-path"
```

**Error**: "Config not found"
```bash
# Solution: Use --config flag
npm run prepare -- --config sync-helper/configs/mzfshark-AragonOSX.json
```

**Want to delete a repo config?**
```bash
rm sync-helper/configs/mzfshark-AragonOSX.json
rm -rf tmp/mzfshark-AragonOSX/
```

## See Also

- [docs/MULTI_REPO_GUIDE.md](docs/MULTI_REPO_GUIDE.md) - Complete multi-repo documentation
- [docs/SETUP_GUIDE.md](docs/SETUP_GUIDE.md) - Detailed setup options
- [README.md](README.md) - Project overview

