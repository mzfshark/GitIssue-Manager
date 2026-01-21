# Feature: New Functionality & Enhancements

Template for FEATURE.md files across repositories.

**Purpose:** Track new features, enhancements, and user-facing improvements.

**Rules:**
- Every checkbox line MUST include metadata tags: [labels:...] [status:...] [priority:...] [estimate:..h] [start:YYYY-MM-DD] [end:YYYY-MM-DD]
- Subtasks are indented by 2 spaces under their parent
- Prefer short, action-oriented titles and descriptive summaries
- Use FEATURE-NNN ID format (unique within repository)

---

## Milestone: Core Feature Development

- [ ] FEATURE-001: Implement reorg-safe indexing [labels:type:feature, area:indexing, area:backend] [status:TODO] [priority:HIGH] [estimate:20h] [start:TBD] [end:TBD]
  **Description:** Implement production-grade indexing with reorg detection and recovery.

  - [ ] Add idempotency keys to event handlers [labels:type:feature] [status:TODO] [priority:HIGH] [estimate:4h] [start:TBD] [end:TBD]
  - [ ] Implement reorg detection logic [labels:type:feature] [status:TODO] [priority:HIGH] [estimate:6h] [start:TBD] [end:TBD]
  - [ ] Add rollback mechanism [labels:type:feature] [status:TODO] [priority:HIGH] [estimate:6h] [start:TBD] [end:TBD]
  - [ ] Create reorg recovery tests [labels:type:test] [status:TODO] [priority:HIGH] [estimate:4h] [start:TBD] [end:TBD]

- [ ] FEATURE-002: Metadata fallback system [labels:type:feature, area:backend, area:frontend] [status:TODO] [priority:MEDIUM] [estimate:16h] [start:TBD] [end:TBD]
  **Description:** Implement resilient metadata sourcing with deterministic fallback chain.

  - [ ] Define fallback order (on-chain → cache → placeholder) [labels:type:feature] [status:TODO] [priority:MEDIUM] [estimate:2h] [start:TBD] [end:TBD]
  - [ ] Implement on-chain metadata extraction [labels:type:feature] [status:TODO] [priority:MEDIUM] [estimate:4h] [start:TBD] [end:TBD]
  - [ ] Add caching layer [labels:type:feature] [status:TODO] [priority:MEDIUM] [estimate:4h] [start:TBD] [end:TBD]
  - [ ] Implement frontend fallback UI [labels:type:feature, area:frontend] [status:TODO] [priority:MEDIUM] [estimate:4h] [start:TBD] [end:TBD]
  - [ ] Add integrity validation [labels:type:feature] [status:TODO] [priority:MEDIUM] [estimate:2h] [start:TBD] [end:TBD]

- [ ] FEATURE-003: Native-token voting support [labels:type:feature, area:contracts, area:backend, area:frontend] [status:TODO] [priority:HIGH] [estimate:24h] [start:TBD] [end:TBD]
  **Description:** Enable voting and execution with native token transfers.

  - [ ] Design native-token execution schema [labels:type:feature] [status:TODO] [priority:HIGH] [estimate:3h] [start:TBD] [end:TBD]
  - [ ] Implement RPC-based power provider [labels:type:feature, area:backend] [status:TODO] [priority:HIGH] [estimate:8h] [start:TBD] [end:TBD]
  - [ ] Add contract execution path for native tokens [labels:type:feature, area:contracts] [status:TODO] [priority:HIGH] [estimate:6h] [start:TBD] [end:TBD]
  - [ ] Display native-token semantics in UI [labels:type:feature, area:frontend] [status:TODO] [priority:MEDIUM] [estimate:4h] [start:TBD] [end:TBD]
  - [ ] Add integration tests [labels:type:test] [status:TODO] [priority:HIGH] [estimate:3h] [start:TBD] [end:TBD]

---

## Milestone: User Experience Enhancements

- [ ] FEATURE-004: Plugin uninstall with warnings [labels:type:feature, area:frontend] [status:TODO] [priority:MEDIUM] [estimate:12h] [start:TBD] [end:TBD]
  **Description:** Implement safe plugin uninstall flow with clear user warnings.

  - [ ] Design uninstall confirmation dialog [labels:type:design] [status:TODO] [priority:MEDIUM] [estimate:2h] [start:TBD] [end:TBD]
  - [ ] Implement warning UX [labels:type:feature, area:frontend] [status:TODO] [priority:MEDIUM] [estimate:4h] [start:TBD] [end:TBD]
  - [ ] Handle post-uninstall state [labels:type:feature, area:frontend] [status:TODO] [priority:MEDIUM] [estimate:3h] [start:TBD] [end:TBD]
  - [ ] Add user testing [labels:type:qa] [status:TODO] [priority:LOW] [estimate:3h] [start:TBD] [end:TBD]

