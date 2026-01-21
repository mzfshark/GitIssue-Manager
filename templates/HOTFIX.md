# Hotfix: Urgent Production Fixes

Template for HOTFIX.md files across repositories.

**Purpose:** Track critical production fixes that bypass normal sprint planning and require immediate deployment.

**Rules:**
- Every checkbox line MUST include metadata tags: [labels:...] [status:...] [priority:...] [estimate:..h] [start:YYYY-MM-DD] [end:YYYY-MM-DD]
- Subtasks are indented by 2 spaces under their parent
- Use HOTFIX-NNN ID format (unique within repository)
- Always include: Issue Description, SLA, Severity, Rollback Plan
- Hotfixes MUST be deployed within SLA (4-24h depending on severity)

---

## Critical Hotfixes (SLA: 2-4 hours)

- [ ] HOTFIX-001: Vote duplication causes incorrect vote count [labels:type:hotfix, area:backend, priority:critical] [status:INVESTIGATION] [priority:CRITICAL] [estimate:4h] [start:2026-01-21] [end:2026-01-21]
  **Issue:** Production proposal shows 5,000 votes but should show 2,500 (duplicates from reorg).
  **SLA:** Fix deployed within 4 hours
  **Severity:** Critical — Governance calculations broken; DAO can't execute votes correctly.
  **Impact:** All proposals created in last 7 days potentially invalid.
  
  **Rollback Plan:**
  1. Revert to last known-good database snapshot (2026-01-20 18:00 UTC)
  2. Re-run vote aggregation on snapshots (30 min)
  3. Deploy previous indexer version (10 min)
  4. Verify vote counts match on-chain (5 min)
  5. Notify affected DAOs via email
  
  **Root Cause Investigation:**
  - [ ] Query duplicate VoteCast records [labels:type:investigation] [status:TODO] [priority:CRITICAL] [estimate:0.5h] [start:2026-01-21] [end:2026-01-21]
  - [ ] Identify affected proposals [labels:type:investigation] [status:TODO] [priority:CRITICAL] [estimate:0.5h] [start:2026-01-21] [end:2026-01-21]
  - [ ] Verify reorg occurred (query block hashes) [labels:type:investigation] [status:TODO] [priority:CRITICAL] [estimate:0.5h] [start:2026-01-21] [end:2026-01-21]
  
  **Emergency Fix:**
  - [ ] Apply idempotency fix to event handler [labels:type:hotfix] [status:TODO] [priority:CRITICAL] [estimate:1h] [start:2026-01-21] [end:2026-01-21]
  - [ ] Create migration to clean up duplicates [labels:type:hotfix] [status:TODO] [priority:CRITICAL] [estimate:0.5h] [start:2026-01-21] [end:2026-01-21]
  - [ ] Deploy hotfix to production [labels:type:deploy] [status:TODO] [priority:CRITICAL] [estimate:0.5h] [start:2026-01-21] [end:2026-01-21]
  - [ ] Monitor for regressions (1 hour post-deploy) [labels:type:ops] [status:TODO] [priority:CRITICAL] [estimate:1h] [start:2026-01-21] [end:2026-01-21]
  
  **Communication:**
  - [ ] Notify on-call team [labels:type:task] [status:TODO] [priority:CRITICAL] [estimate:0.25h] [start:2026-01-21] [end:2026-01-21]
  - [ ] Post status update in Slack #incidents [labels:type:task] [status:TODO] [priority:CRITICAL] [estimate:0.25h] [start:2026-01-21] [end:2026-01-21]
  - [ ] Notify affected DAOs (email) [labels:type:task] [status:TODO] [priority:CRITICAL] [estimate:0.5h] [start:2026-01-21] [end:2026-01-21]

---

## High-Priority Hotfixes (SLA: 4-8 hours)

