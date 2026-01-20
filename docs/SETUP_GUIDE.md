# Setup Guide

Complete guide for configuring GitIssue-Manager for your repositories.

## Quick Setup (Using Defaults)

The fastest way to get started is to press **Enter** for all prompts to use defaults:

```bash
yarn setup
# Press Enter 5+ times to accept all defaults
```

This creates a configuration for:
- Owner: `mzfshark`
- Repo: `AragonOSX`
- Local path: `../AragonOSX`
- Project sync: **disabled**
- Default estimate: `1 hour` per subtask

## Interactive Setup Options

### 1. Repository Configuration

**Owner Selection**
```
Owner (GitHub user or organization) [default: mzfshark]: 
```
- Press **Enter** to use `mzfshark`
- Or type your GitHub username or organization name

**Repository Name**
```
Repository name (without owner) [default: AragonOSX]: 
```
- Press **Enter** to use `AragonOSX`
- Or type your repository name (without the owner prefix)

The script combines these into full format: `owner/repo`

**Local Path**
```
Local path to scan for *.md [default: ../AragonOSX]: 
```
- Press **Enter** to use `../[repo-name]`
- Or provide absolute/relative path to repository

### 2. Project Sync Configuration

**Enable Project Sync**
```
Enable Project sync for this repo? [y/N]: 
```
- Press **Enter** for `N` (disabled)
- Type `y` to enable GitHub Project V2 sync

#### If Project Sync Enabled (y):

**Select Project Method**
```
Project selection (user projects V2):
  1) List projects via gh and select
  2) Paste project URL (https://github.com/users/<user>/projects/<id>)
Choose (1/2) [1]: 
```

**Option 1** (default): Lists your projects via `gh` CLI
- Select project number from the list
- Script extracts project URL and nodeId automatically

**Option 2**: Manual URL entry
```
Project URL: https://github.com/users/mzfshark/projects/5
```

#### If Project Sync Disabled (N):

**Store Project Reference (Optional)**
```
Store a custom Project reference for metadata anyway? (y/N): 
```
- Press **Enter** for `N` (no project metadata)
- Type `y` to store project info without enabling sync

### 3. Default Configuration

**Estimate Hours Per Subtask**
```
Default estimate hours per subtask (default 1): 
```
- Press **Enter** to use `1` hour
- Or specify default hours (e.g., `2`, `0.5`)

**Output Paths**
```
Output tasks.json path (default ./tmp/tasks.json): 
Output subtasks.json path (default ./tmp/subtasks.json): 
Output engine-input.json path (default ./tmp/engine-input.json): 
```
- Press **Enter** for all to use defaults under `./tmp/`
- Or customize paths as needed

## Configuration Examples

### Example 1: Personal Repository (All Defaults)

**Inputs**: Press Enter for all prompts

**Generated Config**:
```json
{
  "owner": "mzfshark",
  "targets": [
    {
      "repo": "mzfshark/AragonOSX",
      "localPath": "../AragonOSX",
      "enableProjectSync": false
    }
  ]
}
```

### Example 2: Organization Repository with Project Sync

**Inputs**:
- Owner: `my-org`
- Repo: `my-project`
- Enable Project: `y`
- Select project: `1` → choose from list

**Generated Config**:
```json
{
  "owner": "my-org",
  "project": {
    "url": "https://github.com/users/my-org/projects/15",
    "number": 15
  },
  "targets": [
    {
      "repo": "my-org/my-project",
      "localPath": "../my-project",
      "enableProjectSync": true
    }
  ]
}
```

### Example 3: Multiple Repos (Run Setup Multiple Times)

Setup is designed for single-repo configuration. To manage multiple repos:

**Option A**: Run setup multiple times, then merge configs manually
```bash
yarn setup  # Configure repo 1
mv sync-helper/sync-config.json sync-helper/config-repo1.json

yarn setup  # Configure repo 2
# Manually merge targets[] arrays
```

