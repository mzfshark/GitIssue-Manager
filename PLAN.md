# #PLAN-002 - Single Source of Truth for Issue Generation (sync-helper + E2E) [key:01KFXQ0FJPGFR7BX34GK62ZCAD]

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

### PLAN-002: [key:01KFXQ0FJRYKKPR24V1YHA8KXY]

- [ ] Make Stage 2 call sync-helper prepare and persist artifact paths [labels:type:task, area:gitissue-manager] [status:TODO] [priority:HIGH] [estimate:2h] [start:2026-01-22] [end:2026-01-23] [key:01KFXQ0FJRYKKPR24V1YHA8KXZ]
- [ ] Fix Stage 2 plan resolution to use `<repoRoot>/docs/plans/` by default (avoid hardcoded sibling paths) [labels:type:task, area:gitissue-manager] [status:TODO] [priority:MEDIUM] [estimate:0.5h] [start:2026-01-23] [end:2026-01-23] [key:01KFXQ0FJRYKKPR24V1YHA8KY0]
- [ ] Add `gitissuer sync` command (prepare + deploy + registry:update) as a first-class CLI workflow [labels:type:task, area:gitissue-manager] [status:TODO] [priority:MEDIUM] [estimate:0.5h] [start:2026-01-23] [end:2026-01-23] [key:01KFXQ0FJRYKKPR24V1YHA8KY1]
- [ ] Make `gitissuer` portable: add `doctor/install` commands and a repo-local zero-config fallback config under `.gitissuer/` [labels:type:task, area:gitissue-manager] [status:TODO] [priority:HIGH] [estimate:1h] [start:2026-01-23] [end:2026-01-23] [key:01KFXQ0FJRYKKPR24V1YHA8KY2]
- [ ] Harden Axodus maintenance scripts (archive/close) to fail closed on API errors and avoid silent hangs (timeouts + logs) [labels:type:task, area:gitissue-manager] [status:TODO] [priority:HIGH] [estimate:0.5h] [start:2026-01-25] [end:2026-01-25] [key:01KFXQ0FJSN7T122BPFED3Z56B]
- [ ] Make Stage 3 create/reuse PAI from templates + plan file content [labels:type:task, area:gitissue-manager] [status:TODO] [priority:HIGH] [estimate:2h] [start:2026-01-22] [end:2026-01-24] [key:01KFXQ0FJSN7T122BPFED3Z56C]
- [ ] Make Stage 4 run executor (idempotent issue upsert) and capture engine-output.json [labels:type:task, area:gitissue-manager] [status:TODO] [priority:HIGH] [estimate:2h] [start:2026-01-23] [end:2026-01-24] [key:01KFXQ0FJSN7T122BPFED3Z56D]
- [ ] Add `deploy --dry-run` support in `scripts/gitissuer.sh` (no writes; allow `--link-hierarchy` to dry-run too) [labels:type:task, area:gitissue-manager] [status:TODO] [priority:HIGH] [estimate:0.5h] [start:2026-01-23] [end:2026-01-23] [key:01KFXQ0FJSN7T122BPFED3Z56E]
- [ ] Make Stage 5 link hierarchy based on stableId/parentStableId maps [labels:type:task, area:gitissue-manager] [status:TODO] [priority:HIGH] [estimate:1h] [start:2026-01-24] [end:2026-01-25] [key:01KFXQ0FJSN7T122BPFED3Z56F]
- [ ] Make Stage 7 update progress via bounded markers (no overwrite) [labels:type:task, area:gitissue-manager] [status:TODO] [priority:MEDIUM] [estimate:1h] [start:2026-01-25] [end:2026-01-26] [key:01KFXQ0FJSN7T122BPFED3Z56G]

## Milestones

- Milestone 1: E2E consumes prepared artifacts → 2026-01-24
- Milestone 2: Hierarchy + PAI template preserved → 2026-01-26

---

# PLAN-003 - Per-Repo Registry + ISSUE_UPDATES Apply Engine [key:01KFXQ0FJSN7T122BPFED3Z56H]

Repository: GitIssue-Manager (mzfshark/GitIssue-Manager)
End Date Goal: 2026-01-30
Priority: [ HIGH ]
Estimative Hours: 10h
Status: [ TODO ]

## Executive Summary

