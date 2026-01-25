# GitIssue-Manager

**Stop writing GitHub issues manually. Write planning documents once, auto-sync to GitHub, with full audit trail.**

A lightweight Node.js toolset that converts Markdown planning documents (like `SPRINT.md`, `PLAN.md`) into structured GitHub issues and ProjectV2 project boards, with safe dry-run previews, repository-aware prefixes, and complete audit logging.

Think of it as a **bridge between your planning docs and your GitHub issue tracker**—no copy-paste, no typos, no lost context.

## What it solves
- ❌ **Problem:** Create 30+ sprint issues manually → copy titles, paste descriptions, add labels, attach to project → repeat every sprint.  
- ✅ **Solution:** Write `SPRINT.md` once → GitIssue-Manager parses it → dry-run preview → one-click apply.

## Key goals
- **Parse** Markdown planning files into issue hierarchies (tasks + subtasks).
- **Preview** all changes before touching GitHub (dry-run mode, no surprises).
- **Standardize** issue titles with repo-aware prefixes (e.g., `[aragon-app | #FEATURE-001]`).
- **Sync** to GitHub issues and ProjectV2 boards in one safe operation.
- **Audit** every change: who, what, when, why (JSONL log).

## Visual Flow (How it Works)

```
┌──────────────────┐
│   Your Repo      │
│   (SPRINT.md,    │
│    PLAN.md)      │
└────────┬─────────┘
         │
         ▼
┌──────────────────────────────┐
│  GitIssue-Manager (Parser)   │
│  ✓ Extract checklist items   │
│  ✓ Read metadata (priority)  │
│  ✓ Generate stable IDs       │
│  ✓ Create engine-input.json  │
└────────┬─────────────────────┘
         │
         ▼
┌──────────────────────────────┐
│  Dry-Run Mode (Preview)      │
│  ✓ Show what will be created │
│  ✓ Validate ProjectV2 fields │
│  ✓ Check for duplicates      │
│  ✓ JSON summary report       │
└────────┬─────────────────────┘
         │
    [Team Reviews]
         │
    [Approves]
         │
         ▼
┌──────────────────────────────┐
│  Execute Mode (Real Write)   │
│  ✓ Create/update issues      │
│  ✓ Attach to ProjectV2       │
│  ✓ Add labels & metadata     │
│  ✓ Log audit trail           │
└────────┬─────────────────────┘
         │
         ▼
┌──────────────────┐
│  GitHub Issues   │
│  + ProjectV2     │
│  + Audit Log     │
└──────────────────┘
```

---

## Overview
GitIssue-Manager is a **single-purpose tool**: take your Markdown planning files (where you outline sprints, features, bugs) and convert them into GitHub issues + ProjectV2 board items automatically.

**Why?**
- Writing issues in GitHub UI is slow (lots of copy-paste, field switching, re-typing).
- Planning in Markdown is fast (outline, edit, version-control with git).
- Bridge the gap: write once in Markdown, sync once to GitHub.

**For teams with:**
- Multiple repositories (monorepo or microservices)
- Regular sprints or large feature rollouts
- Need for audit trail and approval workflows
- Preference for writing plans in Markdown (docs, version-control, diffs)

## Features

| Feature | Why it matters | Example |
|---------|---------------|---------|
| **Markdown parser** | Write plans naturally; tool extracts structure | `SPRINT.md` → tasks → GitHub issues |
| **Stable IDs (`TYPE-NNN`)** | Move items between files; identity stays the same | `FEATURE-042` always maps to the same issue |
| **Dry-run preview** | Review changes before applying them to GitHub | See JSON output; no GitHub writes yet |
| **Repository-aware titles** | Quickly identify which repo an issue belongs to | `[aragon-app \| #FEATURE-001]` format |
| **ProjectV2 sync** | Automatically attach issues to your board | Create issue + add to project in one go |
| **Audit log (JSONL)** | Full record: who, what, when, why | `logs/audit.jsonl` for compliance/debugging |
| **Per-repo safety** | Apply changes one repo at a time | Reduces risk; easy rollback |