**Option B**: Manually edit `sync-config.json` and duplicate the targets entry:
```json
{
  "owner": "mzfshark",
  "targets": [
    {
      "repo": "mzfshark/AragonOSX",
      "localPath": "../AragonOSX",
      "enableProjectSync": false
    },
    {
      "repo": "mzfshark/aragon-app",
      "localPath": "../aragon-app",
      "enableProjectSync": true
    }
  ]
}
```

## Configuration File Structure

The setup script generates `sync-helper/sync-config.json`:

```json
{
  "owner": "mzfshark",                    // GitHub owner (user or org)
  "project": {                             // Global project settings
    "url": "https://...",                  // Project V2 URL
    "number": 15,                          // Project number
    "fieldIds": {                          // Field IDs (obtain via gh)
      "statusFieldId": "",
      "priorityFieldId": "",
      "estimateHoursFieldId": "251668000",
      "startDateFieldId": "",
      "endDateFieldId": ""
    }
  },
  "defaults": {
    "defaultEstimateHours": 1              // Default estimate per subtask
  },
  "targets": [                             // Array of repos to process
    {
      "repo": "mzfshark/AragonOSX",        // Full repo path
      "localPath": "../AragonOSX",         // Where to scan for *.md
      "enableProjectSync": false,          // Whether to sync to Project V2
      "outputs": {                         // Output paths
        "tasksPath": "./tmp/tasks.json",
        "subtasksPath": "./tmp/subtasks.json",
        "engineInputPath": "./tmp/engine-input.json"
      }
    }
  ]
}
```

## Post-Setup Steps

After running setup:

1. **Review Configuration**
   ```bash
   cat sync-helper/sync-config.json
   ```

2. **Get Project Field IDs** (if Project sync enabled)
   ```bash
   yarn project:help
   # Follow instructions to extract field IDs via gh CLI
   ```

3. **Run Prepare**
   ```bash
   yarn prepare
   # Scans Markdown files and generates engine-input.json
   ```

4. **Review Generated Tasks**
   ```bash
   yarn output:summary
   ```

5. **Execute** (creates GitHub issues)
   ```bash
   yarn execute
   ```

## Troubleshooting

**Issue**: "Could not resolve viewer login via gh"
- **Solution**: Authenticate with `gh auth login`

**Issue**: "Command 'jq' not found"
- **Solution**: Install jq: `sudo apt install jq` (Ubuntu/WSL) or `brew install jq` (macOS)

**Issue**: Defaults not applied when pressing Enter
- **Verify**: Script shows `[default: value]` in prompt
- **Verify**: Using Bash 4.0+ (`bash --version`)

**Issue**: Project sync not working
- **Verify**: `gh` CLI has `project` scope: `gh auth status`
- **Verify**: Field IDs are correct in config
- **Solution**: Re-authenticate: `gh auth login -s project`

## Advanced Configuration

### Custom Default Values

Edit `setup-sync.sh` to change defaults:

**Line 66**: Change default owner
```bash
OWNER=${OWNER:-your-org-name}
```

**Line 69**: Change default repo
```bash
REPO_NAME=${REPO_NAME:-your-default-repo}
```

**Line 142**: Change default estimate
```bash
DEFAULT_ESTIMATE=${DEFAULT_ESTIMATE:-2}  # 2 hours instead of 1
```

### Field ID Discovery

To get Project V2 field IDs:

```bash
gh api graphql -f query='
query($login: String!, $number: Int!) {
  user(login: $login) {
    projectV2(number: $number) {
      fields(first: 20) {
        nodes {
          ... on ProjectV2Field {
            id
            name
          }
          ... on ProjectV2SingleSelectField {
            id
            name
            options { name }
          }
        }
      }
    }
  }
}' -f login="mzfshark" -F number=15
```

Update `fieldIds` in `sync-config.json` with the returned IDs.

## See Also

- [QUICK_START.md](QUICK_START.md) - Command reference
- [README.md](../README.md) - Project overview
- [package.json](../package.json) - All available npm scripts
