# [<PLAN_SLUG> | SPRINT-XXX | BUG-NNN] <Bug Title>

**Repository:** <REPO>(<OWNER>/<REPO>)  
**Parent:** [<PLAN_SLUG> | SPRINT-XXX](#) <!-- Link to parent SPRINT issue -->  
**End Date Goal:** <date>  
**Priority:** <PRIORITY> [ LOW | MEDIUM | HIGH | URGENT ]  
**Estimative Hours:** <ESTIMATE>  
**Status:** <STATUS> [ Backlog | TODO | In Progress | In Review | Done ]

---

## Technical Summary

Brief technical description of the bug, root cause analysis, and proposed fix. Keep it concise (2-4 paragraphs max).

### Bug Description

- **Observed behavior:** <what happens>
- **Expected behavior:** <what should happen>
- **Reproduction steps:** <how to reproduce>

### Impact

- **Severity:** [ Critical | High | Medium | Low ]
- **Affected users/systems:** <scope of impact>

---

## Root Cause Analysis

Technical analysis of why the bug occurs.

### Files to Modify

- `path/to/file1.ts` — <description>
- `path/to/file2.ts` — <description>

### Fix Approach

1. Step 1: <action>
2. Step 2: <action>
3. Step 3: <action>

---

## Checklist

- [ ] Root cause identified
- [ ] Fix implemented
- [ ] Regression tests added
- [ ] Verified in staging
- [ ] Code reviewed
- [ ] Merged to target branch

---

## Template Instructions

### Naming Convention

This is a **Level 3** work unit under a SPRINT. Title format:
```
[<PLAN_SLUG> | SPRINT-XXX | BUG-NNN] Bug Title
```

**Examples:**
- `[PLAN-HarmonyVoting | SPRINT-001 | BUG-001] Fix reorg detection edge case`
- `[EPIC-Indexing | SPRINT-002 | BUG-003] Memory leak in queue processor`

### Parent Linking

Use both methods to link to parent SPRINT:
1. **GitHub task list:** This bug appears as `- [ ] #123` in the parent SPRINT issue
2. **Metadata tag:** `[parent:<PLAN_SLUG>-SPRINT-XXX]` in this issue body

---

**Version:** 2.0  
**Last Updated:** 2026-01-28  
**Status:** Ready to use
