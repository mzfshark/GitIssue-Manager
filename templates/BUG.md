# Bug: Issue Tracking & Resolution

Template for BUG.md files across repositories.

**Purpose:** Track identified bugs, defects, and issues that need fixing.

**Rules:**
- Every checkbox line MUST include metadata tags: [labels:...] [status:...] [priority:...] [estimate:..h] [start:YYYY-MM-DD] [end:YYYY-MM-DD]
- Subtasks are indented by 2 spaces under their parent
- Prefer clear bug titles with severity indicators
- Use BUG-NNN ID format (unique within repository)
- Always include: Description, Severity, Root Cause, Solution

---

## Critical Issues (Production)

- [ ] BUG-001: Indexing lag on high-volume blocks [labels:type:bug, area:backend, priority:critical] [status:BACKLOG] [priority:HIGH] [estimate:12h] [start:TBD] [end:TBD]
  **Description:** Indexer falls 2-3 blocks behind during network congestion (>500 tx/block).
  **Severity:** High
  **Root Cause:** Event handler processing is sequential; no batching optimization.
  **Impact:** Users see stale proposal state (5-30 second delay).
  **Solution:** Implement batch processing with configurable window size.

  - [ ] Profile event processing bottleneck [labels:type:investigation] [status:TODO] [priority:HIGH] [estimate:2h] [start:TBD] [end:TBD]
  - [ ] Implement batch processing [labels:type:feature] [status:TODO] [priority:HIGH] [estimate:6h] [start:TBD] [end:TBD]
  - [ ] Add performance monitoring [labels:type:monitoring] [status:TODO] [priority:MEDIUM] [estimate:2h] [start:TBD] [end:TBD]
  - [ ] Test under load (1000+ tx/block) [labels:type:test] [status:TODO] [priority:HIGH] [estimate:2h] [start:TBD] [end:TBD]

- [ ] BUG-002: Metadata fetch timeout on slow IPFS gateways [labels:type:bug, area:backend] [status:IN_PROGRESS] [priority:HIGH] [estimate:8h] [start:2026-01-20] [end:TBD]
  **Description:** Proposal metadata requests timeout (5s default) when IPFS gateway is slow or unavailable.
  **Severity:** High
  **Root Cause:** Single IPFS gateway without fallback; no retry logic.
  **Impact:** Proposals shown without metadata; UI displays placeholder state.
  **Solution:** Implement fallback chain: on-chain → IPFS → fallback gateway → placeholder.

  - [x] Add timeout parameter to API calls [labels:type:feature] [status:DONE] [priority:HIGH] [estimate:1h] [start:2026-01-20] [end:2026-01-20]
  - [ ] Implement IPFS gateway fallback [labels:type:feature] [status:IN_PROGRESS] [priority:HIGH] [estimate:4h] [start:2026-01-20] [end:TBD]
  - [ ] Add retry with exponential backoff [labels:type:feature] [status:TODO] [priority:MEDIUM] [estimate:2h] [start:TBD] [end:TBD]
  - [ ] Test fallback scenarios [labels:type:test] [status:TODO] [priority:HIGH] [estimate:1h] [start:TBD] [end:TBD]

- [ ] BUG-003: Reorg causes duplicate VoteCast events [labels:type:bug, area:indexing, area:backend] [status:FIXED] [priority:HIGH] [estimate:6h] [start:2026-01-15] [end:2026-01-17]
  **Description:** When a reorg occurs, duplicate VoteCast events appear in database.
  **Severity:** Critical
  **Root Cause:** Event handlers lack idempotency; no unique constraints on events.
  **Impact:** Vote counts inflated; governance calculations incorrect.
  **Solution:** Add idempotency keys (txHash + logIndex) with upsert pattern.

  - [x] Add unique constraint to VoteCast table [labels:type:feature] [status:DONE] [priority:CRITICAL] [estimate:1h] [start:2026-01-15] [end:2026-01-15]
  - [x] Implement upsert pattern in handler [labels:type:feature] [status:DONE] [priority:CRITICAL] [estimate:3h] [start:2026-01-16] [end:2026-01-16]
  - [x] Add migration for existing duplicates [labels:type:task] [status:DONE] [priority:HIGH] [estimate:1h] [start:2026-01-17] [end:2026-01-17]
  - [x] Verify in production [labels:type:qa] [status:DONE] [priority:HIGH] [estimate:1h] [start:2026-01-17] [end:2026-01-17]

