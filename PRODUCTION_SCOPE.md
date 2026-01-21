# Production Scope Manifest

GitIssue-Manager input and output tracking for HarmonyVoting E2E production rollout.

**Last Updated:** 2026-01-21  
**Manifest Version:** 1.0  
**Status:** Active  

---

## Overview

This manifest documents all production-grade planning artifacts (SPRINT.md, PLAN.md, BUG.md) that feed into the GitIssue-Manager parsing and syncing pipeline.

### File Convention (Per Repository)

| Artifact | Purpose | Creates Issues? | Source of Truth | Format |
|----------|---------|-----------------|-----------------|--------|
| SPRINT.md | Sprint execution checklist; contains deliverables | YES (1 issue per repo) | Checklist items with TYPE-NNN IDs | Markdown checklist with metadata tags |
| PLAN.md | Long-term planning; detailed context | NO (internal) | Milestone structure | Markdown with nested checkboxes |
| BUG.md | Known bugs and regressions | NO (internal) | Bug list | Markdown with status tracking |

---

## Repository Inventory

### 1. AragonOSX (Contracts)

**Role:** Core plugin contracts, setup, executor  
**Owner:** Axodus  
**Current Branch:** develop  
**Default Branch:** develop  

#### Production Artifacts
- **SPRINT.md**: Sprint 1 HarmonyVoting E2E Production Rollout
  - Location: `d:\Rede\Github\mzfshark\AragonOSX\SPRINT.md`
  - Updated: 2026-01-21
  - Status: Active (69% complete)
  - Items: 16 (11 completed, 5 TODO)
  - Sync to GitHub: Yes (single aggregated issue)

- **PLAN.md**: HarmonyVoting E2E Reliability (Long-term)
  - Location: `d:\Rede\Github\mzfshark\AragonOSX\PLAN.md`
  - Updated: 2026-01-09
  - Status: Reference (internal)
  - Items: 50+ milestones
  - Sync to GitHub: No (stays internal)

- **BUG.md**: Known issues and regressions
  - Location: `d:\Rede\Github\mzfshark\AragonOSX\BUG.md`
  - Updated: 2026-01-21
  - Status: 4 tracked bugs (3 fixed, 1 in investigation)
  - Sync to GitHub: No (internal, reference only)

#### Key Metrics
- Sprint completion: 69%
- Blockers: None (all critical items completed)
- Dependencies: None externally

---

### 2. aragon-app (Frontend)

**Role:** User-facing DAO governance UI  
**Owner:** Axodus  
**Current Branch:** feature/sprint1/validator-address-fix  
**Default Branch:** main  
**Active PR:** #162 (WIP: normalize validator address and add sprint artifacts)

#### Production Artifacts
- **SPRINT.md**: Sprint 1 Frontend UI & UX Production Release
  - Location: `d:\Rede\Github\mzfshark\aragon-app\SPRINT.md`
  - Updated: 2026-01-21
  - Status: Active (73% complete)
  - Items: 15 (11 completed, 4 TODO)
  - Sync to GitHub: Yes (single aggregated issue)

- **PLAN.md**: HarmonyVoting Frontend UI & UX Reliability (Long-term)
  - Location: `d:\Rede\Github\mzfshark\aragon-app\PLAN.md`
  - Updated: 2026-01-09
  - Status: Reference (internal)
  - Sync to GitHub: No (stays internal)

- **BUG.md**: UI/UX bugs and regressions
  - Location: `d:\Rede\Github\mzfshark\aragon-app\BUG.md`
  - Updated: 2026-01-21
  - Status: 3 tracked bugs (1 fixed, 2 in progress)
  - Sync to GitHub: No (internal, reference only)

#### Key Metrics
- Sprint completion: 73%
- Blockers: None
- Dependencies: Aragon-app-backend (indexing API)

---

### 3. Aragon-app-backend (Backend API & Indexer)

**Role:** Event indexing, proposal metadata, native-token power  
**Owner:** Axodus  
**Current Branch:** feature/sprint1/validator-address-fix  
**Default Branch:** development  
**Active PR:** #1 (WIP: add PLAN_subtasks and sprint artifacts)

#### Production Artifacts
- **SPRINT.md**: Sprint 1 Backend Indexing Production Rollout
  - Location: `d:\Rede\Github\mzfshark\Aragon-app-backend\SPRINT.md`
  - Updated: 2026-01-21
  - Status: Active (17% complete)
  - Items: 12 (2 completed, 10 TODO)
  - Sync to GitHub: Yes (single aggregated issue)

- **PLAN.md**: HarmonyVoting Backend Indexing & Reliability (Long-term)
  - Location: `d:\Rede\Github\mzfshark\Aragon-app-backend\PLAN.md`
  - Updated: 2026-01-09
  - Status: Reference (internal)
  - Sync to GitHub: No (stays internal)

- **BUG.md**: Backend bugs and regressions
  - Location: `d:\Rede\Github\mzfshark\Aragon-app-backend\BUG.md`
  - Updated: 2026-01-21
  - Status: 3 tracked bugs (1 fixed, 2 in progress)
  - Sync to GitHub: No (internal, reference only)

#### Key Metrics
- Sprint completion: 17%
- Blockers: None (foundational work in progress)
- Dependencies: AragonOSX (contract ABIs), external IPFS gateway

---

### 4. GitIssue-Manager (Tool)

**Role:** Orchestrates parsing and syncing of planning artifacts to GitHub  
**Owner:** mzfshark  
**Current Branch:** main  
**Default Branch:** main  

