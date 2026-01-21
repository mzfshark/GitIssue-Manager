# Epic: Large Initiatives & Cross-Team Efforts

Template for EPIC.md files across repositories.

**Purpose:** Track large, multi-phase initiatives that span multiple features, teams, or repositories.

**Rules:**
- Every checkbox line MUST include metadata tags: [labels:...] [status:...] [priority:...] [estimate:..h] [start:YYYY-MM-DD] [end:YYYY-MM-DD]
- Subtasks are indented by 2 spaces under their parent
- Prefer clear epic titles with business value
- Use EPIC-NNN ID format (unique within repository)
- Always include: Vision, Acceptance Criteria, Timeline, Risks

---

## Platform Epics

- [ ] EPIC-001: Production-Ready Indexing System [labels:type:epic, area:backend, area:indexing] [status:TODO] [priority:HIGH] [estimate:80h] [start:2026-01-21] [end:2026-02-28]
  **Vision:** Implement a robust, resilient event indexing system that handles reorgs, ensures data consistency, and provides SLA guarantees.
  
  **Acceptance Criteria:**
  - ✅ Zero duplicate events in database (idempotency enforced)
  - ✅ Reorg recovery < 60 seconds
  - ✅ 99.9% uptime on indexing (monitoring in place)
  - ✅ Fallback metadata sourcing (on-chain → cache → placeholder)
  - ✅ < 2 block indexing lag during normal network conditions
  - ✅ Full test coverage (95%+) for reorg scenarios
  
  **Timeline:**
  - Phase 1 (Week 1-2): Reorg-safe foundation + idempotency (FEATURE-001)
  - Phase 2 (Week 2-3): Metadata resilience (FEATURE-002)
  - Phase 3 (Week 3-4): Monitoring & alerts
  - Phase 4 (Week 4-6): Burn-in & optimization
  
  **Risks:**
  - ⚠️ Reorg detection may miss edge cases → Mitigation: Extensive test suite
  - ⚠️ IPFS gateway failures → Mitigation: Multi-gateway fallback
  - ⚠️ Performance regression on large blocks → Mitigation: Batch optimization (Q2)

  - [ ] FEATURE-001: Reorg-safe indexing [labels:type:feature] [status:TODO] [priority:HIGH] [estimate:20h] [start:2026-01-21] [end:2026-02-04]
  - [ ] FEATURE-002: Metadata fallback system [labels:type:feature] [status:TODO] [priority:MEDIUM] [estimate:16h] [start:2026-02-04] [end:2026-02-11]
  - [ ] Implement monitoring & alerting [labels:type:task] [status:TODO] [priority:MEDIUM] [estimate:12h] [start:2026-02-11] [end:2026-02-18]
  - [ ] Burn-in testing (2 weeks) [labels:type:qa] [status:TODO] [priority:HIGH] [estimate:0h] [start:2026-02-18] [end:2026-03-04]
  - [ ] Production deployment [labels:type:task] [status:TODO] [priority:HIGH] [estimate:4h] [start:2026-03-04] [end:2026-03-07]

- [ ] EPIC-002: Native-Token Voting & Execution [labels:type:epic, area:contracts, area:backend, area:frontend] [status:TODO] [priority:HIGH] [estimate:100h] [start:2026-02-04] [end:2026-03-21]
  **Vision:** Enable voting and proposal execution using native tokens (not ERC-20), supporting chains like Harmony where gas is paid in native token.
  
  **Acceptance Criteria:**
  - ✅ Native-token voting on testnet
  - ✅ Native-token execution on testnet
  - ✅ Frontend displays native-token semantics (fee vs. value)
  - ✅ E2E flow tested (vote → execute → verify)
  - ✅ > 90% test coverage
  - ✅ Gas cost analysis documented
  
  **Timeline:**
  - Phase 1 (Week 1): Design & specification
  - Phase 2 (Week 2-3): Contract implementation (FEATURE-003)
  - Phase 3 (Week 3-4): Backend integration (RPC provider)
  - Phase 4 (Week 5): Frontend UX (FEATURE-005)
  - Phase 5 (Week 6-7): E2E testing & deployment
  
  **Risks:**
  - ⚠️ Gas cost estimation may differ from actual → Mitigation: Simulation endpoints
  - ⚠️ Chain-specific quirks (Harmony) → Mitigation: Fork testing with real RPC
  - ⚠️ User confusion (fee vs. value) → Mitigation: Clear UI labels

  - [ ] Design native-token schema [labels:type:design] [status:TODO] [priority:HIGH] [estimate:4h] [start:2026-02-04] [end:2026-02-05]
  - [ ] FEATURE-003: Contract implementation [labels:type:feature] [status:TODO] [priority:HIGH] [estimate:24h] [start:2026-02-05] [end:2026-02-18]
  - [ ] Implement RPC power provider [labels:type:feature, area:backend] [status:TODO] [priority:HIGH] [estimate:12h] [start:2026-02-18] [end:2026-02-25]
  - [ ] FEATURE-005: Frontend UX [labels:type:feature, area:frontend] [status:TODO] [priority:MEDIUM] [estimate:16h] [start:2026-02-25] [end:2026-03-04]
  - [ ] E2E testing (testnet) [labels:type:qa] [status:TODO] [priority:HIGH] [estimate:12h] [start:2026-03-04] [end:2026-03-11]
  - [ ] Mainnet deployment readiness [labels:type:task] [status:TODO] [priority:HIGH] [estimate:8h] [start:2026-03-11] [end:2026-03-21]