---

## High-Priority Issues

- [ ] BUG-004: Plugin uninstall may leave orphan permissions [labels:type:bug, area:contracts] [status:UNDER_REVIEW] [priority:HIGH] [estimate:10h] [start:2026-01-18] [end:TBD]
  **Description:** After plugin uninstall, some permission grants remain in DAO.
  **Severity:** High
  **Root Cause:** Uninstall handler doesn't revoke all plugin-related permissions (missing multi-batch logic).
  **Impact:** Plugin can still execute actions via leftover grants.
  **Solution:** Implement comprehensive permission cleanup with multi-batch revoke.

  - [ ] Audit all permission types used by plugin [labels:type:investigation] [status:TODO] [priority:HIGH] [estimate:2h] [start:TBD] [end:TBD]
  - [ ] Implement multi-batch revoke logic [labels:type:feature] [status:TODO] [priority:HIGH] [estimate:5h] [start:TBD] [end:TBD]
  - [ ] Add integration tests [labels:type:test] [status:TODO] [priority:HIGH] [estimate:2h] [start:TBD] [end:TBD]
  - [ ] Verify with live DAO uninstall [labels:type:qa] [status:TODO] [priority:HIGH] [estimate:1h] [start:TBD] [end:TBD]

- [ ] BUG-005: Address normalization breaks token balance lookups [labels:type:bug, area:frontend] [status:FIXED] [priority:HIGH] [estimate:4h] [start:2026-01-19] [end:2026-01-20]
  **Description:** Frontend sends non-checksummed addresses to backend; balance API returns 404.
  **Severity:** High
  **Root Cause:** Wagmi returns mixed-case addresses; backend uses checksummed comparison.
  **Impact:** Users can't see token balances; voting validation fails.
  **Solution:** Normalize addresses to checksum format before API calls.

  - [x] Add address normalization utility [labels:type:feature] [status:DONE] [priority:HIGH] [estimate:1h] [start:2026-01-19] [end:2026-01-19]
  - [x] Apply normalization in data hooks [labels:type:feature] [status:DONE] [priority:HIGH] [estimate:2h] [start:2026-01-19] [end:2026-01-20]
  - [x] Test with different address formats [labels:type:test] [status:DONE] [priority:HIGH] [estimate:1h] [start:2026-01-20] [end:2026-01-20]

- [ ] BUG-006: API metadata endpoint blocks on slow IPFS [labels:type:bug, area:backend] [status:IN_PROGRESS] [priority:MEDIUM] [estimate:6h] [start:2026-01-20] [end:TBD]
  **Description:** API request hangs if IPFS gateway is slow; entire API becomes unresponsive.
  **Severity:** High
  **Root Cause:** Metadata fetch blocks request handler; no timeout on IPFS calls.
  **Impact:** High latency on proposal list endpoints; cascading failures.
  **Solution:** Implement async metadata fetch with request timeout + cache fallback.

  - [ ] Add timeout to IPFS client [labels:type:feature] [status:IN_PROGRESS] [priority:HIGH] [estimate:2h] [start:2026-01-20] [end:TBD]
  - [ ] Implement async fetch (return stale cache if slow) [labels:type:feature] [status:TODO] [priority:HIGH] [estimate:3h] [start:TBD] [end:TBD]
  - [ ] Load test endpoint under slow IPFS [labels:type:test] [status:TODO] [priority:MEDIUM] [estimate:1h] [start:TBD] [end:TBD]

---

## Medium-Priority Issues

- [ ] BUG-007: Uninstall dialog doesn't show in some DAO states [labels:type:bug, area:frontend] [status:UNDER_REVIEW] [priority:MEDIUM] [estimate:4h] [start:TBD] [end:TBD]
  **Description:** When DAO is in certain permission states, uninstall dialog disappears.
  **Severity:** Medium
  **Root Cause:** Conditional rendering logic is overly restrictive; missing permission state.
  **Impact:** Users unable to access uninstall flow (workaround: direct contract call).
  **Solution:** Fix condition to include all valid DAO states for uninstall.

  - [ ] Identify all valid DAO states for uninstall [labels:type:investigation] [status:TODO] [priority:MEDIUM] [estimate:1h] [start:TBD] [end:TBD]
  - [ ] Update condition logic [labels:type:feature] [status:TODO] [priority:MEDIUM] [estimate:1h] [start:TBD] [end:TBD]
  - [ ] Add regression test [labels:type:test] [status:TODO] [priority:MEDIUM] [estimate:1h] [start:TBD] [end:TBD]
  - [ ] Verify with manual testing [labels:type:qa] [status:TODO] [priority:MEDIUM] [estimate:1h] [start:TBD] [end:TBD]

