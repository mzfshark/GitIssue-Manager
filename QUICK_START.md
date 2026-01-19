# Quick Start Guide

## Installation

No installation needed! Uses Node.js built-in modules + GitHub CLI.

**Prerequisites:**
- Node.js >= 16
- GitHub CLI (`gh`) authenticated

```bash
gh auth status  # Verify authentication
```

## Commands Cheatsheet

### 🚀 First Time Setup
```bash
npm run setup           # Interactive config wizard
npm run labels:create   # Create standard labels (optional)
```

### 📝 Daily Workflow
```bash
# 1. Update your Markdown checklists (*.md files)
# 2. Run:
npm run full            # Prepare + Execute in one command
```

### 🔍 Check Results
```bash
npm run output:summary  # Quick stats
npm run verify:count    # Count issues on GitHub
npm run verify:issues   # List recent issues
```

### 🔧 Advanced
```bash
npm run prepare         # Generate engine-input.json only
npm run execute         # Execute only (uses existing engine-input.json)
npm run execute:bg      # Background execution for large repos
```

### 🐛 Troubleshooting
```bash
npm run output:errors   # Show first 5 errors
npm run output:last     # Show last 10 processed items
npm run clean          # Remove temp files
```

## Example Output

### After `npm run output:summary`:
```json
{
  "executed": "2026-01-19T13:09:09.626Z",
  "repo": "mzfshark/AragonOSX",
  "total": 397,
  "created": 397,
  "errors": 0
}
```

### After `npm run verify:count`:
```
528
```

## Typical Workflow

```bash
# Day 1: Setup
npm run setup
npm run full
npm run verify:count  # Verify issues created

# Day 2: Update Markdown and sync
# Edit some *.md files...
npm run full
npm run output:summary  # Check what changed

# Day 3: Check for issues
npm run verify:issues
# Open browser to review issues
```

## Rate Limits

If you hit rate limits:
1. Wait ~1 hour for reset
2. Re-run `npm run execute` (it's idempotent—will skip existing issues)

## Tips

- Issues are idempotent via `stableId` (SHA1 of file:line:text)
- Changing text creates a new issue; use `stableId` to track identity
- Use `[estimate:2h]` tags inline in Markdown for project tracking
- Enable Project sync in config for automatic Project V2 updates

