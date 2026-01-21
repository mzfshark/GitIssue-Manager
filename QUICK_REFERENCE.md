# Quick Reference: Production Scope Structure

Visual guide to all production artifacts and GitIssue-Manager integration.

---

## File Structure Summary

```
AragonOSX/
├── SPRINT.md              ← PRIMARY INPUT (69% complete, 16 items)
├── BUG.md                 ← REFERENCE (4 bugs tracked)
└── PLAN.md                ← INTERNAL (long-term planning)

aragon-app/
├── SPRINT.md              ← PRIMARY INPUT (73% complete, 15 items)
├── BUG.md                 ← REFERENCE (3 bugs tracked)
└── PLAN.md                ← INTERNAL (long-term planning)

Aragon-app-backend/
├── SPRINT.md              ← PRIMARY INPUT (17% complete, 12 items)
├── BUG.md                 ← REFERENCE (3 bugs tracked)
└── PLAN.md                ← INTERNAL (long-term planning)

GitIssue-Manager/
├── PRODUCTION_SCOPE.md    ← Master manifest (repository inventory)
├── ENGINE_INPUT_SPEC.md   ← Parsing specification (technical)
├── SYNC_COMMANDS.md       ← Ready-to-run commands (approval needed)
├── PRODUCTION_UPDATE_SUMMARY.md  ← This update (executive summary)
└── QUICK_REFERENCE.md     ← YOU ARE HERE (visual guide)
```

---

## Quick Stats Dashboard

| Metric | Value | Status |
|--------|-------|--------|
| **Total Sprint Items** | 43 | ✅ |
| **Items Complete** | 13 | ✅ |
| **Overall Completion** | 30% | 📋 On track |
| **High-Risk Blockers** | 0 | ✅ |
| **Repos Ready for Sync** | 3/3 | ✅ |
| **Bugs Tracked** | 10 | 📋 |
| **Bugs Fixed** | 3 | ✅ |
| **Sprint Duration** | 6 weeks | 2026-01-21 → 2026-02-28 |

---

## Sprint Breakdown by Repo

### 🔒 AragonOSX (Contracts) — 69% Complete
**Role:** Core plugin implementation, setup, executor  
**Owner:** Axodus/AragonOSX  
**Branch:** develop  

```
SPRINT.md Items (16 total, 11 done, 5 todo)
├── FEATURE-001: Indexing Resilience          [████████░] 80%
├── FEATURE-002: Plugin Uninstall             [████████░] 83%
├── FEATURE-003: Metadata Redundancy          [████░░░░░] 33%
├── FEATURE-004: Native-Token Support         [██████░░░] 67%
├── TASK-001: Testing & Validation            [░░░░░░░░░] 0%
└── TASK-002: Docs & Runbooks                 [░░░░░░░░░] 0%

BUGS: 4 tracked
├── BUG-001: Permission orphans [HIGH] 🔄 Under investigation
├── BUG-002: Metadata timeout [MEDIUM] 🔄 Under review
├── BUG-003: Reorg duplicates [MEDIUM] ✅ FIXED
└── BUG-004: Native-token marking [MEDIUM] ✅ FIXED
```

### 🎨 aragon-app (Frontend) — 73% Complete
**Role:** User-facing DAO governance UI  
**Owner:** Axodus/aragon-app  
**Branch:** feature/sprint1/validator-address-fix  

```
SPRINT.md Items (15 total, 11 done, 4 todo)
├── FEATURE-001: Install & Setup Forms        [███████░░] 91%
├── FEATURE-002: Install Prepare Flows        [░░░░░░░░░] 0%
├── FEATURE-003: UI Resilience                [░░░░░░░░░] 0%
├── FEATURE-004: Uninstall UX                 [░░░░░░░░░] 0%
├── FEATURE-005: Native-Token UX              [░░░░░░░░░] 0%
└── TASK-001: E2E Monitoring & QA             [░░░░░░░░░] 0%

BUGS: 3 tracked
├── BUG-001: Address normalization [MEDIUM] ✅ FIXED
├── BUG-002: Metadata blocks rendering [HIGH] 🔄 In progress
└── BUG-003: Uninstall dialog missing [MEDIUM] 🔄 Under review
```