- [ ] FEATURE-005: Graceful degradation (API unavailable) [labels:type:feature, area:frontend] [status:TODO] [priority:HIGH] [estimate:10h] [start:TBD] [end:TBD]
  **Description:** Ensure app works when backend API is temporarily unavailable.

  - [ ] Implement error boundary [labels:type:feature, area:frontend] [status:TODO] [priority:HIGH] [estimate:3h] [start:TBD] [end:TBD]
  - [ ] Add offline mode with cached data [labels:type:feature, area:frontend] [status:TODO] [priority:HIGH] [estimate:4h] [start:TBD] [end:TBD]
  - [ ] Implement retry logic with backoff [labels:type:feature, area:frontend] [status:TODO] [priority:MEDIUM] [estimate:2h] [start:TBD] [end:TBD]
  - [ ] Add user-friendly error messages [labels:type:feature] [status:TODO] [priority:MEDIUM] [estimate:1h] [start:TBD] [end:TBD]

- [ ] FEATURE-006: Real-time proposal updates [labels:type:feature, area:frontend, area:backend] [status:TODO] [priority:MEDIUM] [estimate:16h] [start:TBD] [end:TBD]
  **Description:** Stream proposal state changes to users in real-time.

  - [ ] Design WebSocket schema [labels:type:design] [status:TODO] [priority:MEDIUM] [estimate:2h] [start:TBD] [end:TBD]
  - [ ] Implement backend WebSocket server [labels:type:feature, area:backend] [status:TODO] [priority:MEDIUM] [estimate:6h] [start:TBD] [end:TBD]
  - [ ] Implement frontend WebSocket client [labels:type:feature, area:frontend] [status:TODO] [priority:MEDIUM] [estimate:6h] [start:TBD] [end:TBD]
  - [ ] Add fallback polling if WebSocket unavailable [labels:type:feature] [status:TODO] [priority:LOW] [estimate:2h] [start:TBD] [end:TBD]

---

## Milestone: Advanced Features (Future)

- [ ] FEATURE-007: Proposal simulation [labels:type:feature, area:backend] [status:TODO] [priority:LOW] [estimate:20h] [start:TBD] [end:TBD]
  **Description:** Allow users to simulate proposal execution before voting.

  - [ ] Design simulation API [labels:type:design] [status:TODO] [priority:LOW] [estimate:3h] [start:TBD] [end:TBD]
  - [ ] Implement backend simulator [labels:type:feature, area:backend] [status:TODO] [priority:LOW] [estimate:12h] [start:TBD] [end:TBD]
  - [ ] Add frontend simulation UI [labels:type:feature, area:frontend] [status:TODO] [priority:LOW] [estimate:4h] [start:TBD] [end:TBD]
  - [ ] Write simulation tests [labels:type:test] [status:TODO] [priority:LOW] [estimate:1h] [start:TBD] [end:TBD]

- [ ] FEATURE-008: Multi-language support [labels:type:feature, area:frontend] [status:TODO] [priority:LOW] [estimate:12h] [start:TBD] [end:TBD]
  **Description:** Add i18n support for multiple languages.

  - [ ] Set up i18n framework [labels:type:feature, area:frontend] [status:TODO] [priority:LOW] [estimate:3h] [start:TBD] [end:TBD]
  - [ ] Extract user-facing strings [labels:type:task] [status:TODO] [priority:LOW] [estimate:4h] [start:TBD] [end:TBD]
  - [ ] Add language selector [labels:type:feature, area:frontend] [status:TODO] [priority:LOW] [estimate:2h] [start:TBD] [end:TBD]
  - [ ] Translate to initial languages [labels:type:task] [status:TODO] [priority:LOW] [estimate:3h] [start:TBD] [end:TBD]

---

## Milestone: Integration & Compatibility

- [ ] FEATURE-009: Network switching support [labels:type:feature, area:frontend] [status:TODO] [priority:MEDIUM] [estimate:8h] [start:TBD] [end:TBD]
  **Description:** Allow users to switch between networks (Harmony, Ethereum, Polygon, etc.).

  - [ ] Add network selector to UI [labels:type:feature, area:frontend] [status:TODO] [priority:MEDIUM] [estimate:3h] [start:TBD] [end:TBD]
  - [ ] Update API endpoints per network [labels:type:feature, area:backend] [status:TODO] [priority:MEDIUM] [estimate:2h] [start:TBD] [end:TBD]
  - [ ] Clear cache on network switch [labels:type:feature, area:frontend] [status:TODO] [priority:MEDIUM] [estimate:1h] [start:TBD] [end:TBD]
  - [ ] Test cross-network scenarios [labels:type:test] [status:TODO] [priority:MEDIUM] [estimate:2h] [start:TBD] [end:TBD]