## Architecture & Key Files

| Component | File | Role | Input | Output |
|-----------|------|------|-------|--------|
| **Parser** | `client/prepare.js` | Reads Markdown, extracts tasks | SPRINT.md, config.json | engine-input.json |
| **Executor** | `server/executor.js` | Writes to GitHub or previews | engine-input.json | GitHub issues + audit.jsonl |
| **Helper** | `scripts/cleanup.sh` | Repo cleanup (dry-run + execute) | target repo | cleanup results |
| **Config** | `sync-helper/configs/*.json` | Specifies which repos to target | manual edit | parsed by prepare.js |
| **Audit log** | `logs/audit.jsonl` | Record of all GitHub writes | (append-only) | compliance / debugging |

### Single-file artifacts (convention)
Keep one artifact per file for stability:
- `SPRINT.md` — current sprint (canonical)
- `PLAN.md` — long-term roadmap
- `FEATURE.md` — feature details
- `BUG.md` — bug tracking
- `TASK.md` — ad-hoc tasks

## Quickstart (5 minutes)

### 1. Install
```bash
cd GitIssue-Manager
pnpm install
# Or: npm install / yarn install
```

Optional (recommended): install `gitissuer` globally pointing to this checkout:

```bash
# From the GitIssue-Manager repo
gitissuer install
# (equivalent to: npm link)

# Verify what is running
gitissuer doctor
```

If you previously had a legacy hardcoded install (e.g. `/opt/GitIssue-Manager`), run `gitissuer doctor` and re-install via `npm link` so your PATH resolves to the current workspace code.

If `command -v gitissuer` still resolves to `/usr/local/bin/gitissuer` and `gitissuer doctor` shows `/opt/GitIssue-Manager`, you likely have a root-owned legacy wrapper. You can replace it (requires sudo):

```bash
sudo rm -f /usr/local/bin/gitissuer
sudo ln -sf "$(npm prefix -g)/bin/gitissuer" /usr/local/bin/gitissuer
```

### 2. Prepare your plan file
Create or edit `SPRINT.md` in your repo root:

```markdown
# Sprint 1: Validator Address Normalization

## FEATURE-001: Fix validator addresses
- [ ] Normalize all stored validator addresses to checksummed format
- [ ] Update API endpoints to return normalized addresses
- [ ] Add integration tests for address format
  - [ ] Test uppercase/lowercase variants
  - [ ] Test with real blockchain data

## FEATURE-002: Add address validation middleware
- [ ] Create validation function in shared utilities
- [ ] Integrate into all DAO-related routes
```

### 3. Generate engine input (parse plan)
```bash
node client/prepare.js --config sync-helper/configs/sample-config.json
```

Output: `tmp/engine-input.json` (contains structured tasks ready for GitHub).

### 4. Preview changes (dry-run)
```bash
node server/executor.js --input tmp/engine-input.json --dry-run
```

Check outputs:
- `logs/dryrun_summary_*.json` — JSON summary of what will be created
- Terminal output — validation warnings/errors (if any)

### 5. Review & approve
Open `logs/dryrun_summary_*.json` in your editor and verify:
- Issue titles look good (`[repo | #TYPE-NNN]` format)
- Descriptions match your intent
- Labels are correct

### 6. Execute (real GitHub write)
```bash
node server/executor.js --input tmp/engine-input.json --execute
```

Done! Check your GitHub repo—issues should be created and linked to ProjectV2.

---

## Understanding the Workflow

### Stage 1: Parse (Client)
- **What:** Read Markdown files (SPRINT.md, PLAN.md, FEATURE.md, BUG.md, etc.)
- **How:** Extract checklist items and metadata (priority, assignee, labels)
- **Output:** `tmp/engine-input.json` — machine-readable task list
- **Who:** Run `client/prepare.js`