- [ ] EPIC-003: Plugin Uninstall & Lifecycle Management [labels:type:epic, area:contracts, area:frontend] [status:TODO] [priority:MEDIUM] [estimate:60h] [start:2026-01-21] [end:2026-02-28]
  **Vision:** Provide safe, reversible plugin installation and uninstallation flows with clear user warnings and complete permission cleanup.
  
  **Acceptance Criteria:**
  - ✅ Plugin uninstall revokes all permissions (zero orphans)
  - ✅ Uninstall dialog shown in all valid DAO states
  - ✅ User warnings clear and accurate
  - ✅ Undo/recovery path documented (manual for MVP)
  - ✅ E2E uninstall tested on testnet
  - ✅ Zero regression in existing install flows
  
  **Timeline:**
  - Phase 1 (Week 1): Permission audit & design
  - Phase 2 (Week 2): Contract implementation (FEATURE-002)
  - Phase 3 (Week 3): Frontend UX (FEATURE-004)
  - Phase 4 (Week 4-5): Testing & fixes
  - Phase 5 (Week 6): Deployment
  
  **Risks:**
  - ⚠️ Orphan permissions difficult to find → Mitigation: Multi-batch revoke + test coverage
  - ⚠️ UI state machine complex → Mitigation: Component library + state tests
  - ⚠️ User confusion on uninstall effect → Mitigation: Clear warnings + docs

  - [ ] Audit all permission types [labels:type:investigation] [status:TODO] [priority:HIGH] [estimate:4h] [start:2026-01-21] [end:2026-01-22]
  - [ ] Design multi-batch revoke logic [labels:type:design] [status:TODO] [priority:HIGH] [estimate:4h] [start:2026-01-22] [end:2026-01-23]
  - [ ] FEATURE-002: Contract uninstall logic [labels:type:feature] [status:TODO] [priority:HIGH] [estimate:16h] [start:2026-01-23] [end:2026-02-04]
  - [ ] FEATURE-004: Frontend uninstall UX [labels:type:feature, area:frontend] [status:TODO] [priority:MEDIUM] [estimate:12h] [start:2026-02-04] [end:2026-02-11]
  - [ ] BUG-004: Fix orphan permission edge case [labels:type:bug] [status:TODO] [priority:HIGH] [estimate:10h] [start:2026-02-11] [end:2026-02-18]
  - [ ] E2E uninstall testing [labels:type:qa] [status:TODO] [priority:HIGH] [estimate:8h] [start:2026-02-18] [end:2026-02-25]
  - [ ] Deployment & monitoring [labels:type:task] [status:TODO] [priority:HIGH] [estimate:6h] [start:2026-02-25] [end:2026-02-28]

---

## Infrastructure Epics

- [ ] EPIC-004: Observability & Monitoring [labels:type:epic, area:ops, area:infra] [status:TODO] [priority:MEDIUM] [estimate:48h] [start:2026-02-28] [end:2026-04-11]
  **Vision:** Implement comprehensive monitoring, alerting, and observability for all services (indexer, API, frontend).
  
  **Acceptance Criteria:**
  - ✅ Structured logging for all services
  - ✅ Prometheus metrics exposed
  - ✅ Grafana dashboards for key metrics
  - ✅ Alerting rules configured (indexing lag, API errors, etc.)
  - ✅ SLA tracking (99.9% uptime target)
  - ✅ On-call runbook documented
  
  **Timeline:**
  - Phase 1 (Week 1): Logging infrastructure (Winston + aggregation)
  - Phase 2 (Week 2): Metrics & Prometheus
  - Phase 3 (Week 3-4): Dashboards & alerts
  - Phase 4 (Week 5-6): SLA tracking & runbooks

  - [ ] Set up centralized logging [labels:type:task, area:infra] [status:TODO] [priority:MEDIUM] [estimate:12h] [start:2026-02-28] [end:TBD]
  - [ ] Add Prometheus metrics [labels:type:task, area:infra] [status:TODO] [priority:MEDIUM] [estimate:12h] [start:TBD] [end:TBD]
  - [ ] Create Grafana dashboards [labels:type:task, area:infra] [status:TODO] [priority:MEDIUM] [estimate:12h] [start:TBD] [end:TBD]
  - [ ] Configure alerting rules [labels:type:task, area:infra] [status:TODO] [priority:MEDIUM] [estimate:6h] [start:TBD] [end:TBD]
  - [ ] Write on-call runbook [labels:type:docs] [status:TODO] [priority:MEDIUM] [estimate:6h] [start:TBD] [end:TBD]

