# [<PLAN_SLUG> | SPRINT-XXX | FEATURE-NNN] <Feature Title>

**Repository:** <REPO>(<OWNER>/<REPO>)  
**Parent:** [<PLAN_SLUG> | SPRINT-XXX](#) <!-- Link to parent SPRINT issue -->  
**End Date Goal:** <date>  
**Priority:** <PRIORITY> [ LOW | MEDIUM | HIGH | URGENT ]  
**Estimative Hours:** <ESTIMATE>  
**Status:** <STATUS> [ Backlog | TODO | In Progress | In Review | Done ]

---

## Technical Summary

Brief technical description of the feature scope, implementation approach, and expected outcome. Keep it concise (2-4 paragraphs max).

### Feature Description

- **What:** <feature description>
- **Why:** <business value>
- **Who:** <target users/systems>

### Acceptance Criteria

- [ ] Criterion 1: <measurable outcome>
- [ ] Criterion 2: <measurable outcome>
- [ ] Criterion 3: <measurable outcome>

---

## Implementation Notes

Technical details, code references, or architecture notes relevant to this feature.

### Files to Create/Modify

- `path/to/file1.ts` — <description>
- `path/to/file2.ts` — <description>

### API Changes

- **New endpoints:** <list if any>
- **Modified endpoints:** <list if any>
- **Breaking changes:** <yes/no + details>

### Dependencies

- Depends on: #<!-- issue number --> [<PLAN_SLUG> | SPRINT-XXX | TASK-YYY] <dependency title>
- Blocks: #<!-- issue number --> [<PLAN_SLUG> | SPRINT-XXX | FEATURE-ZZZ] <blocked item>

---

## Checklist

- [ ] Design approved
- [ ] Implementation complete
- [ ] Tests added (unit + integration)
- [ ] Documentation updated
- [ ] Code reviewed
- [ ] Merged to target branch

---

## Template Instructions

### Naming Convention

This is a **Level 3** work unit under a SPRINT. Title format:
```
[<PLAN_SLUG> | SPRINT-XXX | FEATURE-NNN] Feature Title
```

**Examples:**
- `[PLAN-HarmonyVoting | SPRINT-001 | FEATURE-001] Add Band Oracle integration`
- `[EPIC-Indexing | SPRINT-002 | FEATURE-003] Implement IPFS fallback`

### Parent Linking

Use both methods to link to parent SPRINT:
1. **GitHub task list:** This feature appears as `- [ ] #123` in the parent SPRINT issue
2. **Metadata tag:** `[parent:<PLAN_SLUG>-SPRINT-XXX]` in this issue body

---

**Version:** 2.0  
**Last Updated:** 2026-01-28  
**Status:** Ready to use
