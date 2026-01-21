## Intent
Standardize planning artifacts across repositories (SPRINT/PLAN/TASK/FEATURE/BUG) and update GitIssue-Manager to generate and maintain a single Sprint issue per repo, containing an internal checklist tree, while keeping other artifacts as internal sources of truth.

## Process
1. Define strict file conventions and English templates.
2. Update parsing so only SPRINT.md produces a single aggregated “Sprint issue”.
3. Ensure ProjectV2 sync sets Status to exactly “Ready” when Sprint completion reaches 100%.
4. Add guardrails (dry-run defaults, preflight checks, and idempotency markers).

## File Convention (Per Target Repo)
### Issue-producing artifact
- SPRINT.md (parent sprint; ONLY file that generates an issue)

### Optional sub-sprints (linked from SPRINT.md)
- SPRINT_<SUB>.md (e.g., SPRINT_BUGFIX.md, SPRINT_BACKEND.md)

### Internal artifacts (do NOT generate issues by default)
- PLAN.md
- BUG.md
- FEATURE.md
- TASK.md

## Item ID Convention (Required)
Each checklist item must start with a stable explicit ID:
- BUG-001, TASK-014, FEATURE-003, PLAN-010

This ID must remain stable across edits and file moves.

## Definition of Done / Status Rules
- Sprint completion = all checklist items under “Work Tree” are checked (including nested items).
- When Sprint completion is 100%:
  - Set ProjectV2 Status to exactly "Ready" (case-sensitive target string; option match may be case-insensitive).
- Otherwise:
  - Keep default status (e.g., TODO) or existing status depending on execution mode.

## Scope & Deliverables
- Exactly one “Sprint issue” per repo/target with full internal checklist tree from SPRINT.md.
- No automatic creation of per-item issues (keeps UI clean and reduces issue noise).
- ProjectV2 sync: Status → Ready only when complete, plus (optional) estimate/date/priority if configured.
- Clear documentation explaining: what creates issues vs what stays internal.

## Work Items

- [ ] Define templates and naming rules [labels:planning,docs] [status:TODO] [priority:HIGH] [estimate:3h] [start:2026-01-21] [end:2026-01-22]
  Acceptance Criteria:
  - English templates exist for SPRINT.md, SPRINT_<SUB>.md, PLAN.md, BUG.md, FEATURE.md, TASK.md
  - Examples use TYPE-NNN IDs consistently (BUG-001, etc.)
  Risks:
  - Repo drift; mitigate with copyable templates and “rules” section.

- [ ] Implement “Sprint Single-Issue Mode” in prepare pipeline [labels:feature,prepare] [status:TODO] [priority:HIGH] [estimate:6h] [start:2026-01-22] [end:2026-01-23]
  Implementation Notes:
  - Parse SPRINT.md as the only issue-producing artifact
  - Support optional inclusion of SPRINT_<SUB>.md referenced via Markdown links in SPRINT.md
  - Produce exactly one aggregated task per target
  - Use stableId derived from sprint identity (not from line numbers) to avoid duplication
  Acceptance Criteria:
  - Prepare output contains exactly 1 task per target when SPRINT.md exists
  - Task body contains the full checklist tree (indentation preserved)
  - Completion state is derived from checkboxes (all checked => Ready)

- [ ] Update executor to upsert only the Sprint issue in this mode [labels:feature,executor] [status:TODO] [priority:HIGH] [estimate:5h] [start:2026-01-23] [end:2026-01-24]
  Acceptance Criteria:
  - Issue title is stable and predictable (e.g., "SPRINT: <name> (YYYY-MM-DD → YYYY-MM-DD)")
  - Body includes an idempotency marker and stable references
  - No per-item issues are created/updated

- [ ] ProjectV2 “Ready” exact-option sync + preflight validation [labels:projectv2,safety] [status:TODO] [priority:HIGH] [estimate:3h] [start:2026-01-24] [end:2026-01-24]
  Acceptance Criteria:
  - When sprint completion is 100%, Status is set to exactly "Ready"
  - If the Status field does not contain an option named "Ready", fail with a clear actionable error
  - If sprint is not complete, do not set Status to Ready
  Notes:
  - Prefer resolving fields by project number + field name when possible (avoid numeric UI ids).

- [ ] Document workflow (“What creates issues” vs “What stays internal”) [labels:docs] [status:TODO] [priority:NORMAL] [estimate:2h] [start:2026-01-24] [end:2026-01-25]
  Acceptance Criteria:
  - Only SPRINT.md becomes an issue
  - Clear rules for sub-sprints (SPRINT_<SUB>.md) and linking from SPRINT.md
  - Examples of TYPE-NNN usage and editing do/don’t guidance

- [ ] Safety defaults and auditability [labels:safety] [status:TODO] [priority:NORMAL] [estimate:2h] [start:2026-01-25] [end:2026-01-25]
  Acceptance Criteria:
  - Default mode is safe (dry-run / no destructive actions without explicit flags)
  - Outputs include a concise JSON summary of intended changes (create/update/project field updates)

## Test Plan (Manual)
- Prepare:
  - With a repo containing SPRINT.md, confirm output contains exactly one aggregated task per target.
- Execute:
  - Run in dry-run (or safe mode) and verify intended create/update/project updates.
  - Verify Status is updated to Ready only when all checklist items are checked.
- Regression:
  - Confirm PLAN.md/BUG.md/FEATURE.md/TASK.md do not create issues by default.

## Risks & Mitigations (Red Team)
- Risk: IDs change (line-based) → duplicated issues.
  - Mitigation: require explicit TYPE-NNN IDs, and make stableId derive from sprint identity / explicit IDs (not from line numbers).
- Risk: ProjectV2 Status option "Ready" missing or renamed.
  - Mitigation: preflight check; fail with remediation steps.
- Risk: Numeric field IDs in config prevent updates.
  - Mitigation: resolve field node IDs by name via project schema discovery; document required setup step.