### ⚙️ Aragon-app-Backend (Backend) — 17% Complete
**Role:** Event indexing, proposal metadata, voting power  
**Owner:** Axodus/Aragon-app-backend  
**Branch:** feature/sprint1/validator-address-fix  

```
SPRINT.md Items (12 total, 2 done, 10 todo)
├── FEATURE-001: Indexing Resilience          [██░░░░░░░] 20%
├── FEATURE-002: Observability                [░░░░░░░░░] 0%
├── FEATURE-003: Metadata Redundancy          [░░░░░░░░░] 0%
├── FEATURE-004: Native-Token Support         [░░░░░░░░░] 0%
└── TASK-001: Testing                         [░░░░░░░░░] 0%
   TASK-002: Operational Docs                 [░░░░░░░░░] 0%

BUGS: 3 tracked
├── BUG-001: Reorg duplicates [HIGH] ✅ FIXED
├── BUG-002: Metadata timeout [MEDIUM] 🔄 Under review
└── BUG-003: Indexing lag [LOW] 📋 Backlog
```

---

## Item ID Convention (Quick Reference)

**Format:** `TYPE-NNN`

```
FEATURE-001 → New feature for sprint
FEATURE-002 → Another feature
...
TASK-001 → Work item (maintenance, refactoring)
TASK-002 → Another task
...
BUG-001 → Bug fix with acceptance criteria
BUG-002 → Another bug
...
```

