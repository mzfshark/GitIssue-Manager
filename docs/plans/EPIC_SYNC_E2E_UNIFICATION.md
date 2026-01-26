# EPIC-001 - Unify sync and e2e flows into single linear workflow

**Repository:** GitIssue-Manager(mzfshark/GitIssue-Manager)  
**GitHub Issue:** [#117](https://github.com/mzfshark/GitIssue-Manager/issues/117)  
**End Date Goal:** 2026-02-02  
**Priority:** HIGH  
**Estimative Hours:** 24  
**Status:** In Progress

---

## Executive Summary

Merge the working parts of `e2e-flow-v2.sh` into the `sync` command, eliminating flow fragmentation and reducing user interaction to a single command. The unified flow will be idempotent, support `--dry-run/--confirm` gates, and handle parent↔sub-issue linking natively.

---

## Problem Statement

Currently, users must run **two separate flows** to achieve full issue hierarchy:

1. `gitissuer sync` — creates issues but delegates hierarchy linking to e2e
2. `gitissuer e2e:run` or `gitissuer link:hierarchy` — links sub-issues via GraphQL

This causes:
- **Duplicates**: e2e rewrites PAI body with markers, sometimes creating new issues instead of reusing
- **Confusion**: separate state files (`execution-state.json` vs `engine-output.json`)
- **Extra steps**: user must run multiple commands and pass artifact paths manually

---

## Solution

Make `sync` the **single E2E flow**:

```
gitissuer sync --repo X --confirm
  │
  ├─ 1. prepare        → engine-input.json + metadata.json
  ├─ 2. deploy         → create/update issues (parent + children)
  ├─ 3. link-hierarchy → GraphQL addSubIssue (NEW: native, no e2e call)
  └─ 4. registry:update
```

---

## Subtasks (Linked)

### EPIC-001 | TASK-001: Create server/link-hierarchy.js [key:01JJK8TQSPJTN6GNH4YKG3DMJP]

- [ ] Extract STAGE 5 logic from e2e-flow-v2.sh into Node script [labels:type:task, area:server] [status:TODO] [priority:HIGH] [estimate:6h]
- [ ] Read engine-output.json to get stableId → issueNumber mapping [labels:type:task, area:server] [status:TODO] [priority:HIGH] [estimate:2h]
- [ ] Resolve issueNumber → nodeId via GraphQL [labels:type:task, area:server] [status:TODO] [priority:MEDIUM] [estimate:2h]
- [ ] Call addSubIssue mutation for each parent↔child relation [labels:type:task, area:server] [status:TODO] [priority:HIGH] [estimate:2h]
- [ ] Support --dry-run (log intended links without executing) [labels:type:task, area:server] [status:TODO] [priority:HIGH] [estimate:1h]
- [ ] Support --replace-parent flag [labels:type:task, area:server] [status:TODO] [priority:MEDIUM] [estimate:1h]

### EPIC-001 | TASK-002: Update gitissuer.sh wrapper [key:01JJK8TQSQ29H26YN4D4T1T1X7]

- [ ] Rewrite cmd_link_hierarchy to call server/link-hierarchy.js instead of e2e-flow-v2.sh [labels:type:task, area:scripts] [status:TODO] [priority:HIGH] [estimate:2h]
- [ ] Remove e2e stage dependency from cmd_sync flow [labels:type:task, area:scripts] [status:TODO] [priority:HIGH] [estimate:1h]
- [ ] Update usage() to document new unified flow [labels:type:task, area:docs] [status:TODO] [priority:LOW] [estimate:0.5h]

### EPIC-001 | TASK-003: Update executor.js for parent identity markers [key:01JJK8TQSQ29H26YN4D4T1T1X8]

- [ ] Add HTML comment markers to parent issue body (Key, StableId, ContentHash) [labels:type:task, area:server] [status:TODO] [priority:HIGH] [estimate:2h]
- [ ] Ensure dedupe uses markers for matching existing parent issues [labels:type:task, area:server] [status:TODO] [priority:HIGH] [estimate:1h]

### EPIC-001 | TASK-004: Config and defaults [key:01JJK8TQSQ29H26YN4D4T1T1X9]

- [ ] Add gitissuer.hierarchy.parentIssueNumber to mzfshark-GitIssue-Manager.json [labels:type:task, area:config] [status:TODO] [priority:MEDIUM] [estimate:0.5h]
- [ ] Document config schema in README or docs [labels:type:task, area:docs] [status:TODO] [priority:LOW] [estimate:1h]

### EPIC-001 | TASK-005: Deprecate e2e-flow-v2.sh [key:01JJK8TQSQ29H26YN4D4T2T2Y0]

- [ ] Add deprecation warning at top of e2e-flow-v2.sh [labels:type:task, area:scripts] [status:TODO] [priority:LOW] [estimate:0.5h]
- [ ] Update cmd_e2e to print migration notice [labels:type:task, area:scripts] [status:TODO] [priority:LOW] [estimate:0.5h]
- [ ] Remove e2e references from main README [labels:type:task, area:docs] [status:TODO] [priority:LOW] [estimate:0.5h]

---

## Milestones

- **M1: link-hierarchy.js ready** — 2026-01-28 (TASK-001 complete)
- **M2: sync flow unified** — 2026-01-30 (TASK-002 + TASK-003 complete)
- **M3: config + docs** — 2026-02-01 (TASK-004 complete)
- **M4: e2e deprecated** — 2026-02-02 (TASK-005 complete)

---

## Acceptance Criteria

1. `gitissuer sync --repo X --confirm` creates parent issue, child issues, and links hierarchy in one command
2. `--dry-run` shows all intended operations without GitHub writes
3. Existing issues are reused (no duplicates) based on Key/StableId markers
4. `e2e:run` still works but prints deprecation notice
5. Config supports `parentIssueNumber` default to skip `--parent-number` flag

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| GraphQL rate limits during link phase | Batch requests; add retry with backoff |
| Existing e2e users break | Deprecation notice + 2-week grace period |
| Parent issue body conflicts | Use HTML comment markers (invisible to users) |

---

## References

- Current sync flow: [scripts/gitissuer.sh](../scripts/gitissuer.sh)
- Current e2e flow: [scripts/e2e-flow-v2.sh](../scripts/e2e-flow-v2.sh)
- Related issues: #74, #75 (sync), #94 (e2e)
- Executor: [server/executor.js](../server/executor.js)

---

**Version:** 1.0  
**Created:** 2026-01-26  
**Author:** Morpheus (Planning Agent)
