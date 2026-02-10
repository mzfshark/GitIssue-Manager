# [EPIC-LogicConvergence | SPRINT-001 | BUG-001] Explicit Status Sync (Close/Reopen)

**Repository:** GitIssue-Manager  
**Parent:** [EPIC-LogicConvergence | SPRINT-001](../plans/SPRINT_001_CORE_UNIFICATION.md)  
**Type:** BUG  
**Key:** 01JPUXWM8NIDWZ4FF1ZWMMVG6R  
**Status:** TODO  
**Priority:** URGENT  
**Estimate:** 4h

---

## Technical Summary

Fixes the issue where marking a task as `[x]` in a local Markdown file does not automatically close the corresponding GitHub issue. The current logic detects the state transition but fails to invoke the `gh issue close` command reliably, or skips it if the local cache thinks it's already updated.

This bug fix will ensure that the sync loop explicitly verifies the remote status against the local Markdown state and issues a `close` or `reopen` command when they diverge.

## Acceptance Criteria

- [ ] MARKING `[x]` in `PLAN.md` + sync = Issue "Closed" on GitHub.
- [ ] REVERTING `[ ]` in `PLAN.md` + sync = Issue "Reopened" on GitHub.
- [ ] Log output clearly states "Closing issue #NNN..." or "Reopening issue #NNN...".

## Implementation Notes

- Modify the `syncTaskState` routine in [server/executor.js](server/executor.js).
- Ensure `gh issue edit` is followed by `gh issue close --reason "completed"` when applicable.
- Handle `gh issue reopen` if the local checkbox is unchecked.
