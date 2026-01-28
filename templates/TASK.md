# [<PLAN_SLUG> | SPRINT-XXX | TASK-NNN] <Task Title>

**Repository:** <REPO>(<OWNER>/<REPO>)  
**Parent:** [<PLAN_SLUG> | SPRINT-XXX](#) <!-- Link to parent SPRINT issue -->  
**End Date Goal:** <date>  
**Priority:** <PRIORITY> [ LOW | MEDIUM | HIGH | URGENT ]  
**Estimative Hours:** <ESTIMATE>  
**Status:** <STATUS> [ Backlog | TODO | In Progress | In Review | Done ]

---

## Technical Summary

Brief technical description of the task scope, implementation approach, and expected outcome. Keep it concise (2-4 paragraphs max).

### Acceptance Criteria

- [ ] Criterion 1: <measurable outcome>
- [ ] Criterion 2: <measurable outcome>
- [ ] Criterion 3: <measurable outcome>

---

## Implementation Notes

Technical details, code references, or architecture notes relevant to this task.

### Files to Modify

- `path/to/file1.ts` — <description>
- `path/to/file2.ts` — <description>

### Dependencies

- Depends on: #<!-- issue number --> [<PLAN_SLUG> | SPRINT-XXX | TASK-YYY] <dependency title>
- Blocks: #<!-- issue number --> [<PLAN_SLUG> | SPRINT-XXX | FEATURE-ZZZ] <blocked item>

---

## Checklist

- [ ] Implementation complete
- [ ] Tests added/updated
- [ ] Documentation updated
- [ ] Code reviewed
- [ ] Merged to target branch

---

## Template Instructions

### Naming Convention

This is a **Level 3** work unit under a SPRINT. Title format:
```
[<PLAN_SLUG> | SPRINT-XXX | TASK-NNN] Task Title
```

**Examples:**
- `[PLAN-HarmonyVoting | SPRINT-001 | TASK-001] Configure Prometheus metrics`
- `[EPIC-Indexing | SPRINT-002 | TASK-003] Implement batch processing`

### Parent Linking

Use both methods to link to parent SPRINT:
1. **GitHub task list:** This task appears as `- [ ] #123` in the parent SPRINT issue
2. **Metadata tag:** `[parent:<PLAN_SLUG>-SPRINT-XXX]` in this issue body

### Key Tags (Dedupe)

If this task appears in a checklist, include `[key:<ULID>]` for canonical identity.

---

**Version:** 2.0  
**Last Updated:** 2026-01-28  
**Status:** Ready to use