### Stage 2: Preview (Executor, dry-run)
- **What:** Simulate GitHub writes without touching GitHub
- **How:** Generate issue JSON, check ProjectV2 field compatibility
- **Output:** `logs/dryrun_summary_*.json` — review before applying
- **Who:** Run `server/executor.js --dry-run`

### Stage 3: Apply (Executor, execute)
- **What:** Real GitHub writes (create/update issues, attach to ProjectV2)
- **How:** Call GitHub GraphQL API; append audit log
- **Output:** Issues in GitHub + entries in `logs/audit.jsonl`
- **Who:** Run `server/executor.js --execute` (after approval)

## Workflow: prepare → dry-run → execute
1. Prepare:
   - The parser reads `PLAN.md`, `SPRINT.md`, and referenced single-file artifacts, and emits `engine-input.json`.
2. Dry-run:
   - Executor simulates GitHub writes; produces `logs/dryrun_summary_*.json` and an audit preview.
3. Review:
   - Team reviews diffs, generated titles, and ProjectV2 mappings.
4. Execute:
   - Executor applies changes to GitHub and writes final audit entries to `logs/audit.jsonl`.

## Configuration
- Configs support top-level `repo` or a `targets[]` array (the parser accepts both forms).
- ProjectV2 field mapping: only `text`, `number`, `date`, `singleSelectOptionId`, and `iterationId` are reliably supported for updates via GraphQL.

## Conventions & Best Practices

### 1. Use explicit IDs (`TYPE-NNN`)
Start each task with an explicit ID so it stays stable when you move files:

```markdown
## FEATURE-001: Normalize validator addresses
- [x] Subtask A
- [ ] Subtask B
```

✅ Good: ID stays the same across file moves; easy to track.  
❌ Bad: No ID; if you move this task to a different file, it gets a new ID (duplicate issue created).

### 2. One artifact per file
```
repo/
  SPRINT.md         ← Current sprint (canonical)
  PLAN.md           ← Long-term roadmap
  FEATURE.md        ← Feature backlog
  BUG.md            ← Bug tracking
  TASK.md           ← Ad-hoc tasks
```

Keeps things organized and stable.

### 3. Checklist structure
```markdown
## FEATURE-001: Main feature title
- [ ] First task
  - [ ] Subtask 1.1
  - [ ] Subtask 1.2
- [ ] Second task
```

Parser extracts both parent tasks and subtasks. Subtasks become issue checklists.

### 4. Add metadata (optional)
Inline tags for priority, estimates, assignees:

```markdown
## FEATURE-042: Big refactor [priority:high] [estimate:13 days] [labels:backend,tech-debt]
- [ ] Phase 1
- [ ] Phase 2
```

Parsed and added to the GitHub issue.

## Audit & Safety
- All write operations append records to `logs/audit.jsonl`. Each record includes timestamp, operation type, target repo/issue, and a caller identifier.
- Dry-run is the default safety mode. Execution requires explicit `--execute` flag.
- All multi-repo or bulk operations should be executed per-repo to limit blast radius.

## Troubleshooting
- If ProjectV2 attachments fail: ensure project permissions and the correct project ID; use two-step flow — create issue, then add to ProjectV2.
- If code-quality/Codacy CLI fails in your environment: check Codacy CLI availability; see `.github/instructions/codacy.instructions.md`.
- If stableIds change unexpectedly: prefer `TYPE-NNN` IDs to avoid file-line-based stableId volatility.

## Contribution & Development
- Follow the repository conventions: English for public-facing docs and commit messages.
- Run tests and linting before proposing changes.
- Use per-repo dry-run + review cycle for any change that updates multiple repositories or many issues.

## Useful Links (repo-local)
- Parser: `client/prepare.js`
- Executor: `server/executor.js`
- Cleanup: `scripts/cleanup.sh`
- Plan: `PLAN.md`

## License & Contact
- License: see repository `LICENSE`.
- For questions or to schedule a demo, contact the repo owner or the engineering lead listed in the repository metadata.
