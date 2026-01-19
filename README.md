# GitIssue-Manager

Two-layer system:

- **Client-side (preparer)**: scans `*.md` checklists, normalizes tasks/subtasks, and outputs JSON.
- **Server-side (executor)**: consumes JSON and performs GitHub operations (issues + optional Project V2 field updates).

This repo is intended to be reusable across repositories via configuration.

## Requirements

- `node` (no npm dependencies required)
- `gh` (GitHub CLI) authenticated (`gh auth status`)

## Configure

Interactive setup:

```bash
bash sync-helper/setup-sync.sh
```

This creates `sync-helper/sync-config.json`.

- `enableProjectSync`: per target repo.
- If disabled, you can still store a custom Project reference for metadata.

## Client-side: Prepare JSON

```bash
node client/prepare.js --config sync-helper/sync-config.json
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

## Server-side: Execute (scaffold)

```bash
node server/executor.js --input ./tmp/engine-input.json
```

This currently prints the execution plan.

## JSON schema

See `schemas/engine-input.schema.json`.
