# Multi-Repository Management Guide

GitIssue-Manager now supports managing multiple repositories independently with organized configuration and output structure.

## New Structure

### Configuration Files

Each repository has its own configuration file:

```
sync-helper/configs/
├── mzfshark-AragonOSX.json
├── mzfshark-aragon-app.json
└── mzfshark-Aragon-app-backend.json
```

**Config naming**: `<owner>-<repo-name>.json`

### Output Files

Each repository's outputs are isolated in separate directories:

```
tmp/
├── mzfshark-AragonOSX/
│   ├── tasks.json
│   ├── subtasks.json
│   ├── engine-input.json
│   └── engine-output.json
├── mzfshark-aragon-app/
│   ├── tasks.json
│   ├── subtasks.json
│   ├── engine-input.json
│   └── engine-output.json
└── mzfshark-Aragon-app-backend/
    ├── tasks.json
    ├── subtasks.json
    ├── engine-input.json
    └── engine-output.json
```

## Quick Start

### 1. Configure First Repository

```bash
npm run setup
# Press Enter to use defaults or customize
```

This creates: `sync-helper/configs/mzfshark-AragonOSX.json`

### 2. Configure Additional Repositories

```bash
npm run setup
# Choose option 1: Configure a new repository
# Fill in different owner/repo details
```

### 3. List Configured Repositories

```bash
npm run repos
```

**Output example:**
```
=== Configured Repositories ===

1. mzfshark-AragonOSX
   Repo: mzfshark/AragonOSX
   Local: ../AragonOSX
   Project Sync: disabled
   Config: /path/to/sync-helper/configs/mzfshark-AragonOSX.json

2. mzfshark-aragon-app
   Repo: mzfshark/aragon-app
   Local: ../aragon-app
   Project Sync: enabled
   Config: /path/to/sync-helper/configs/mzfshark-aragon-app.json
```

### 4. Get Commands for Specific Repo

```bash
npm run repos -- --commands mzfshark-AragonOSX
```

**Output:**
```
=== Commands for mzfshark-AragonOSX ===

Prepare (scan Markdown and generate input):
  npm run prepare -- --config sync-helper/configs/mzfshark-AragonOSX.json

Execute (create/update GitHub issues):
  npm run execute -- --config sync-helper/configs/mzfshark-AragonOSX.json

Full workflow (prepare + execute):
  npm run prepare -- --config sync-helper/configs/mzfshark-AragonOSX.json && npm run execute -- --config sync-helper/configs/mzfshark-AragonOSX.json
```

## Workflow Examples

### Work on Single Repository

```bash
# 1. Configure (first time only)
npm run setup

# 2. Prepare
npm run prepare -- --config sync-helper/configs/mzfshark-AragonOSX.json

# 3. Execute
npm run execute -- --config sync-helper/configs/mzfshark-AragonOSX.json

# Or combined:
npm run prepare -- --config sync-helper/configs/mzfshark-AragonOSX.json && \
npm run execute -- --config sync-helper/configs/mzfshark-AragonOSX.json
```

### Work on Multiple Repositories

```bash
# Loop through all configured repos
for config in sync-helper/configs/*.json; do
  echo "Processing: $config"
  npm run prepare -- --config "$config"
  npm run execute -- --config "$config"
  echo "---"
done
```

### Bash Helper Script

Create `scripts/sync-all-repos.sh`:

```bash
#!/usr/bin/env bash
set -e

CONFIG_DIR="./sync-helper/configs"

if [ ! -d "$CONFIG_DIR" ]; then
  echo "No configs found. Run: npm run setup"
  exit 1
fi

for config in "$CONFIG_DIR"/*.json; do
  [ -f "$config" ] || continue
  
  repo=$(jq -r '.repo' "$config")
  echo "========================================"
  echo "Processing: $repo"
  echo "Config: $config"
  echo "========================================"
  
  npm run prepare -- --config "$config"
  npm run execute -- --config "$config"
  
  echo ""
done

echo "✓ All repositories processed!"
```

**Usage:**
```bash
chmod +x scripts/sync-all-repos.sh
./scripts/sync-all-repos.sh
```

## Configuration Management

### Edit Existing Repository

**Option 1**: Via setup script
```bash
npm run setup
# Choose option 2: Edit an existing repository
# Enter config name (e.g., mzfshark-AragonOSX)
```

**Option 2**: Direct edit
```bash
nano sync-helper/configs/mzfshark-AragonOSX.json
```

### Remove Repository

```bash
rm sync-helper/configs/mzfshark-AragonOSX.json
rm -rf tmp/mzfshark-AragonOSX/
```

