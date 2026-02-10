# [EPIC-LogicConvergence | SPRINT-001 | TASK-001] Canonical Title Generator

**Repository:** GitIssue-Manager  
**Parent:** [EPIC-LogicConvergence | SPRINT-001](../plans/SPRINT_001_CORE_UNIFICATION.md)  
**Type:** TASK  
**Key:** 01JPHC8GW7P1UI3MCRASVB2EAX  
**Status:** TODO  
**Priority:** HIGH  
**Estimate:** 4h

---

## Technical Summary

Standardizes how GitHub issue titles are generated and updated. The titles must follow the strict hierarchy format: `[<PLAN_SLUG> | SPRINT-XXX | <TYPE>-NNN] <Task Title>`.

The refactor will:
1. Extract the current Slug and Level from the Markdown hierarchy context.
2. Build the title prefix dynamically.
3. Compare the generated title with the actual GitHub title.
4. Update via `gh issue edit --title` if they differ.

## Acceptance Criteria

- [ ] Every issue created or synchronized by `gitissuer` has a title formatted exactly as per the protocol.
- [ ] If a task is moved from one SPRINT to another in Markdown, its GitHub title is updated with the new SPRINT slug on the next sync.

## Implementation Notes

- Add a `generateCanonicalTitle(item, context)` helper to the parser/executor.
- Ensure `title` synchronization is part of the core update loop in [server/executor.js](server/executor.js).