- [ ] FEATURE-010: Hardware wallet support [labels:type:feature, area:frontend] [status:TODO] [priority:LOW] [estimate:10h] [start:TBD] [end:TBD]
  **Description:** Enable signing with hardware wallets (Ledger, Trezor).

  - [ ] Integrate hardware wallet library [labels:type:feature, area:frontend] [status:TODO] [priority:LOW] [estimate:4h] [start:TBD] [end:TBD]
  - [ ] Implement signing flow [labels:type:feature, area:frontend] [status:TODO] [priority:LOW] [estimate:4h] [start:TBD] [end:TBD]
  - [ ] Add hardware wallet tests [labels:type:test] [status:TODO] [priority:LOW] [estimate:2h] [start:TBD] [end:TBD]

---

## Template Instructions

### How to Use This Template

1. **Copy this file** to `<repo-root>/FEATURE.md`
2. **Replace feature titles** with your own (e.g., "Plugin marketplace")
3. **Add/remove subtasks** as needed
4. **Fill in metadata tags** with real values:
   - Replace `[start:TBD]` with `[start:2026-01-21]`
   - Replace `[end:TBD]` with `[end:2026-01-22]`
   - Choose appropriate labels, priority, estimate
5. **Add description** under each feature (3–5 sentences)
6. **Mark completed items** as `[x]` when done
7. **Sync to GitHub** via GitIssue-Manager (optional, see SYNC_COMMANDS.md)

### Feature Lifecycle

```
FEATURE-001: New Feature
├── Design phase (MEDIUM priority)
│   ├── [ ] Write specification
│   ├── [ ] Design UI mockups
│   └── [ ] Review with team
├── Implementation phase (HIGH priority)
│   ├── [ ] Implement backend
│   ├── [ ] Implement frontend
│   └── [ ] Integrate
├── Testing phase (HIGH priority)
│   ├── [ ] Unit tests
│   ├── [ ] Integration tests
│   └── [ ] User testing
└── Release phase (MEDIUM priority)
    ├── [ ] Documentation
    ├── [ ] Release notes
    └── [ ] Deploy to production
```

### Feature Request Process

1. **Create feature issue** in GitHub (if not in FEATURE.md)
2. **Write specification** in corresponding subtask
3. **Get team approval** before implementation
4. **Mark FEATURE as IN_PROGRESS** when work starts
5. **Update status** as subtasks complete
6. **Mark FEATURE as DONE** when released

### Metadata Tag Reference

```markdown
[labels:type:feature, area:backend]  ← Categories
[status:TODO|IN_PROGRESS|DONE]       ← Current state
[priority:HIGH|MEDIUM|LOW]           ← Urgency
[estimate:12h]                       ← Hours needed
[start:2026-01-21]                   ← Start date (ISO 8601)
[end:2026-01-22]                     ← End date (ISO 8601)
```

### Acceptance Criteria Template

Add this to feature description:

```markdown
**Acceptance Criteria:**
- [ ] Feature works on Chrome, Firefox, Safari
- [ ] Mobile responsive (< 600px width)
- [ ] Accessibility: WCAG 2.1 AA standard
- [ ] Error cases handled gracefully
- [ ] User documentation updated
- [ ] No performance regression (< 5% slower)
```

---

## Example: Filled-in Feature

```markdown
- [x] FEATURE-001: Implement reorg-safe indexing [labels:type:feature, area:indexing, area:backend] [status:DONE] [priority:HIGH] [estimate:20h] [start:2026-01-15] [end:2026-01-20]
  **Description:** Implement production-grade indexing with reorg detection and recovery.

  - [x] Add idempotency keys to event handlers [labels:type:feature] [status:DONE] [priority:HIGH] [estimate:4h] [start:2026-01-15] [end:2026-01-15]
  - [x] Implement reorg detection logic [labels:type:feature] [status:DONE] [priority:HIGH] [estimate:6h] [start:2026-01-16] [end:2026-01-17]
  - [x] Add rollback mechanism [labels:type:feature] [status:DONE] [priority:HIGH] [estimate:6h] [start:2026-01-18] [end:2026-01-19]
  - [x] Create reorg recovery tests [labels:type:test] [status:DONE] [priority:HIGH] [estimate:4h] [start:2026-01-20] [end:2026-01-20]

**Acceptance Criteria Met:**
- ✅ All reorg scenarios tested (5, 10, 20 block reorgs)
- ✅ No duplicate events in database
- ✅ Recovery < 60 seconds
- ✅ Full test coverage (95%)
```

---

**Version:** 1.0  
**Last Updated:** 2026-01-21  
**Status:** Ready to use  