- [ ] BUG-008: Proposal card flickers on metadata update [labels:type:bug, area:frontend] [status:BACKLOG] [priority:MEDIUM] [estimate:3h] [start:TBD] [end:TBD]
  **Description:** Proposal title flashes (loading → loaded) when metadata fetches.
  **Severity:** Low
  **Root Cause:** Key-based rendering causes unmount/remount on data change.
  **Impact:** Minor visual glitch; UX feels janky.
  **Solution:** Memoize proposal components; use data keys instead of index.

  - [ ] Audit component keys [labels:type:investigation] [status:TODO] [priority:MEDIUM] [estimate:1h] [start:TBD] [end:TBD]
  - [ ] Implement proper memoization [labels:type:feature] [status:TODO] [priority:MEDIUM] [estimate:1h] [start:TBD] [end:TBD]
  - [ ] Test re-render behavior [labels:type:test] [status:TODO] [priority:LOW] [estimate:1h] [start:TBD] [end:TBD]

---

## Low-Priority Issues (Backlog)

- [ ] BUG-009: Error message truncated on small screens [labels:type:bug, area:frontend] [status:BACKLOG] [priority:LOW] [estimate:2h] [start:TBD] [end:TBD]
  **Description:** Long error messages are cut off on mobile devices.
  **Severity:** Low
  **Root Cause:** Error toast has fixed max-width; no responsive handling.
  **Impact:** Users can't read full error messages.
  **Solution:** Implement responsive toast sizing with text wrapping.

  - [ ] Update toast styling [labels:type:feature] [status:TODO] [priority:LOW] [estimate:1h] [start:TBD] [end:TBD]
  - [ ] Test on mobile (iPhone 5s, 6, etc.) [labels:type:qa] [status:TODO] [priority:LOW] [estimate:1h] [start:TBD] [end:TBD]

- [ ] BUG-010: Stale data in Redux store after reconnect [labels:type:bug, area:frontend] [status:BACKLOG] [priority:LOW] [estimate:4h] [start:TBD] [end:TBD]
  **Description:** After wallet reconnect, store retains old DAO data.
  **Severity:** Low
  **Root Cause:** Store isn't cleared on wallet account change.
  **Impact:** Rare edge case; users can force refresh.
  **Solution:** Clear Redux store on wallet account change.

  - [ ] Detect account change event [labels:type:feature] [status:TODO] [priority:LOW] [estimate:1h] [start:TBD] [end:TBD]
  - [ ] Implement store clear logic [labels:type:feature] [status:TODO] [priority:LOW] [estimate:1h] [start:TBD] [end:TBD]
  - [ ] Test account switching [labels:type:test] [status:TODO] [priority:LOW] [estimate:2h] [start:TBD] [end:TBD]

---

## Template Instructions

### How to Use This Template

1. **Copy this file** to `<repo-root>/BUG.md`
2. **Add bugs** in appropriate section (Critical → Low Priority)
3. **Fill in metadata tags** with real values:
   - Replace `[start:TBD]` with `[start:2026-01-21]`
   - Replace `[end:TBD]` with `[end:2026-01-22]`
   - Choose appropriate labels, priority, estimate
4. **Complete bug info:**
   - **Description:** What is broken? (1–2 sentences)
   - **Severity:** Low/Medium/High/Critical
   - **Root Cause:** Why is it broken? (technical analysis)
   - **Impact:** What's the user impact?
   - **Solution:** How to fix it? (technical approach)
5. **Add subtasks** for investigation, implementation, testing, verification
6. **Mark completed items** as `[x]` when done
7. **Sync to GitHub** via GitIssue-Manager (optional, see SYNC_COMMANDS.md)

### Bug Severity Levels

