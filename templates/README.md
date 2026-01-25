# GitIssue Templates

This folder contains standardized templates for plan and issue tracking files.

## Standard Format

Each template follows the same structure:

1. Title in the format `#  #<TYPE>-NNN - <Title>`
2. Technical info block (repository, dates, priority, estimate, status)
3. Executive Summary
4. Subtasks (Linked) section with checklists under headings that include an ID (e.g., `FEATURE-001`)
5. Milestones section at the end

### Canonical identity (recommended)

To prevent duplicate GitHub issues when checklist items are moved or edited, add a canonical key tag to every checklist item you expect to sync:

- Example: `- [ ] Do something [key:01J0ABCDE...] [labels:...] [status:TODO] ...`

Recommended format: ULID (26 chars, time-sortable).

You can auto-inject missing keys safely:

- Preview: `gitissuer rekey --repo <owner/name> --dry-run`
- Apply: `gitissuer rekey --repo <owner/name> --confirm`

When present, GitIssue-Manager derives a stable `StableId` from `key`, and also writes `Key: ...` into the GitHub issue body.

### GitHub issue title format

GitIssue-Manager creates GitHub issues using a breadcrumb title format (no `-NNN` numbering in the GitHub title):

- Example: `[PLAN / EPIC / TASK] - Title`

The `TYPE-NNN` numbering remains in Markdown to keep the document structured and searchable.

## Files

- `.gitissue/metadata.config.json`: Default metadata and allowed values.
- `PLAN.md`, `EPIC.md`, `FEATURE.md`, `TASK.md`, `BUG.md`, `HOTFIX.md`: Canonical templates.

## How to use in a target repository

1. Copy the templates to the repository root.
2. Customize defaults and allowed values in `.gitissue/metadata.config.json`.
3. Ensure checklists only appear inside “Subtasks (Linked)” sections.