- [ ] EPIC-005: CI/CD Pipeline Enhancement [labels:type:epic, area:infra] [status:TODO] [priority:MEDIUM] [estimate:40h] [start:2026-03-21] [end:2026-04-25]
  **Vision:** Automate build, test, security scanning, and deployment across all repositories.
  
  **Acceptance Criteria:**
  - ✅ All tests run in CI (unit, integration, E2E)
  - ✅ Security scanning enabled (SAST, dependency audit)
  - ✅ Automated deployments to staging/prod
  - ✅ Zero manual deployment steps
  - ✅ Build time < 15 minutes
  - ✅ All PRs require passing checks before merge
  
  **Timeline:**
  - Phase 1: Test automation & GitHub Actions setup
  - Phase 2: Security scanning integration
  - Phase 3: Deployment automation

  - [ ] Set up GitHub Actions workflows [labels:type:task, area:infra] [status:TODO] [priority:HIGH] [estimate:12h] [start:TBD] [end:TBD]
  - [ ] Add security scanning (Trivy, SAST) [labels:type:task, area:infra] [status:TODO] [priority:HIGH] [estimate:8h] [start:TBD] [end:TBD]
  - [ ] Implement automated deployments [labels:type:task, area:infra] [status:TODO] [priority:MEDIUM] [estimate:12h] [start:TBD] [end:TBD]
  - [ ] Document deployment procedures [labels:type:docs] [status:TODO] [priority:MEDIUM] [estimate:8h] [start:TBD] [end:TBD]

---

## Business / Product Epics

- [ ] EPIC-006: Harmony Mainnet Launch [labels:type:epic] [status:TODO] [priority:CRITICAL] [estimate:0h] [start:2026-03-07] [end:2026-03-21]
  **Vision:** Launch Aragon on Harmony mainnet with full feature parity to testnet.
  
  **Acceptance Criteria:**
  - ✅ All epics (EPIC-001 through EPIC-005) complete & verified on testnet
  - ✅ Security audit completed (external)
  - ✅ Mainnet contract deployment (with upgrade proxy)
  - ✅ Mainnet indexer deployment
  - ✅ Mainnet app deployment (vercel)
  - ✅ Monitoring & alerting active
  - ✅ Launch announcement & documentation
  
  **Timeline:**
  - Pre-launch (2026-03-07 to 2026-03-18): Final testnet verification
  - Launch day (2026-03-21): Mainnet deployment
  - Post-launch (2026-03-21+): Monitoring & incident response
  
  **Risks:**
  - 🚨 Unknown contract vulnerabilities → Mitigation: Professional audit, testnet burn-in
  - 🚨 Indexer crashes on mainnet load → Mitigation: Load testing, monitoring
  - 🚨 User adoption slower than expected → Mitigation: Community communication
  - 🚨 Chain-specific issues (Harmony quirks) → Mitigation: Fork testing, RPC resilience

  - [ ] Complete all feature epics (EPIC-001 through EPIC-005) [labels:type:epic] [status:TODO] [priority:CRITICAL] [estimate:0h] [start:2026-01-21] [end:2026-02-28]
  - [ ] External security audit [labels:type:security] [status:TODO] [priority:CRITICAL] [estimate:0h] [start:2026-02-18] [end:2026-03-07]
  - [ ] Mainnet deployment readiness review [labels:type:qa] [status:TODO] [priority:CRITICAL] [estimate:8h] [start:2026-03-07] [end:2026-03-18]
  - [ ] Execute mainnet deployment [labels:type:task] [status:TODO] [priority:CRITICAL] [estimate:8h] [start:2026-03-21] [end:2026-03-21]
  - [ ] Launch announcement [labels:type:docs] [status:TODO] [priority:HIGH] [estimate:4h] [start:2026-03-21] [end:2026-03-21]
  - [ ] Post-launch monitoring (2 weeks) [labels:type:ops] [status:TODO] [priority:CRITICAL] [estimate:0h] [start:2026-03-21] [end:2026-04-04]

---

## Template Instructions

### How to Use This Template

1. **Copy this file** to `<repo-root>/EPIC.md`
2. **Replace epic titles** with your own (e.g., "Multi-Sig Plugin")
3. **Fill in Vision, Acceptance Criteria, Timeline, Risks** (required)
4. **Add features and subtasks** under each epic
5. **Set start/end dates** for phases
6. **Link to related FEATURE, TASK, BUG items** (e.g., `FEATURE-001`)
7. **Mark progress** as features complete
8. **Sync to GitHub** via GitIssue-Manager (optional)

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