| Severity | Definition | Example | SLA |
|----------|-----------|---------|-----|
| **Critical** | System down, data loss, security breach | Duplicate votes, orphan perms | 2-4h |
| **High** | Major functionality broken | Metadata timeout, indexing lag | 8-24h |
| **Medium** | Workaround exists, poor UX | Dialog missing, flicker | 1-2 weeks |
| **Low** | Edge case, cosmetic | Small screens, rare state | Backlog |

### Bug Lifecycle

```
REPORTED → INVESTIGATED → ASSIGNED → IN_PROGRESS → TESTING → FIXED → VERIFIED
   ↓            ↓             ↓           ↓           ↓         ↓        ↓
  TODO      INVESTIGATION  TODO     IN_PROGRESS  TESTING    DONE     DONE
```

### Bug Status Values

| Status | Meaning |
|--------|---------|
| **BACKLOG** | Not yet triaged; low priority |
| **TODO** | Approved; waiting for dev |
| **INVESTIGATION** | Reproducing / analyzing root cause |
| **IN_PROGRESS** | Developer assigned; actively fixing |
| **UNDER_REVIEW** | Fix completed; waiting for review/testing |
| **TESTING** | QA testing the fix |
| **FIXED** | Fix deployed; monitoring in prod |
| **VERIFIED** | Confirmed fixed; no regression |

### Root Cause Analysis (5 Whys)

Template for complex bugs:

```markdown
**Root Cause Analysis:**
1. Why are votes duplicated?
   → Because reorg causes re-processing of events
2. Why are events re-processed?
   → Because handler rollback doesn't clear written data
3. Why doesn't handler rollback clear data?
   → Because no idempotency key exists (no upsert)
4. Why no idempotency key?
   → Oversight in design; not required during initial dev
5. Why discovered now?
   → Network reorg on testnet exposed the issue
```

### Metadata Tag Reference

```markdown
[labels:type:bug, area:backend]      ← Categories
[status:TODO|IN_PROGRESS|DONE]       ← Current state
[priority:HIGH|MEDIUM|LOW]           ← Urgency
[estimate:6h]                        ← Hours to fix
[start:2026-01-21]                   ← Start date (ISO 8601)
[end:2026-01-22]                     ← End date (ISO 8601)
```

### Common Bug Labels

| Label | Applies To |
|-------|-----------|
| **type:bug** | Defect (not working as intended) |
| **type:regression** | Previously working, now broken |
| **type:crash** | App crash or fatal error |
| **type:memory-leak** | Memory grows unbounded |
| **type:performance** | Slow / high latency |
| **type:security** | Vulnerability or exploit |
| **area:frontend** | UI/React issue |
| **area:backend** | API/Service issue |
| **area:contracts** | Smart contract issue |
| **area:indexing** | Event handler issue |
| **priority:critical** | System down |

---

## Example: Filled-in Bug

```markdown
- [x] BUG-003: Reorg causes duplicate VoteCast events [labels:type:bug, area:indexing, area:backend] [status:FIXED] [priority:HIGH] [estimate:6h] [start:2026-01-15] [end:2026-01-17]
  **Description:** When a reorg occurs, duplicate VoteCast events appear in database.
  **Severity:** Critical
  **Root Cause:** Event handlers lack idempotency; no unique constraints on events.
  **Impact:** Vote counts inflated; governance calculations incorrect.
  **Solution:** Add idempotency keys (txHash + logIndex) with upsert pattern.

  - [x] Add unique constraint to VoteCast table [labels:type:feature] [status:DONE] [priority:CRITICAL] [estimate:1h] [start:2026-01-15] [end:2026-01-15]
  - [x] Implement upsert pattern in handler [labels:type:feature] [status:DONE] [priority:CRITICAL] [estimate:3h] [start:2026-01-16] [end:2026-01-16]
  - [x] Add migration for existing duplicates [labels:type:task] [status:DONE] [priority:HIGH] [estimate:1h] [start:2026-01-17] [end:2026-01-17]
  - [x] Verify in production [labels:type:qa] [status:DONE] [priority:HIGH] [estimate:1h] [start:2026-01-17] [end:2026-01-17]

**Verification:**
- ✅ 47 duplicate VoteCast events cleaned up from prod DB
- ✅ New reorg test passes (5, 10, 20 block reorgs)
- ✅ Unique constraint prevents re-insertion
- ✅ Performance: < 2ms per vote (no regression)
```

---

**Version:** 1.0  
**Last Updated:** 2026-01-21  
**Status:** Ready to use  
