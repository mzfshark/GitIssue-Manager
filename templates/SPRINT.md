# [<PLAN_SLUG> | SPRINT-XXX] <Sprint Title>

**Repository:** <REPO>(<OWNER>/<REPO>)  
**Parent:** [<PLAN_SLUG>](#) <!-- Link to parent PLAN or EPIC issue -->  
**Sprint Duration:** <weeks> weeks (<start> → <end>)  
**Priority:** <PRIORITY> [ LOW | MEDIUM | HIGH | URGENT ]  
**Estimative Hours:** <ESTIMATE>  
**Status:** <STATUS> [ Backlog | TODO | In Progress | In Review | Done ]

---

## Executive Summary

Brief description of the sprint scope, goals, and expected deliverables. This sprint is an execution unit of the parent PLAN/EPIC.

---

## Sprint Goals

- [ ] Goal 1: <description>
- [ ] Goal 2: <description>
- [ ] Goal 3: <description>

---

## Tasks (Linked)

Tasks are work units under this sprint. Each task MUST follow the naming convention:
`[<PLAN_SLUG> | SPRINT-XXX | <TYPE>-NNN] Task Title`

Where `<TYPE>` is one of: `TASK`, `BUG`, `FEATURE`, `HOTFIX`

### Week 1 (<start> → <mid>)

- [ ] #<!-- issue number --> [<PLAN_SLUG> | SPRINT-XXX | TASK-001] <Task title> [key:<ULID>] [labels:type:task, area:<area>] [status:TODO] [priority:MEDIUM] [estimate:4h]
- [ ] #<!-- issue number --> [<PLAN_SLUG> | SPRINT-XXX | FEATURE-001] <Feature title> [key:<ULID>] [labels:type:feature, area:<area>] [status:TODO] [priority:HIGH] [estimate:8h]

### Week 2 (<mid> → <end>)

- [ ] #<!-- issue number --> [<PLAN_SLUG> | SPRINT-XXX | BUG-001] <Bug title> [key:<ULID>] [labels:type:bug, area:<area>] [status:TODO] [priority:HIGH] [estimate:4h]
- [ ] #<!-- issue number --> [<PLAN_SLUG> | SPRINT-XXX | TASK-002] <Task title> [key:<ULID>] [labels:type:task, area:<area>] [status:TODO] [priority:MEDIUM] [estimate:6h]

---

## Execution Instructions

Detailed instructions for executing the tasks in this sprint:

1. **Setup:** <environment setup instructions>
2. **Dependencies:** <list dependencies that must be completed first>
3. **Validation:** <how to validate task completion>
4. **Rollback:** <rollback procedure if issues arise>

---

## Acceptance Criteria

- [ ] All tasks marked as DONE
- [ ] All tests passing
- [ ] Documentation updated
- [ ] Code reviewed and merged

---

## Milestones

- **Milestone 1:** <name> — <status> — <start> → <end>
- **Milestone 2:** <name> — <status> — <start> → <end>

---

## Template Instructions

### Naming Convention

| Level | Type | Title Format |
|-------|------|--------------|
| **1 (PAI)** | PLAN, EPIC | `[PLAN] Title` or `[EPIC] Title` (no `-NNN` suffix) |
| **2** | SPRINT | `[<PLAN_SLUG> \| SPRINT-XXX] Title` |
| **3** | TASK, BUG, FEATURE, HOTFIX | `[<PLAN_SLUG> \| SPRINT-XXX \| <TYPE>-NNN] Title` |

### Slug Generation

The `<PLAN_SLUG>` is auto-generated from the parent PLAN/EPIC title:
- Remove special characters
- Convert to PascalCase or kebab-case
- Keep it short and descriptive (max 20 chars)

**Examples:**
- `HarmonyVoting Production Rollout` → `PLAN-HarmonyVoting`
- `Indexing System Resilience` → `EPIC-IndexingResilience`

### Linking

Use both methods to link children to parents:
1. **GitHub task list:** `- [ ] #123` (checkbox with issue reference)
2. **Metadata tag:** `[parent:<PLAN_SLUG>]` in the issue body

---

**Version:** 1.0  
**Last Updated:** 2026-01-28  
**Status:** Ready to use