- [ ] HOTFIX-002: API returns 500 errors during metadata fetch [labels:type:hotfix, area:backend] [status:TODO] [priority:HIGH] [estimate:6h] [start:TBD] [end:TBD]
  **Issue:** Proposal list endpoint crashing intermittently (500 errors ~20% of requests).
  **SLA:** Fix deployed within 8 hours
  **Severity:** High — Users can't view proposals; app is unusable.
  **Impact:** Affects all DAOs; <2% of requests succeed.
  
  **Rollback Plan:**
  1. Deploy previous API version (5 min)
  2. Revert to cached metadata fallback (automatic)
  3. Monitor error rate (should drop to 0 within 2 min)
  4. Post-mortem investigation (async)
  
  **Root Cause Investigation:**
  - [ ] Check API logs for error pattern [labels:type:investigation] [status:TODO] [priority:HIGH] [estimate:1h] [start:TBD] [end:TBD]
  - [ ] Identify correlating IPFS gateway failures [labels:type:investigation] [status:TODO] [priority:HIGH] [estimate:1h] [start:TBD] [end:TBD]
  - [ ] Load test API endpoint [labels:type:investigation] [status:TODO] [priority:HIGH] [estimate:1h] [start:TBD] [end:TBD]
  
  **Emergency Fix:**
  - [ ] Increase IPFS request timeout [labels:type:hotfix] [status:TODO] [priority:HIGH] [estimate:1h] [start:TBD] [end:TBD]
  - [ ] Implement circuit breaker for IPFS [labels:type:hotfix] [status:TODO] [priority:HIGH] [estimate:2h] [start:TBD] [end:TBD]
  - [ ] Deploy hotfix [labels:type:deploy] [status:TODO] [priority:HIGH] [estimate:0.5h] [start:TBD] [end:TBD]
  - [ ] Monitor error rate for 2 hours [labels:type:ops] [status:TODO] [priority:HIGH] [estimate:2h] [start:TBD] [end:TBD]

- [ ] HOTFIX-003: Frontend app crashes on load for some users [labels:type:hotfix, area:frontend] [status:TODO] [priority:HIGH] [estimate:4h] [start:TBD] [end:TBD]
  **Issue:** App crashes with `TypeError: Cannot read property 'address' of undefined` (affects ~30% of users).
  **SLA:** Fix deployed within 8 hours
  **Severity:** High — App unusable for affected users.
  **Impact:** New users with fresh wallet state most affected.
  
  **Rollback Plan:**
  1. Revert to previous app version (automatic via Vercel)
  2. Clear browser cache: `purge` CDN
  3. Monitor crash rate (should drop to 0)
  
  **Root Cause Investigation:**
  - [ ] Analyze sentry crash logs [labels:type:investigation] [status:TODO] [priority:HIGH] [estimate:1h] [start:TBD] [end:TBD]
  - [ ] Identify failing code line [labels:type:investigation] [status:TODO] [priority:HIGH] [estimate:0.5h] [start:TBD] [end:TBD]
  - [ ] Reproduce locally with fresh state [labels:type:investigation] [status:TODO] [priority:HIGH] [estimate:0.5h] [start:TBD] [end:TBD]
  
  **Emergency Fix:**
  - [ ] Add null-check guard [labels:type:hotfix] [status:TODO] [priority:HIGH] [estimate:0.5h] [start:TBD] [end:TBD]
  - [ ] Deploy to Vercel [labels:type:deploy] [status:TODO] [priority:HIGH] [estimate:0.5h] [start:TBD] [end:TBD]
  - [ ] Monitor crash rate (30 min post-deploy) [labels:type:ops] [status:TODO] [priority:HIGH] [estimate:0.5h] [start:TBD] [end:TBD]

---

## Medium-Priority Hotfixes (SLA: 8-24 hours)