#### Production Artifacts
- **README.md**: Tool documentation and usage
- **QUICKSTART.md**: Step-by-step setup guide
- **PLAN.md**: GitIssue-Manager roadmap (internal)
- **Templates/**: Markdown templates for SPRINT.md, PLAN.md, BUG.md

#### Key Metrics
- Status: Operational
- Current sync: Supporting 3 active repos (AragonOSX, aragon-app, Aragon-app-backend)
- Last audit: 2026-01-21

---

## Artifact Parsing Rules

### SPRINT.md Parsing

**Rule:** Every SPRINT.md becomes ONE aggregated GitHub issue per repository.

**Item ID Format:** `TYPE-NNN` where TYPE ∈ {FEATURE, TASK, BUG}

**Metadata Tags (per checklist item):**
```
[labels:type:task, area:frontend] [status:DONE] [priority:high] [estimate:4h] [start:2026-01-20] [end:2026-01-22]
```

**Mapping to GitHub Issue:**
- Title: `[Sprint] HarmonyVoting Production Rollout – Week X`
- Body: Full checklist tree (nested structure preserved)
- Labels: `sprint`, `production`, `harmony-voting`, + all item labels
- Status: ProjectV2 field (TODO → Ready when 100% complete)
- Assignee: Team lead (manual assignment)

### PLAN.md Parsing

**Rule:** PLAN.md stays INTERNAL (not synced to GitHub issues).

**Purpose:** Long-term planning reference; milestone tracking; context.

**Audience:** Internal team; used for quarterly planning and retrospectives.

### BUG.md Parsing

**Rule:** BUG.md stays INTERNAL (not synced to GitHub issues).

**Purpose:** Track known bugs, regressions, and investigation status.

**Audience:** Internal team; reference during incident response.

---

## Sync Commands (GitIssue-Manager)

### Pre-sync Checklist
- [ ] All SPRINT.md files have consistent TYPE-NNN ID format
- [ ] All metadata tags present on each checklist item
- [ ] No duplicate IDs across repos
- [ ] PLAN.md and BUG.md marked as internal (do not sync)

### Sync Operations

#### Repository: AragonOSX
```bash
# Dry-run preview (no GitHub writes)
gh issue create \
  --title "[Sprint] HarmonyVoting E2E Production Rollout – Sprint 1" \
  --body-file AragonOSX/SPRINT.md \
  --project "https://github.com/users/mzfshark/projects/5" \
  --label "sprint,production,harmony-voting,area:indexing,area:contracts" \
  --dry-run

# Execute (approval required)
gh issue create \
  --title "[Sprint] HarmonyVoting E2E Production Rollout – Sprint 1" \
  --body-file AragonOSX/SPRINT.md \
  --project "https://github.com/users/mzfshark/projects/5" \
  --label "sprint,production,harmony-voting,area:indexing,area:contracts"
```

#### Repository: aragon-app
```bash
# Dry-run
gh issue create \
  --title "[Sprint] Frontend UI & UX Production Release – Sprint 1" \
  --body-file aragon-app/SPRINT.md \
  --project "https://github.com/users/mzfshark/projects/5" \
  --label "sprint,production,harmony-voting,area:frontend" \
  --dry-run

# Execute
gh issue create \
  --title "[Sprint] Frontend UI & UX Production Release – Sprint 1" \
  --body-file aragon-app/SPRINT.md \
  --project "https://github.com/users/mzfshark/projects/5" \
  --label "sprint,production,harmony-voting,area:frontend"
```

#### Repository: Aragon-app-backend
```bash
# Dry-run
gh issue create \
  --title "[Sprint] Backend Indexing Production Rollout – Sprint 1" \
  --body-file Aragon-app-backend/SPRINT.md \
  --project "https://github.com/users/mzfshark/projects/5" \
  --label "sprint,production,harmony-voting,area:backend,area:indexing" \
  --dry-run

# Execute
gh issue create \
  --title "[Sprint] Backend Indexing Production Rollout – Sprint 1" \
  --body-file Aragon-app-backend/SPRINT.md \
  --project "https://github.com/users/mzfshark/projects/5" \
  --label "sprint,production,harmony-voting,area:backend,area:indexing"
```

---

## Cross-Repo Dependencies

| From Repo | To Repo | Dependency | Status |
|-----------|---------|-----------|--------|
| aragon-app | Aragon-app-backend | Indexing API & proposal metadata | Active |
| aragon-app | AragonOSX | Contract ABIs & plugin addresses | Active |
| Aragon-app-backend | AragonOSX | Event schemas & contract interfaces | Active |
| All | GitIssue-Manager | Sprint sync & issue tracking | Active |

---

## Release Cadence

- **Sprint Duration:** 6 weeks (2026-01-21 to 2026-02-28)
- **Status Updates:** Bi-weekly (Tuesdays)
- **Release Candidate:** 2026-02-28 (all 3 repos at 100%)
- **Production Deployment:** 2026-03-07

---

## ProjectV2 Field Mapping

**Project:** mzfshark/projects/5 (HarmonyVoting E2E)

| GitHub ProjectV2 Field | PLAN.md Tag | Value | Type |
|------------------------|-------------|-------|------|
| Status | [status:...] | TODO / IN_PROGRESS / DONE | Select |
| Priority | [priority:...] | LOW / MEDIUM / HIGH | Select |
| Estimate | [estimate:...h] | Numeric hours | Number |
| Start Date | [start:YYYY-MM-DD] | Date | Date |
| End Date | [end:YYYY-MM-DD] | Date | Date |

**Limitation:** GitHub ProjectV2 does not support PARENT_ISSUE mutation via GraphQL. Workaround: Manual UI linking or UI automation (Playwright/Puppeteer).

---

## Audit Log

- **2026-01-21:** Initial production scope manifest created
- **2026-01-21:** SPRINT.md files updated (AragonOSX, aragon-app, Aragon-app-backend)
- **2026-01-21:** BUG.md files created (all 3 repos)
- **Next:** Sync commands execution (pending approval)
