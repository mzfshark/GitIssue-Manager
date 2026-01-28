# Issue Templates — GitIssue-Manager

This directory contains canonical templates for creating GitHub issues with proper hierarchy and naming conventions.

## Hierarchy Overview

```
Level 1: PAI (Parent Issues)
├── [PLAN] Title     ← Full project/release roadmap
└── [EPIC] Title     ← Cross-functional feature set

Level 2: SPRINT
└── [<PLAN_SLUG> | SPRINT-XXX] Title    ← Execution unit with grouped tasks

Level 3: Work Units
├── [<PLAN_SLUG> | SPRINT-XXX | TASK-NNN] Title
├── [<PLAN_SLUG> | SPRINT-XXX | BUG-NNN] Title
├── [<PLAN_SLUG> | SPRINT-XXX | FEATURE-NNN] Title
└── [<PLAN_SLUG> | SPRINT-XXX | HOTFIX-NNN] Title
```

## Templates

| Template | Level | Description |
|----------|-------|-------------|
| [PLAN.md](PLAN.md) | 1 (PAI) | Project/release roadmap with all milestones |
| [EPIC.md](EPIC.md) | 1 (PAI) | Cross-functional feature set spanning sprints |
| [SPRINT.md](SPRINT.md) | 2 | Execution unit grouping tasks |
| [TASK.md](TASK.md) | 3 | General work item |
| [BUG.md](BUG.md) | 3 | Bug fix |
| [FEATURE.md](FEATURE.md) | 3 | New feature implementation |
| [HOTFIX.md](HOTFIX.md) | 3 | Urgent fix (can be standalone at Level 1) |

## Naming Convention

### Parent Issues (PAI) — Level 1

No numeric suffix. Title format:
```
[PLAN] HarmonyVoting Production Rollout
[EPIC] Indexing System Resilience
```

### SPRINT — Level 2

Uses parent slug + sprint number:
```
[PLAN-HarmonyVoting | SPRINT-001] Infrastructure Setup
[EPIC-Indexing | SPRINT-002] Monitoring Phase
```

### Work Units — Level 3

Uses parent slug + sprint + type + number:
```
[PLAN-HarmonyVoting | SPRINT-001 | TASK-001] Configure Prometheus
[PLAN-HarmonyVoting | SPRINT-001 | BUG-001] Fix reorg detection
[PLAN-HarmonyVoting | SPRINT-001 | FEATURE-001] Add alerting
[PLAN-HarmonyVoting | SPRINT-001 | HOTFIX-001] Patch memory leak
```

## Slug Generation

The `<PLAN_SLUG>` is auto-generated from the parent title:

1. Remove special characters and stop words
2. Convert to PascalCase (max 20 chars)
3. Prefix with document type

**Examples:**
- `HarmonyVoting Production Rollout` → `PLAN-HarmonyVoting`
- `Production-Ready Indexing System` → `EPIC-IndexingSystem`
- `Q1 2026 Infrastructure Upgrade` → `PLAN-Q1InfraUpgrade`

## Linking Children to Parents

Use both methods for robust linking:

### 1. GitHub Task List (in parent issue body)

```markdown
## Tasks (Linked)

- [ ] #123 [PLAN-HarmonyVoting | SPRINT-001 | TASK-001] Configure Prometheus
- [ ] #124 [PLAN-HarmonyVoting | SPRINT-001 | FEATURE-001] Add alerting
```

### 2. Metadata Tag (in child issue body)

```markdown
**Parent:** [PLAN-HarmonyVoting | SPRINT-001](#123)
```

Or in checklist items:
```markdown
- [ ] Task title [key:01KFRBTZSPJTN6GNH4YKG3DMJP] [parent:PLAN-HarmonyVoting-SPRINT-001]
```

## Key Tags (Dedupe)

Every checklist item intended for GitHub sync MUST include a canonical key:

```markdown
- [ ] Task title [key:<ULID>] [labels:type:task, area:backend] [status:TODO] [priority:MEDIUM] [estimate:4h]
```

Generate ULIDs via:
```bash
gitissuer rekey --repo <owner>/<repo> --dry-run    # Preview
gitissuer rekey --repo <owner>/<repo> --confirm    # Apply
```

## Content Guidelines

| Level | Body Content |
|-------|--------------|
| **PAI (PLAN/EPIC)** | Full detailed scope, all milestones, all sprints |
| **SPRINT** | Execution instructions, grouped tasks, validation criteria |
| **TASK/BUG/FEATURE/HOTFIX** | Brief technical summary, acceptance criteria |

---

**Version:** 2.0  
**Last Updated:** 2026-01-28  
**Status:** Ready to use
