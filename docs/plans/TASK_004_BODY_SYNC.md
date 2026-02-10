# [EPIC-LogicConvergence | SPRINT-001 | TASK-002] Body Content Sync Logic

**Repository:** GitIssue-Manager  
**Parent:** [EPIC-LogicConvergence | SPRINT-001](../plans/SPRINT_001_CORE_UNIFICATION.md)  
**Type:** TASK  
**Key:** 01JPXJ5CIL2N9RS20RTJUZ1E58  
**Status:** TODO  
**Priority:** HIGH  
**Estimate:** 4h

---

## Technical Summary

Implements "Managed Sections" within the GitHub issue body. This allows the tool to update its metadata (Keys, Parent links, technical specs) without overwriting manual comments or edits made by humans in the main body area of the issue.

The logic will use HTML comment markers:
`<!-- gitissuer-managed-start -->`
... managed content ...
`<!-- gitissuer-managed-end -->`

## Acceptance Criteria

- [ ] New issues are created with a clear metadata block at the top or bottom.
- [ ] Updating an issue preserves any text outside the managed section markers.
- [ ] If no markers exist, the tool prepends/appends the managed section.

## Implementation Notes

- Implement regex-based section replacement in the body preparation logic.
- Ensure `parent` links (Level 1/2) are always present in the managed section of Level 3 issues.
- Store the ULID key inside this managed section for the Deduplication Engine (FEATURE-001) to find.
