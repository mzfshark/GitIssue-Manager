# GitIssue-Manager

Automate GitHub issue creation from Markdown checklists with optional Project V2 sync.

## Quick Start

```bash
# 1. Interactive setup (press Enter to accept all defaults)
npm run setup

# 2. Prepare engine input from Markdown
npm run prepare

# 3. Execute: create/update issues on GitHub
npm run execute

# Or run both in sequence
npm run full
```

**💡 Tip**: Press **Enter** at each prompt to use default values. See [Setup Guide](docs/SETUP_GUIDE.md) for detailed configuration options.

## Architecture

Two-layer system:

- **Client-side (preparer)**: scans `*.md` checklists, normalizes tasks/subtasks, and outputs JSON.
- **Server-side (executor)**: consumes JSON and performs GitHub operations (issues + optional Project V2 field updates).

This repo is intended to be reusable across repositories via configuration.

## Requirements

- `node` (no npm dependencies required)
- `gh` (GitHub CLI) authenticated (`gh auth status`)

## Configure

Interactive setup wizard guides you through configuration:

```bash
npm run setup
# or: bash sync-helper/setup-sync.sh
```

The script will ask for:
- **Owner**: GitHub username or organization (default: `mzfshark`)
- **Repository**: Repo name without owner (default: `AragonOSX`)
- **Local path**: Where to scan for `*.md` files (default: `../[repo-name]`)
- **Project sync**: Enable GitHub Project V2 integration (default: disabled)

**All prompts support defaults** - just press **Enter** to accept the default value.

This creates `sync-helper/sync-config.json`.

For detailed configuration options and examples, see [Setup Guide](docs/SETUP_GUIDE.md).

- `enableProjectSync`: per target repo.
- If disabled, you can still store a custom Project reference for metadata.

## Client-side: Prepare JSON

```bash
npm run prepare
# or: node client/prepare.js --config sync-helper/sync-config.json
```

Outputs per target (paths are configurable):

- `tmp/tasks.json`
- `tmp/subtasks.json`
- `tmp/engine-input.json`

### Tags in Markdown

You can annotate checklist items with tags:

- `[estimate:2h]`
- `[priority:P1]`
- `[status:In Progress]`
- `[start:2026-01-01]`
- `[end:2026-01-31]`

## Server-side: Execute

```bash
npm run execute
# or: node server/executor.js --input ./tmp/engine-input.json

# Run in background (for large repos)
npm run execute:bg
```

Creates/updates issues on GitHub using `gh` CLI. Idempotent via `stableId` (SHA1 of file:line:text).

## Available Scripts

### Core Workflow
- `npm run setup` - Interactive configuration wizard
- `npm run prepare` - Generate engine input from Markdown
- `npm run execute` - Create/update GitHub issues
- `npm run full` - Run prepare + execute

### Utilities
- `npm run labels:create` - Create standard labels across repos
- `npm run project:help` - Show project field info
- `npm run project:update` - Apply project field updates

### Output Analysis
- `npm run output:summary` - Show execution summary
- `npm run output:errors` - List first 5 errors
- `npm run output:last` - Show last 10 processed items

### Verification
- `npm run verify:issues` - List 10 sync-md issues on GitHub
- `npm run verify:count` - Count total sync-md issues

### Maintenance
- `npm run clean` - Remove generated artifacts

```bash
node server/executor.js --input ./tmp/engine-input.json
```

This currently prints the execution plan.

## JSON schema

See `schemas/engine-input.schema.json`.
