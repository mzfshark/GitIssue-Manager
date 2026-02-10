# [EPIC-LogicConvergence | SPRINT-001] Core Unification

**Repository:** GitIssue-Manager (mzfshark/GitIssue-Manager)  
**Parent:** [EPIC-LogicConvergence](../plans/EPIC_LOGIC_CONVERGENCE.md)  
**Sprint Duration:** 2026-02-10 → 2026-02-24  
**Priority:** URGENT  
**Estimative Hours:** 20h  
**Status:** TODO

---

## Executive Summary

This sprint implements the core "Impeccable Workflow" logic within the `gitissuer` engine. It refactors the matching and synchronization routines to ensure that Markdown is the absolute source of truth.

### Sprint Goals

- [ ] Implement ULID-based matching that searches issue bodies.
- [ ] Enforce state synchronization (Close/Reopen) based on Markdown checkbox state.
- [ ] Centralize title formatting to follow the canonical prefix pattern.
- [ ] Implement Managed Sections for issue body synchronization.

---

## Tasks (Linked)

- [ ] #<!-- issue --> [EPIC-LogicConvergence | SPRINT-001 | FEATURE-001] ULID-based Deduplication Engine [key:01JPUIE642GMDT90NT83ZMR46L] [labels:type:feature, area:core] [status:TODO] [priority:URGENT] [estimate:8h]
- [ ] #<!-- issue --> [EPIC-LogicConvergence | SPRINT-001 | BUG-001] Explicit Status Sync (Close/Reopen) [key:01JPUXWM8NIDWZ4FF1ZWMMVG6R] [labels:type:bug, area:core] [status:TODO] [priority:URGENT] [estimate:4h]
- [ ] #<!-- issue --> [EPIC-LogicConvergence | SPRINT-001 | TASK-001] Canonical Title Generator [key:01JPHC8GW7P1UI3MCRASVB2EAX] [labels:type:task, area:core] [status:TODO] [priority:HIGH] [estimate:4h]
- [ ] #<!-- issue --> [EPIC-LogicConvergence | SPRINT-001 | TASK-002] Body Content Sync Logic [key:01JPXJ5CIL2N9RS20RTJUZ1E58] [labels:type:task, area:core] [status:TODO] [priority:HIGH] [estimate:4h]

---

## Acceptance Criteria

- [ ] A task marked as `[x]` in a local Markdown file results in the corresponding GitHub issue being CLOSED upon execution of `gitissuer sync --confirm`.
- [ ] Renaming a task in Markdown updates the GitHub issue title while maintaining the canonical prefix.
- [ ] Tasks are matched correctly even if their titles change, as long as the ULID key remains constant in the body.
- [ ] Reverting a `[x]` to `[ ]` in Markdown triggers a `reopen` action on GitHub.
