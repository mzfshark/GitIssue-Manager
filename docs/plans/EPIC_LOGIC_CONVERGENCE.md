# [EPIC] GitIssuer Logic Convergence (Impeccable Workflow)

**Repository:** GitIssue-Manager (mzfshark/GitIssue-Manager)  
**Slug:** `EPIC-LogicConvergence`  
**End Date Goal:** 2026-03-10  
**Priority:** URGENT  
**Estimative Hours:** 32h  
**Status:** TODO

---

## Executive Summary

This epic focuses on aligning the `gitissuer` core logic with the "Impeccable Workflow" demonstrated by AI agents. The goal is to ensure that Markdown plans are the absolute source of truth for both task existence, hierarchy, and status (open/closed). 

Currently, `gitissuer` suffers from inconsistent deduping and incomplete status synchronization. This plan will refactor the internal executor and parser to prioritize ULID keys, enforce canonical title formats, and synchronize issue bodies and states (closed/reopened) automatically.

### Success Criteria

- [ ] Successful deduplication using `[key:<ULID>]` found anywhere in the issue body.
- [ ] Automatic closing of GitHub issues when the Markdown checkbox is marked `[x]`.
- [ ] Automatic reopening of GitHub issues when a `DONE` task is reverted to `[ ]` in Markdown.
- [ ] Issue titles are automatically formatted as `[PLAN-Slug | SPRINT-XXX | TYPE-NNN] Title`.
- [ ] Issue bodies are synchronized from Markdown sections (Source of Truth).

---

## Hierarchy Overview

```
[EPIC] Logic Convergence (this document - PAI)
├── [EPIC-LogicConvergence | SPRINT-001] Core Unification
│   ├── [EPIC-LogicConvergence | SPRINT-001 | FEATURE-001] ULID-based Deduplication Engine
│   ├── [EPIC-LogicConvergence | SPRINT-001 | BUG-001] Explicit Status Sync (Close/Reopen)
│   ├── [EPIC-LogicConvergence | SPRINT-001 | TASK-001] Canonical Title Generator
│   └── [EPIC-LogicConvergence | SPRINT-001 | TASK-002] Body Content Sync Logic
└── [EPIC-LogicConvergence | SPRINT-002] Hierarchy & Metadata
    ├── [EPIC-LogicConvergence | SPRINT-002 | FEATURE-001] Recursive Hierarchy Parser
    └── [EPIC-LogicConvergence | SPRINT-002 | TASK-001] ProjectV2 Metadata Alignment
```

---

## Sprints (Linked)

### [EPIC-LogicConvergence | SPRINT-001] Core Unification

- [ ] #<!-- issue --> [EPIC-LogicConvergence | SPRINT-001 | FEATURE-001] ULID-based Deduplication Engine [key:01JPUIE642GMDT90NT83ZMR46L] [labels:type:feature, area:core] [status:TODO] [priority:URGENT] [estimate:8h]
- [ ] #<!-- issue --> [EPIC-LogicConvergence | SPRINT-001 | BUG-001] Explicit Status Sync (Close/Reopen) [key:01JPUXWM8NIDWZ4FF1ZWMMVG6R] [labels:type:bug, area:core] [status:TODO] [priority:URGENT] [estimate:4h]
- [ ] #<!-- issue --> [EPIC-LogicConvergence | SPRINT-001 | TASK-001] Canonical Title Generator [key:01JPHC8GW7P1UI3MCRASVB2EAX] [labels:type:task, area:core] [status:TODO] [priority:HIGH] [estimate:4h]
- [ ] #<!-- issue --> [EPIC-LogicConvergence | SPRINT-001 | TASK-002] Body Content Sync Logic [key:01JPXJ5CIL2N9RS20RTJUZ1E58] [labels:type:task, area:core] [status:TODO] [priority:HIGH] [estimate:4h]

### [EPIC-LogicConvergence | SPRINT-002] Hierarchy & Metadata

- [ ] #<!-- issue --> [EPIC-LogicConvergence | SPRINT-002 | FEATURE-001] Recursive Hierarchy Parser [key:01JP9KW8CHZ5LDVEER8GU3M39A] [labels:type:feature, area:parser] [status:TODO] [priority:MEDIUM] [estimate:6h]
- [ ] #<!-- issue --> [EPIC-LogicConvergence | SPRINT-002 | TASK-001] ProjectV2 Metadata Alignment [key:01JPOVXA9088UEYVGRFX5GXW0J] [labels:type:task, area:project] [status:TODO] [priority:MEDIUM] [estimate:2h]

---

## Risks & Mitigations

- 🚨 **Critical Risk:** Search API secondary rate limits when deduping by ULID keys.
  → Mitigation: Use local registry index as primary source; optimize search queries to be exact matches.
  
- ⚠️ **Medium Risk:** Overwriting manual community comments in issue bodies.
  → Mitigation: Use "Managed Sections" (HTML comments) to wrap gitissuer-controlled content.

---

## Implementation Notes

1. **Dedupe Strategy**: `executor.js` must search for the ULID string `[key:...]` in the body of all issues (cached/indexed) before deciding to create a new one.
2. **Title Pattern**: Centralize title generation in a utility that consumes the Plan/Epic slug and level.
3. **State Transitions**: `desiredIssueStateFromItem` must be the final arbiter. `gh issue close` must be called if Markdown is `[x]`.

---

**Version:** 1.0  
**Last Updated:** 2026-02-10
