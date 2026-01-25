#  #EPIC-001 - <Epic Title>

**Repository:** <REPO>(<OWNER>/<REPO>)  
**End Date Goal:** <date>  
**Priority:** <PRIORITY> [ LOW | HIGH | URGENT | MEDIUM ]  
**Estimative Hours:** <ESTIMATE>  
**Status:** <STATUS> [ in progress | Ready | Done | in Review | Backlog ]

---

## Executive Summary

Brief description of the epic scope, impact, and expected outcome.

---

## Subtasks (Linked)

Use headings that include an ID (e.g., EPIC-001). Checklist items under these headings become subtasks.

### EPIC-001: <Epic Milestone>

- [ ] <Subtask title> [key:<canonical-key>] [labels:type:feature, area:<area>] [status:TODO] [priority:HIGH] [estimate:6h] [start:YYYY-MM-DD] [end:YYYY-MM-DD]
- [ ] <Subtask title> [key:<canonical-key>] [labels:type:task, area:<area>] [status:TODO] [priority:MEDIUM] [estimate:4h] [start:YYYY-MM-DD] [end:YYYY-MM-DD]

---

## Milestones

- **Milestone 1:** <Milestone name> — <status> — <start> → <end>
- **Milestone 2:** <Milestone name> — <status> — <start> → <end>

---

## Template Instructions

1. Use the `#EPIC-001` format in the title.
2. Keep the technical info block at the top.
3. Put checklists only inside “Subtasks (Linked)”.
4. Add `[key:<canonical-key>]` to every checklist item to keep identity stable across moves/edits.
5. GitHub issue titles are generated as breadcrumbs (no `-NNN` numbering in GitHub titles), e.g. `[PLAN / EPIC] - Title`.
6. **Mark progress** as features complete.
7. **Sync to GitHub** via GitIssue-Manager (optional).

### Epic Structure

```markdown
- [ ] EPIC-NNN: Title [metadata-tags]
  **Vision:** What's the end goal?
  
  **Acceptance Criteria:**
  - ✅ Criterion 1
  - ✅ Criterion 2
  
  **Timeline:**
  - Phase 1 (dates): Description
  - Phase 2 (dates): Description
  
  **Risks:**
  - ⚠️ Risk 1 → Mitigation: ...
  - ⚠️ Risk 2 → Mitigation: ...
  
  - [ ] FEATURE-001: Sub-feature [metadata-tags]
  - [ ] FEATURE-002: Sub-feature [metadata-tags]
  - [ ] TASK-001: Supporting task [metadata-tags]
```

### Epic vs. Feature vs. Task

| Type | Scope | Timeline | Effort |
|------|-------|----------|--------|
| **EPIC** | Cross-functional, large vision | 4-12 weeks | 40-200h |
| **FEATURE** | Single feature, one team | 1-4 weeks | 8-40h |
| **TASK** | Maintenance, refactoring | 1-2 weeks | 4-16h |

### Epic Phases

Typical structure (adapt as needed):

1. **Design/Specification** (1-2 weeks)
2. **Implementation** (2-6 weeks)
3. **Testing & QA** (1-2 weeks)
4. **Documentation & Release** (1 week)

### Metadata Tag Reference

```markdown
[labels:type:epic, area:backend]     ← Categories
[status:TODO|IN_PROGRESS|DONE]       ← Current state
[priority:CRITICAL|HIGH|MEDIUM|LOW]  ← Business urgency
[estimate:80h]                       ← Total effort estimate
[start:2026-01-21]                   ← Start date (ISO 8601)
[end:2026-02-28]                     ← End date (ISO 8601)
```

### Example: Risk Mitigation Template

```markdown
**Risks:**
- 🚨 Database migration fails on 1M+ records
  → Mitigation: Test on prod clone first, have rollback plan, alert on-call
  → Contingency: Revert migration, keep old schema for 1 sprint
  
- ⚠️ Third-party API dependency unreliable
  → Mitigation: Add fallback endpoint, implement circuit breaker
  → Contingency: Cache 7-day stale data if API down
  
- ℹ️ Feature adoption may be slow
  → Mitigation: User training session, feature flag to A/B test
  → Contingency: Defer advanced features to v2
```

---

## Example: Filled-in Epic

```markdown
- [x] EPIC-001: Production-Ready Indexing System [labels:type:epic, area:backend] [status:DONE] [priority:HIGH] [estimate:80h] [start:2026-01-21] [end:2026-02-28]
  **Vision:** Implement a robust, resilient event indexing system that handles reorgs, ensures data consistency, and provides SLA guarantees.
  
  **Completion Summary:**
  - ✅ Phase 1 (Reorg-safe foundation) completed 2026-02-04
  - ✅ Phase 2 (Metadata resilience) completed 2026-02-11
  - ✅ Phase 3 (Monitoring & alerts) completed 2026-02-18
  - ✅ Phase 4 (Burn-in testing) completed 2026-03-04
  - ✅ Production deployment: 2026-03-07 (successful)
  
  **Metrics:**
  - 100% uptime on prod (37 days)
  - Zero duplicate events detected
  - Avg. indexing lag: 0.8 blocks (target: < 2 blocks)
  - IPFS fallback triggered 47 times (< 1% of metadata requests)
  
  **Lessons Learned:**
  1. Reorg testing was critical; 6 edge cases found in burn-in
  2. IPFS gateway reliability better than expected
  3. Monitoring setup paid off immediately (caught 2 production issues)
```

---

**Version:** 1.0  
**Last Updated:** 2026-01-21  
**Status:** Ready to use  