- [ ] HOTFIX-004: Incorrect voting power calculation for delegated votes [labels:type:hotfix, area:backend] [status:TODO] [priority:MEDIUM] [estimate:8h] [start:TBD] [end:TBD]
  **Issue:** User's voting power shows 1000 tokens but should show 2500 (delegation not counted).
  **SLA:** Fix deployed within 24 hours
  **Severity:** Medium — Users undercounted on voting power; can still vote, but not at full strength.
  **Impact:** Affects ~5% of DAOs with delegation enabled.
  
  **Rollback Plan:**
  1. Query vote power calculation in API logs
  2. Identify query issue (SQL or cache)
  3. Deploy fix with corrected query
  4. Clear voting power cache (1 min)
  
  **Root Cause Investigation:**
  - [ ] Check vote power query in codebase [labels:type:investigation] [status:TODO] [priority:MEDIUM] [estimate:1h] [start:TBD] [end:TBD]
  - [ ] Verify delegation contract behavior [labels:type:investigation] [status:TODO] [priority:MEDIUM] [estimate:2h] [start:TBD] [end:TBD]
  - [ ] Compare on-chain vs. indexed values [labels:type:investigation] [status:TODO] [priority:MEDIUM] [estimate:1h] [start:TBD] [end:TBD]
  
  **Emergency Fix:**
  - [ ] Fix vote power query [labels:type:hotfix] [status:TODO] [priority:MEDIUM] [estimate:2h] [start:TBD] [end:TBD]
  - [ ] Add test for delegation scenario [labels:type:test] [status:TODO] [priority:MEDIUM] [estimate:1h] [start:TBD] [end:TBD]
  - [ ] Deploy hotfix [labels:type:deploy] [status:TODO] [priority:MEDIUM] [estimate:0.5h] [start:TBD] [end:TBD]

---

## Completed Hotfixes (Reference)

- [x] HOTFIX-000: Orphan permissions prevent plugin removal [labels:type:hotfix, area:contracts] [status:FIXED] [priority:HIGH] [estimate:6h] [start:2026-01-10] [end:2026-01-11]
  **Issue:** Plugin uninstall fails silently; permissions remain in DAO.
  **SLA:** Fixed within 24 hours ✅
  **Severity:** High — Users blocked from uninstalling plugins.
  **Impact:** 3 affected DAOs; workaround: contract call via Etherscan.
  
  **Resolution:**
  - ✅ Added multi-batch revoke to uninstall handler (2h)
  - ✅ Deployed hotfix (0.5h)
  - ✅ Cleaned up orphan permissions in 3 DAOs (0.5h)
  - ✅ Added regression tests (3h)
  - ✅ Merged to develop branch with PR review (1h)
  
  **Lessons Learned:**
  - Need integration tests for permission lifecycle before merging features
  - Uninstall flow should be in critical path of feature testing
  - Add pre-deploy checklist item: "Verify uninstall cleanup on testnet"

---

## Template Instructions

### How to Use This Template

1. **Copy this file** to `<repo-root>/HOTFIX.md`
2. **Create HOTFIX item immediately** when critical issue arises
3. **Fill in Issue Description, SLA, Severity, Impact, Rollback Plan** (required)
4. **Assign on-call engineer** within 15 minutes of creation
5. **Create subtasks** for investigation, fix, test, deploy, monitor
6. **Mark as FIXED** once deployed and stable
7. **Post-mortem investigation** (async, after stability)

### Hotfix SLA Levels

| Severity | SLA | Definition | Example |
|----------|-----|-----------|---------|
| **Critical** | 2-4h | System down, data loss, security breach | Vote duplication, app crash |
| **High** | 4-8h | Major functionality broken | API errors, incorrect calculations |
| **Medium** | 8-24h | Workaround exists, poor UX | Edge case bugs, slow features |

### Hotfix Process (5-Step)

```
1. ALERT (t=0)
   ↓ Page on-call engineer, post to #incidents
2. INVESTIGATION (t=0-30min)
   ↓ Identify root cause, assess rollback risk
3. EMERGENCY FIX (t=30min-3h)
   ↓ Apply minimal fix, test, prepare deploy
4. DEPLOY & MONITOR (t=3h-4h)
   ↓ Deploy to production, monitor for regressions
5. COMMUNICATE & POST-MORTEM (t=4h+)
   ↓ Notify stakeholders, schedule post-mortem
```

