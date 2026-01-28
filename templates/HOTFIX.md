# [<PLAN_SLUG> | SPRINT-XXX | HOTFIX-NNN] <Hotfix Title>

**Repository:** <REPO>(<OWNER>/<REPO>)  
**Parent:** [<PLAN_SLUG> | SPRINT-XXX](#) <!-- Link to parent SPRINT issue (if applicable) -->  
**End Date Goal:** <date>  
**Priority:** URGENT  
**Estimative Hours:** <ESTIMATE>  
**Status:** <STATUS> [ TODO | In Progress | In Review | Done ]

---

## Technical Summary

Brief technical description of the hotfix scope, root cause, and fix approach. HOTFIXes are urgent fixes that bypass normal sprint planning.

### Issue Description

- **Incident:** <incident description>
- **Impact:** <severity and scope>
- **SLA Target:** <response time requirement>

### Root Cause

Brief analysis of what caused the issue.

---

## Fix Details

### Files to Modify

- `path/to/file1.ts` — <description>
- `path/to/file2.ts` — <description>

### Fix Approach

1. Step 1: <action>
2. Step 2: <action>
3. Step 3: <action>

### Rollback Plan

If the fix fails:
1. Revert commit: `git revert <sha>`
2. Deploy previous version
3. Notify stakeholders

---

## Checklist

- [ ] Root cause identified
- [ ] Fix implemented
- [ ] Emergency tests passed
- [ ] Deployed to production
- [ ] Incident documented
- [ ] Post-mortem scheduled

---

## Template Instructions

### Naming Convention

HOTFIXes can be **standalone** (Level 1) or under a SPRINT (Level 3):

**Standalone:**
```
[HOTFIX] Critical login failure
```

**Under SPRINT:**
```
[<PLAN_SLUG> | SPRINT-XXX | HOTFIX-NNN] Hotfix Title
```

**Examples:**
- `[HOTFIX] Fix production database connection timeout`
- `[PLAN-HarmonyVoting | SPRINT-001 | HOTFIX-001] Emergency patch for vote calculation`

### Priority

HOTFIXes are always **URGENT** priority. If it's not urgent, use BUG instead.

### Parent Linking (if under SPRINT)

Use both methods to link to parent SPRINT:
1. **GitHub task list:** This hotfix appears as `- [ ] #123` in the parent SPRINT issue
2. **Metadata tag:** `[parent:<PLAN_SLUG>-SPRINT-XXX]` in this issue body

---

**Version:** 2.0  
**Last Updated:** 2026-01-28  
**Status:** Ready to use