**Rules:**
- IDs are stable (don't change if item moves)
- Unique within sprint
- Appear at start of item title
- Never duplicated across repos

---

## Metadata Tags (Quick Reference)

**Location:** End of line in square brackets

**Example:**
```markdown
- [x] Add reorg detection [labels:type:feature, area:indexing] [status:DONE] [priority:high] [estimate:12h] [start:2026-01-20] [end:2026-01-22]
```

**Tag Guide:**

| Tag | Values | Example | Optional? |
|-----|--------|---------|-----------|
| labels | type:*, area:* | type:feature, area:backend | Yes |
| status | DONE, TODO, IN_PROGRESS | status:DONE | No (def: TODO) |
| priority | HIGH, MEDIUM, LOW | priority:high | Yes |
| estimate | Nh (hours) | estimate:12h | Yes |
| start | YYYY-MM-DD | start:2026-01-20 | Yes |
| end | YYYY-MM-DD | end:2026-01-22 | Yes |

---

## GitHub ProjectV2 Sync

### What Gets Created
```
3 GitHub Issues (1 per repo):
  ✓ AragonOSX/issues/XXX     [16 items, 69% complete]
  ✓ aragon-app/issues/XXX    [15 items, 73% complete]
  ✓ Aragon-app-backend/issues/XXX [12 items, 17% complete]

All attached to: github.com/users/mzfshark/projects/5
```

### Status Tracking
```
When sprint completion = 100%:
  Status field → "Ready"

Otherwise:
  Status field → "TODO" (or keep current)

Updates every sync:
  - Priority
  - Estimate (total hours)
  - Start/End dates
  - Nested checklist
```

### ⚠️ Limitation
**PARENT_ISSUE field not supported** (GitHub limitation)
- Workaround 1: Manual UI linking (recommended)
- Workaround 2: Playwright/Puppeteer automation (advanced)
- Workaround 3: GitHub Support request (long-term)

---

## Sync Workflow

### Step 1: Dry-Run (Preview)
```bash
cd GitIssue-Manager
node client/prepare.js --repos aragon-osx,aragon-app,aragon-app-backend --dry-run
```
✅ No GitHub writes  
✅ Shows what will be created  
✅ Validates all items  

### Step 2: Review Output
```bash
cat tmp/engine-input.json | head -100
```
✅ Check item counts  
✅ Verify labels  
✅ Confirm completion %  

### Step 3: Approve & Execute
```bash
GITHUB_TOKEN=<token> node scripts/prepare.sh --repos aragon-osx,aragon-app,aragon-app-backend --execute
```
✅ Creates 3 issues  
✅ Attaches to ProjectV2  
✅ Logs all operations  

### Step 4: Verify in GitHub
```
https://github.com/users/mzfshark/projects/5
✅ See 3 new sprint issues
✅ Check status/labels/estimates
✅ Review nested checklists
```

---

## Key Dependencies

```
Frontend (aragon-app)
    ↓ depends on
Backend API (Aragon-app-backend)
    ↓ depends on
Contracts (AragonOSX)
    ↓
All feed into → GitIssue-Manager → GitHub ProjectV2
```

**Critical Path:** Backend (17% complete) is slowest  
**Blocker Risk:** NONE (all critical items on track)  
**Timeline Risk:** LOW (6-week sprint, 2026-02-28 target)

---

## Release Calendar

| Date | Milestone | Action |
|------|-----------|--------|
| 2026-01-21 | Artifacts created | ✅ DONE |
| 2026-01-21 | Dry-run prepared | ⏳ Next |
| 2026-01-22 | Sync approved | ⏳ Pending |
| 2026-01-28 | Mid-sprint review | ⏳ Scheduled |
| 2026-02-04 | E2E manual test | ⏳ Scheduled |
| 2026-02-28 | All items done | 🎯 Target |
| 2026-03-07 | Production deploy | 🚀 Target |

---

## Commands Cheat Sheet

### Dry-Run (Safe, No Writes)
```bash
cd GitIssue-Manager
yarn prepare --repos aragon-osx,aragon-app,aragon-app-backend --dry-run
```

### Execute (Needs Approval)
```bash
GITHUB_TOKEN=<token> yarn prepare --repos aragon-osx,aragon-app,aragon-app-backend --execute
```

### Update Single Issue
```bash
yarn update-issue --repo "Axodus/AragonOSX" --issue-number <N> --sprint-file ../AragonOSX/SPRINT.md --execute
```

### Generate Status Report
```bash
yarn status-report --repos aragon-osx,aragon-app,aragon-app-backend --output REPORT.md
```

### View Audit Log
```bash
cat logs/audit.jsonl | tail -20
```

---

## Common Questions

**Q: Can I sync PLAN.md?**  
A: No. PLAN.md stays internal (long-term reference). Only SPRINT.md syncs.

**Q: What about BUG.md?**  
A: BUG.md is internal reference. Not synced automatically. Can be manually linked in issue.

**Q: How often should I update?**  
A: Weekly recommended. Bi-weekly minimum. Update via `yarn update-issue`.

**Q: What if I change an item ID?**  
A: Don't. IDs are stable. If you need to rename, create new ID and mark old as duplicate.

**Q: How do I rollback a sync?**  
A: Delete the GitHub issue (close + "not planned" reason) or use `gh issue delete`.

**Q: Can I sync to a different ProjectV2 board?**  
A: Yes. Change `--project` parameter or update `PRODUCTION_SCOPE.md` project URL.

---

## Files Reference

| File | Purpose | Read First? |
|------|---------|------------|
| PRODUCTION_SCOPE.md | Master manifest | 🟢 YES |
| ENGINE_INPUT_SPEC.md | Technical spec | 🟡 IF debugging |
| SYNC_COMMANDS.md | Ready-to-run commands | 🟢 YES |
| PRODUCTION_UPDATE_SUMMARY.md | Executive summary | 🟢 YES |
| QUICK_REFERENCE.md | YOU ARE HERE | 🔵 Navigation |
| SPRINT.md (per repo) | Sprint execution | 🟢 YES |
| BUG.md (per repo) | Bug tracking | 🟡 AS-needed |
| PLAN.md (per repo) | Long-term planning | 🔵 Internal only |

---

**Last Updated:** 2026-01-21  
**Status:** ✅ Ready for execution  
**Next Step:** Run dry-run → Review → Approve → Execute → Verify