### Rollback Plan Template

Always prepare a rollback before deploying a hotfix:

```markdown
**Rollback Plan:**
1. [Specific step 1 with timing]
2. [Specific step 2 with timing]
3. [Specific step 3 with timing]
4. [Verification step]
5. [Notification step]

**Total rollback time:** X minutes
**Data loss risk:** None / Minimal / Acceptable
```

### Communication Template

When hotfix is in progress:

```
🚨 INCIDENT: [Title]
Status: INVESTIGATING → IN_PROGRESS → MONITORING → RESOLVED
ETA: [time]
Updates: [#1 root cause found] → [#2 fix deployed] → [#3 stable]
```

### Metadata Tag Reference

```markdown
[labels:type:hotfix, area:backend]   ← Must include "type:hotfix"
[status:INVESTIGATION|IN_PROGRESS|MONITORING|FIXED]
[priority:CRITICAL|HIGH|MEDIUM]      ← Never LOW for hotfixes
[estimate:4h]                        ← Total time to fix + monitor
[start:2026-01-21]                   ← Start date (ISO 8601)
[end:2026-01-21]                     ← End date (same day expected)
```

### Post-Mortem Template

After hotfix is stable, schedule post-mortem within 48 hours:

```markdown
**POST-MORTEM: [Title]**
Date: [date]
Attendees: [on-call], [on-call-manager], [responsible-dev], [product]

**Timeline:**
- t=00:00 — Issue reported by [user/monitoring]
- t=00:15 — Root cause identified (reorg causing duplicates)
- t=01:00 — Fix deployed to production
- t=01:30 — System stable, monitoring ongoing

**Root Cause:**
Event handlers not idempotent; no unique constraints on events.

**Why wasn't this caught earlier?**
- No reorg testing before feature merge
- Insufficient test coverage for edge cases
- No database constraints (migration oversight)

**Action Items:**
1. [ ] Add reorg tests to critical path (Eng Lead)
2. [ ] Add pre-deploy checklist: "Test reorg scenarios" (QA)
3. [ ] Review all event handlers for idempotency (Eng)
4. [ ] Increase test coverage for event handlers to 95% (Eng)

**Preventive Measures for Future:**
- Always test event handlers with reorg simulation
- Use database constraints (UNIQUE keys) for critical data
- Mandatory code review for indexing changes
- Add property-based testing for idempotency
```

---

## Example: Filled-in Hotfix

```markdown
- [x] HOTFIX-000: Orphan permissions prevent plugin removal [labels:type:hotfix, area:contracts] [status:FIXED] [priority:HIGH] [estimate:6h] [start:2026-01-10] [end:2026-01-11]
  **Issue:** Plugin uninstall fails silently; permissions remain in DAO.
  **SLA:** Fixed within 24 hours ✅
  **Severity:** High — Users blocked from uninstalling plugins.
  **Impact:** 3 affected DAOs; workaround: contract call via Etherscan.
  
  **Rollback Plan:**
  1. Revert to commit abc123def (5 min)
  2. Redeploy old version to testnet (10 min)
  3. Verify uninstall still fails (expected) (5 min)
  4. If regression, revert to commit before hotfix (5 min)
  
  **Resolution Timeline:**
  - 2026-01-10 14:00 — Issue reported by DAO admin
  - 2026-01-10 14:15 — Root cause identified (missing revoke call)
  - 2026-01-10 15:00 — Fix implemented and tested locally
  - 2026-01-10 16:00 — Deployed to testnet
  - 2026-01-10 17:00 — Deployed to mainnet (after smoke tests)
  - 2026-01-11 08:00 — Post-mortem completed
  
  **Metrics:**
  - ✅ SLA met (deployed in 3 hours)
  - ✅ Zero regressions
  - ✅ All 3 DAOs uninstall working
  - ✅ No data loss
```

---

**Version:** 1.0  
**Last Updated:** 2026-01-21  
**Status:** Ready to use  