### List All Repositories

```bash
npm run repos
```

### View Outputs for Specific Repo

```bash
# View tasks
jq . tmp/mzfshark-AragonOSX/tasks.json

# View execution results
jq . tmp/mzfshark-AragonOSX/engine-output.json

# Count issues created
jq '[.results[0].tasks[] | select(.created == true)] | length' tmp/mzfshark-AragonOSX/engine-output.json
```

## Configuration File Format

Each config file (`sync-helper/configs/<owner>-<repo>.json`) has this structure:

```json
{
  "owner": "mzfshark",
  "repo": "mzfshark/AragonOSX",
  "localPath": "../AragonOSX",
  "enableProjectSync": false,
  "project": {
    "url": "https://github.com/users/mzfshark/projects/5",
    "number": 5,
    "fieldIds": {
      "statusFieldId": "",
      "priorityFieldId": "",
      "estimateHoursFieldId": "251668000",
      "startDateFieldId": "",
      "endDateFieldId": ""
    }
  },
  "defaults": {
    "defaultEstimateHours": 1
  },
  "outputs": {
    "tasksPath": "./tmp/mzfshark-AragonOSX/tasks.json",
    "subtasksPath": "./tmp/mzfshark-AragonOSX/subtasks.json",
    "engineInputPath": "./tmp/mzfshark-AragonOSX/engine-input.json",
    "engineOutputPath": "./tmp/mzfshark-AragonOSX/engine-output.json"
  }
}
```

## Migration from Old Format

The tool supports backward compatibility with the old format (`sync-helper/sync-config.json` with `targets[]` array).

**Old format (still supported):**
```json
{
  "owner": "mzfshark",
  "targets": [
    { "repo": "mzfshark/AragonOSX", "localPath": "../AragonOSX" },
    { "repo": "mzfshark/aragon-app", "localPath": "../aragon-app" }
  ]
}
```

**New format (recommended):**
- Separate files per repo in `sync-helper/configs/`
- Each file is standalone and complete

**To migrate:**
1. Run `npm run setup` for each repo in your old config
2. Delete old `sync-helper/sync-config.json` (optional)

## Advanced Usage

### Custom Output Directory

Edit config file to change output paths:

```json
{
  "outputs": {
    "tasksPath": "./custom-dir/tasks.json",
    "subtasksPath": "./custom-dir/subtasks.json",
    "engineInputPath": "./custom-dir/engine-input.json",
    "engineOutputPath": "./custom-dir/engine-output.json"
  }
}
```

### Different Project per Repository

Each repo can have its own Project V2 configuration:

**AragonOSX config:**
```json
{
  "repo": "mzfshark/AragonOSX",
  "enableProjectSync": true,
  "project": { "number": 5, "url": "https://..." }
}
```

**aragon-app config:**
```json
{
  "repo": "mzfshark/aragon-app",
  "enableProjectSync": true,
  "project": { "number": 8, "url": "https://..." }
}
```

### Dry-Run / Test Mode

To test without creating issues, use a test repository:

```bash
npm run setup
# Owner: mzfshark
# Repo: test-repo
# Local path: ../AragonOSX (use real repo to scan)

npm run prepare -- --config sync-helper/configs/mzfshark-test-repo.json
# Review: tmp/mzfshark-test-repo/engine-input.json

# Issues will be created in mzfshark/test-repo instead of production repo
npm run execute -- --config sync-helper/configs/mzfshark-test-repo.json
```

## Troubleshooting

**Problem**: `npm run repos` shows "No repositories configured"
- **Solution**: Run `npm run setup` to configure first repository

**Problem**: `npm run prepare` fails with "Config not found"
- **Solution**: Use `--config` flag: `npm run prepare -- --config sync-helper/configs/<name>.json`

**Problem**: Outputs mixing between repos
- **Solution**: Verify each config has unique output paths in `tmp/<owner>-<repo>/`

**Problem**: Want to process all repos at once
- **Solution**: Create bash script that loops through `sync-helper/configs/*.json` (see example above)

## Benefits of New Structure

✅ **Isolated Outputs**: Each repo's files never conflict  
✅ **Easy Selection**: List repos with `npm run repos`  
✅ **Independent Execution**: Work on one repo without affecting others  
✅ **Clear Organization**: Config filename matches output directory  
✅ **Backward Compatible**: Old format still works  
✅ **Scalable**: Add unlimited repositories without config file bloat

## See Also

- [QUICK_START.md](../QUICK_START.md) - Basic commands
- [SETUP_GUIDE.md](SETUP_GUIDE.md) - Detailed setup options
- [README.md](../README.md) - Project overview
