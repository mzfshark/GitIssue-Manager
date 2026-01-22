#  #PLAN-002 - Single Source of Truth for Issue Generation (sync-helper + E2E)

Repository: GitIssue-Manager (mzfshark/GitIssue-Manager)
End Date Goal: 2026-01-26
Priority: [ HIGH ]
Estimative Hours: 8h
Status: [ In Progress ]

## Executive Summary

Goal: Make `sync-helper` (prepare + executor) the single source of truth for issue content and metadata, while `e2e-flow-v2.sh` becomes an orchestrator that:
- Uses the already-generated artifacts (`engine-input.json`, `engine-output.json`, `metadata.json`) instead of re-parsing Markdown.
- Creates/updates issues idempotently (fetch first, create only if missing).
- Preserves the parent issue (PAI) description structure using templates and bounded “managed sections” rather than overwriting the whole body.

Non-goals:
- Redesigning the engine schema beyond what is required for orchestration.
- Large-scale refactors of `server/executor.js` unrelated to E2E integration.

Expected outcomes:
- E2E does not create child issues directly from raw checklist text.
- Shortcodes/tags like `[priority:HIGH]` are never part of the issue title and are applied as metadata (labels/project fields).
- Updating progress/hierarchy does not destroy the PLAN/EPIC template body.
- One consistent run path: `prepare` → `executor` → `link hierarchy` → (optional) `project sync validation`.

### Acceptance Criteria

- Running `bash scripts/e2e-flow-v2.sh --dry-run` reaches Stage 8 using prepared artifacts.
- Stage 2 uses `client/prepare.js` (via `sync-helper/configs/*.json`) and writes per-repo artifacts under `tmp/<repo>/`.
- Stage 4 uses `server/executor.js` output to decide which issues exist vs. need creation.
- Stage 5 links GitHub sub-issues using `parentStableId` from prepared data (PAI → tasks, tasks → subtasks).
- Stage 7 updates the PAI body only inside a marked section (no full-body overwrite).

### Key Metrics

- Total Planned Work: 8h
- Completion: 0%
- Active Features: 1
- Open Bugs: 0
- Timeline: 2026-01-22 → 2026-01-26

## Subtasks (Linked)

### PLAN-002:

- [ ] Make Stage 2 call sync-helper prepare and persist artifact paths [labels:type:task, area:gitissue-manager] [status:TODO] [priority:HIGH] [estimate:2h] [start:2026-01-22] [end:2026-01-23]
- [ ] Make Stage 3 create/reuse PAI from templates + plan file content [labels:type:task, area:gitissue-manager] [status:TODO] [priority:HIGH] [estimate:2h] [start:2026-01-22] [end:2026-01-24]
- [ ] Make Stage 4 run executor (idempotent issue upsert) and capture engine-output.json [labels:type:task, area:gitissue-manager] [status:TODO] [priority:HIGH] [estimate:2h] [start:2026-01-23] [end:2026-01-24]
- [ ] Make Stage 5 link hierarchy based on stableId/parentStableId maps [labels:type:task, area:gitissue-manager] [status:TODO] [priority:HIGH] [estimate:1h] [start:2026-01-24] [end:2026-01-25]
- [ ] Make Stage 7 update progress via bounded markers (no overwrite) [labels:type:task, area:gitissue-manager] [status:TODO] [priority:MEDIUM] [estimate:1h] [start:2026-01-25] [end:2026-01-26]

## Milestones

- Milestone 1: E2E consumes prepared artifacts → 2026-01-24
- Milestone 2: Hierarchy + PAI template preserved → 2026-01-26

---

## Archive

### PLAN-001 - Fix ProjectV2 GraphQL Variable Handling (GitIssue-Manager)

Archived: 2026-01-22 (superseded by PLAN-002)