Goal: Add an explicit, per-repo issue identity registry under `.gitissuer/registry/` and introduce `ISSUE_UPDATES.md` as a safe swap-file for small, deterministic actions against known issues.

This plan hardens idempotency and auditability:
- Registry is the source of truth that maps stable IDs (or explicit IDs) to GitHub issue/node IDs.
- `ISSUE_UPDATES.md` actions MUST target existing registry entries; no best-effort matching.
- Default execution is dry-run; GitHub writes require explicit confirmation.

Non-goals:
- Full redesign of the engine schema.
- Backward compatibility with legacy repo list configs (configs-only is acceptable in DEV).
- Bulk migration of historic issues without a plan fingerprint.

Expected outcomes:
- No more “false success”: apply reports reflect what was actually changed.
- Reliable deduplication: repeated runs do not create duplicate issues.
- Safe operator workflow: edit `ISSUE_UPDATES.md`, preview, then apply with confirm.

### Acceptance Criteria

- Each repo has a registry file `.gitissuer/registry/issue-registry.json` created/updated deterministically from `engine-input.json` + `engine-output.json`.
- `ISSUE_UPDATES.md` supports actions: `open`, `reopen`, `close`, with optional `labels`, `comment`, `estimate`, `endDate`.
- Dry-run output includes a machine-readable report (JSON) and a human summary (Markdown).
- Apply mode requires `--confirm` and logs an audit record under `.gitissuer/updates/`.
- Actions referencing unknown IDs fail fast with a clear error (no fuzzy matching).

## Subtasks (Linked)

### PLAN-003: [key:01KFXQ0FJSN7T122BPFED3Z56J]

- [ ] Define registry schema and report schema [labels:type:task, area:gitissue-manager] [status:TODO] [priority:HIGH] [estimate:2h] [start:2026-01-23] [end:2026-01-24] [key:01KFXQ0FJSN7T122BPFED3Z56K]
- [ ] Implement registry read/write helpers + atomic update [labels:type:task, area:gitissue-manager] [status:TODO] [priority:HIGH] [estimate:2h] [start:2026-01-24] [end:2026-01-25] [key:01KFXQ0FJSN7T122BPFED3Z56M]
- [ ] Implement ISSUE_UPDATES.md parser with strict validation [labels:type:task, area:gitissue-manager] [status:TODO] [priority:HIGH] [estimate:2h] [start:2026-01-25] [end:2026-01-26] [key:01KFXQ0FJSN7T122BPFED3Z56N]
- [ ] Make `registry:update` infer outputs from `<repo>/tmp/*.json` when missing in config (zero-to-hero flow) [labels:type:task, area:gitissue-manager] [status:TODO] [priority:MEDIUM] [estimate:0.5h] [start:2026-01-23] [end:2026-01-23] [key:01KFXQ0FJSN7T122BPFED3Z56P]
- [ ] Fix configs missing `outputs.*` so `registry:update` works after `prepare`/`deploy` [labels:type:task, area:gitissue-manager] [status:TODO] [priority:MEDIUM] [estimate:0.5h] [start:2026-01-23] [end:2026-01-23] [key:01KFXQ0FJSN7T122BPFED3Z56Q]
- [ ] Make apply skip missing registry when there are no actionable updates (improves `apply --all` UX) [labels:type:task, area:gitissue-manager] [status:TODO] [priority:MEDIUM] [estimate:0.5h] [start:2026-01-23] [end:2026-01-23] [key:01KFXQ0FJSN7T122BPFED3Z56R]
- [ ] Implement dry-run and apply modes with confirmation gate [labels:type:task, area:gitissue-manager] [status:TODO] [priority:HIGH] [estimate:3h] [start:2026-01-26] [end:2026-01-29] [key:01KFXQ0FJSN7T122BPFED3Z56S]
- [ ] Wire daemon to run apply step (dry-run by default) [labels:type:task, area:gitissue-manager] [status:TODO] [priority:MEDIUM] [estimate:1h] [start:2026-01-29] [end:2026-01-30] [key:01KFXQ0FJSN7T122BPFED3Z56T]

---

## Archive

### PLAN-001 - Fix ProjectV2 GraphQL Variable Handling (GitIssue-Manager) [key:01KFXQ0FJSN7T122BPFED3Z56V]

Archived: 2026-01-22 (superseded by PLAN-002)
