# GitIssue Templates

This folder contains standardized templates for plan and issue tracking files.

## Standard Format

Each template follows the same structure:

1. Title in the format `#  #<TYPE>-NNN - <Title>`
2. Technical info block (repository, dates, priority, estimate, status)
3. Executive Summary
4. Subtasks (Linked) section with checklists under headings that include an ID (e.g., `FEATURE-001`)
5. Milestones section at the end

## Files

- `.gitissue/metadata.config.json`: Default metadata and allowed values.
- `PLAN.md`, `EPIC.md`, `FEATURE.md`, `TASK.md`, `BUG.md`, `HOTFIX.md`: Canonical templates.

## How to use in a target repository

1. Copy the templates to the repository root.
2. Customize defaults and allowed values in `.gitissue/metadata.config.json`.
3. Ensure checklists only appear inside “Subtasks (Linked)” sections.
