# EXECUTION CHECKLIST: Ready-to-Execute Pipeline

**Purpose:** Step-by-step checklist for executing the 6-stage sync pipeline  
**Estimated Time:** 4-6 hours (mostly manual UI work)  
**Status:** ✅ Ready to Start  
**Last Updated:** 2026-01-21

---

## Pre-Execution Setup (10 minutes)

### Prerequisites
- [ ] GitHub CLI installed (`gh --version`)
- [ ] Authenticated with GitHub (`gh auth status`)
- [ ] All 21 markdown files exist in workspace
- [ ] GitIssue-Manager cloned locally
- [ ] Node.js v16+ installed

### Verify Setup
```bash
# Test GitHub auth
gh auth status
# Expected: Logged in to github.com as mzfshark
# Scopes should include: repo, project, org

# Verify repos accessible
gh api repos/Axodus/AragonOSX --jq '.name'
gh api repos/Axodus/aragon-app --jq '.name'
gh api repos/Axodus/Aragon-app-backend --jq '.name'
# Expected: All return repo names without errors

# Verify project exists
gh project view 23 --owner Axodus
# Expected: Shows "DEV Dashboard" project
```

---

## STAGE 1: SETUP (15 minutes)

**Objective:** Initialize GitIssue-Manager and validate GitHub access

### 1.1 Load ProjectV2 Schema
- [ ] Run schema loader:
```bash
cd /mnt/d/Rede/Github/mzfshark/GitIssue-Manager
node scripts/register_project_fields.js \
  --owner Axodus \
  --number 23 \
  --out tmp/axodus-project-23-schema.json
```

**Expected Output:**
```
✅ Loaded 14 fields from Axodus/23 (DEV Dashboard)
- Title (TITLE)
- Assignees (ASSIGNEES)
- Status (SINGLE_SELECT)
- Priority (SINGLE_SELECT)
- Estimate hours (NUMBER)
- Start task (DATE)
- End Task (DATE)
... [7 more fields]

✅ Schema saved to: tmp/axodus-project-23-schema.json
```

- [ ] Verify output file created
```bash
cat tmp/axodus-project-23-schema.json | jq '.fields | length'
# Expected: 14
```

### 1.2 Create config.json
- [ ] Copy template:
```bash
cat > config.json << 'EOF'
{
  "organization": "Axodus",
  "projectNumber": 23,
  "projectId": "PVT_kwDOBfRHZM4BM-PB",
  "repositories": [
    {
      "name": "AragonOSX",
      "owner": "Axodus",
      "branch": "develop",
      "planFiles": ["PLAN.md", "BUG.md", "FEATURE.md", "SPRINT.md", "ROADMAP.md"],
      "defaultLabels": ["repo:AragonOSX"]
    },
    {
      "name": "aragon-app",
      "owner": "Axodus",
      "branch": "main",
      "planFiles": ["PLAN.md", "BUG.md", "FEATURE.md"],
      "defaultLabels": ["repo:aragon-app"]
    },
    {
      "name": "Aragon-app-backend",
      "owner": "Axodus",
      "branch": "development",
      "planFiles": ["PLAN.md", "BUG.md", "FEATURE.md"],
      "defaultLabels": ["repo:Aragon-app-backend"]
    }
  ],
  "projectFields": {
    "status": "Status",
    "priority": "Priority",
    "estimate": "Estimate hours",
    "startDate": "Start task",
    "endDate": "End Task"
  }
}
EOF
```

- [ ] Verify config created:
```bash
cat config.json | jq '.repositories | length'
# Expected: 3
```

### ✅ Stage 1 Complete
- [ ] Schema loaded ✅
- [ ] config.json created ✅
- [ ] All repos accessible ✅

**Time Elapsed:** ~15 minutes

---

## STAGE 2: PREPARE (30 minutes)

**Objective:** Parse markdown files and generate engine-input.json

### 2.1 Prepare Engine Input
- [ ] Run prepare script:
```bash
npm run prepare -- \
  --config config.json \
  --output tmp/engine-input.json \
  --repos AragonOSX,aragon-app,Aragon-app-backend 2>&1 | tee tmp/prepare.log
```

**Expected Output:**
```
✅ Parsing AragonOSX/PLAN.md (8 items)
✅ Parsing AragonOSX/BUG.md (3 items)
✅ Parsing AragonOSX/FEATURE.md (2 items)
✅ Parsing aragon-app/PLAN.md (5 items)
✅ Parsing aragon-app/BUG.md (2 items)
...

✅ Generated engine-input.json with 45 total items
✅ Metadata coverage:
   - estimate: 20 items
   - startDate: 12 items
   - endDate: 12 items
   - status: 40 items
   - priority: 45 items
```

- [ ] Verify engine-input.json:
```bash
cat tmp/engine-input.json | jq '.metadata'
# Expected: totalItems: 45 (or similar count)

cat tmp/engine-input.json | jq '.repositories | length'
# Expected: 3
```

### 2.2 Validate Schema
- [ ] Run validation:
```bash
npm run validate -- \
  --schema schemas/engine-input.schema.json \
  --input tmp/engine-input.json
```

**Expected Output:**
```
✅ Validation passed
✅ All 45 items match schema
✅ No errors, 0 warnings
```

- [ ] If validation fails:
  - Review errors in `tmp/prepare.log`
  - Check markdown syntax in source files
  - Re-run prepare after fixes

### ✅ Stage 2 Complete
- [ ] engine-input.json generated ✅
- [ ] Schema validation passed ✅
- [ ] All 45 items ready for creation ✅

**Time Elapsed:** ~45 minutes total

---

## STAGE 3: CREATE ISSUES & MANUAL UI ORGANIZATION (2-3 hours)

**Objective:** Create parent issues, then manually organize child issues in GitHub UI

### 3.1 Dry Run (5 minutes)
- [ ] Test issue creation without committing:
```bash
npm run create:parents -- \
  --input tmp/engine-input.json \
  --owner Axodus \
  --dry-run 2>&1 | tee tmp/create-dry-run.log
```

**Expected Output:**
```
[DRY RUN] gh issue create -R Axodus/AragonOSX --title "[AragonOSX | #PLAN-001]: ..." --body "..." --label "repo:AragonOSX" ...
[DRY RUN] gh issue create -R Axodus/aragon-app --title "[aragon-app | #PLAN-002]: ..." ...
[DRY RUN] gh issue create -R Axodus/Aragon-app-backend --title "[Aragon-app-backend | #PLAN-003]: ..." ...
...

[DRY RUN] Total issues to create: 19 (parent-level only)
[DRY RUN] No actual GitHub changes. Ready to execute.
```

- [ ] Review output in `tmp/create-dry-run.log`
- [ ] Check issue titles look correct

### 3.2 Create Parent Issues (10 minutes)
- [ ] Execute issue creation:
```bash
npm run create:parents -- \
  --input tmp/engine-input.json \
  --owner Axodus \
  --output tmp/creation-log.json 2>&1 | tee tmp/create-execute.log
```

**Expected Output:**
```
Creating issues in Axodus/AragonOSX...
✅ Created #42: [AragonOSX | #PLAN-001]: HarmonyVoting E2E Production Rollout
✅ Created #51: [AragonOSX | #BUG-001]: RPC timeout on reorg recovery
✅ Created #52: [AragonOSX | #FEATURE-001]: ...

Creating issues in Axodus/aragon-app...
✅ Created #162: [aragon-app | #PLAN-002]: Governance UI Resilience
...

Creating issues in Axodus/Aragon-app-backend...
✅ Created #1: [Aragon-app-backend | #PLAN-003]: Event Indexing Pipeline
...

✅ Created 19 parent issues
✅ Log saved to tmp/creation-log.json
```

- [ ] Verify creation log:
```bash
cat tmp/creation-log.json | jq '.created | length'
# Expected: 19 (or your total parent count)
```

### 3.3 Open GitHub and Organize Sub-Issues (2+ hours)

⚠️ **MANUAL UI WORK - CANNOT BE AUTOMATED**

#### Step 3.3.1: Create First Parent's Sub-Issues
- [ ] Open: https://github.com/Axodus/AragonOSX/issues/42
  - (Replace 42 with actual issue number from creation-log.json)

- [ ] For each child item in PLAN.md:
  1. Click "Create linked issue" or "Add sub-issue"
  2. Enter title: `[AragonOSX | #PLAN-001-SUB-001]: Indexing Resilience`
  3. Enter body: (from PLAN.md)
  4. Add labels: (from PLAN.md metadata)
  5. Click "Create"

**Expected:**
```
Parent Issue #42: HarmonyVoting E2E Production Rollout
├─ Sub-issue #43: Indexing Resilience
├─ Sub-issue #XX: Plugin Uninstall
├─ Sub-issue #XX: Metadata Redundancy
└─ Sub-issue #XX: Native-Token Voting Support
```

#### Step 3.3.2: For Each Parent Sub-Issue, Create Grandchildren
Example: Parent #42 → Sub #43 (Indexing Resilience) → Grandchildren:
- [ ] Open issue #43
- [ ] Create sub-issues:
  - `Ensure backend handlers cover HarmonyVoting events`
  - `Enable historical indexing for HarmonyVoting events`
  - `Add reorg-safe handling`
  - `Implement catch-up strategy`
  - etc.

#### Step 3.3.3: Repeat for All Repositories
- [ ] **AragonOSX:** 
  - [ ] PLAN parent + 4 children + 10+ grandchildren
  - [ ] BUG parent + 3 children
  - [ ] FEATURE parent + 2 children
  
- [ ] **aragon-app:**
  - [ ] PLAN parent + 3 children + 5+ grandchildren
  - [ ] BUG parent + 2 children
  
- [ ] **Aragon-app-backend:**
  - [ ] PLAN parent + 3 children + 6+ grandchildren
  - [ ] BUG parent + 1 child
  - [ ] FEATURE parent + 1 child

#### Checklist for Manual Org:
```
AragonOSX
  PLAN (#42)
    ├─ [ ] Indexing Resilience (#43)
    │   ├─ [ ] Task 1
    │   ├─ [ ] Task 2
    │   └─ [ ] Task 3+
    ├─ [ ] Plugin Uninstall
    ├─ [ ] Metadata Redundancy
    └─ [ ] Native-Token Voting Support
  
  BUG (#51)
    ├─ [ ] RPC timeout issue
    ├─ [ ] Reorg bug
    └─ [ ] Other issues
  
  FEATURE (#52)
    ├─ [ ] Feature 1
    └─ [ ] Feature 2

aragon-app
  PLAN (#162)
    ├─ [ ] Governance UI
    ├─ [ ] Plugin Management
    └─ [ ] Error Handling
  
  BUG (#XX)
    ├─ [ ] Bug 1
    └─ [ ] Bug 2

Aragon-app-backend
  PLAN (#1)
    ├─ [ ] Event Indexing
    ├─ [ ] Rate Limiting
    └─ [ ] Monitoring
  
  BUG (#XX)
    └─ [ ] Bug 1
  
  FEATURE (#XX)
    └─ [ ] Feature 1
```

### ✅ Stage 3 Complete
- [ ] All parent issues created ✅
- [ ] All sub-issues created and linked ✅
- [ ] All grandchildren organized ✅
- [ ] GitHub UI structure matches PLAN.md ✅

**Time Elapsed:** ~2.5-3 hours (mostly UI work)

---

## STAGE 4: FETCH (15 minutes)

**Objective:** Query GitHub to validate structure and build mapping

### 4.1 Fetch Project Data
- [ ] Run fetch:
```bash
npm run fetch -- \
  --owner Axodus \
  --number 23 \
  --output tmp/github-project-data.json 2>&1 | tee tmp/fetch.log
```

**Expected Output:**
```
✅ Fetching Axodus/23 (DEV Dashboard)...
✅ Loaded 19 items
✅ Loaded sub-issue relationships
✅ Project data saved to tmp/github-project-data.json

Summary:
- Parent issues: 7
- Sub-issues: 16
- Grandchild issues: 24
```

- [ ] Verify data:
```bash
cat tmp/github-project-data.json | jq '.issues | length'
# Expected: 19 (or total count from creation-log)
```

### 4.2 Build Mapping
- [ ] Create mapping file:
```bash
npm run build:mapping -- \
  --engine-input tmp/engine-input.json \
  --github-data tmp/github-project-data.json \
  --output tmp/mapping.json 2>&1 | tee tmp/mapping.log
```

**Expected Output:**
```
✅ Matching engine items to GitHub issues...
✅ Matched 19/19 items (100%)
✅ Mapping saved to tmp/mapping.json

Mapping summary:
- AragonOSX: 8 items
- aragon-app: 5 items
- Aragon-app-backend: 6 items
```

- [ ] Verify mapping:
```bash
cat tmp/mapping.json | jq '.mappings | length'
# Expected: 19

# Check first mapping
cat tmp/mapping.json | jq '.mappings[0]'
# Should show: mdId, mdTitle, gitHubIssueNumber, gitHubUrl, etc
```

### 4.3 Validate Mapping
- [ ] Run validation:
```bash
npm run validate:mapping -- \
  --mapping tmp/mapping.json \
  --expected-count 19
```

**Expected Output:**
```
✅ Validation passed
✅ All 19 items mapped successfully
✅ No orphaned items
✅ No duplicate mappings
```

### ✅ Stage 4 Complete
- [ ] GitHub data fetched ✅
- [ ] Mapping created (markdown ↔ GitHub) ✅
- [ ] Mapping validated ✅

**Time Elapsed:** ~60 minutes total

---

## STAGE 5: APPLY METADATA (20 minutes)

**Objective:** Apply estimate, dates, status, priority to all issues

### 5.1 Build Metadata Updates
- [ ] Generate update payloads:
```bash
npm run build:metadata-updates -- \
  --mapping tmp/mapping.json \
  --engine-input tmp/engine-input.json \
  --output tmp/metadata-updates.json 2>&1 | tee tmp/build-updates.log
```

**Expected Output:**
```
✅ Building metadata updates...
✅ Generated 19 mutations
✅ Coverage:
   - Status: 19/19 (100%)
   - Priority: 19/19 (100%)
   - Estimate: 12/19 (63%)
   - Start Date: 11/19 (58%)
   - End Date: 11/19 (58%)

✅ Metadata updates saved to tmp/metadata-updates.json
```

- [ ] Verify updates file:
```bash
cat tmp/metadata-updates.json | jq '.updates | length'
# Expected: 19

# Check first update
cat tmp/metadata-updates.json | jq '.updates[0].fields'
# Should show field mutations
```

### 5.2 Dry Run (5 minutes)
- [ ] Test without committing:
```bash
npm run apply:metadata -- \
  --updates tmp/metadata-updates.json \
  --dry-run 2>&1 | tee tmp/apply-dry-run.log
```

**Expected Output:**
```
[DRY RUN] Applying metadata to 19 issues...
[DRY RUN] Issue #42: Update Status → "In Progress", Priority → "High", Estimate → 160h
[DRY RUN] Issue #43: Update Status → "In Progress", Priority → "High", Estimate → 42h
...
[DRY RUN] Would update 19 issues
[DRY RUN] No GitHub changes. Ready to execute.
```

### 5.3 Apply Metadata
- [ ] Execute updates:
```bash
npm run apply:metadata -- \
  --updates tmp/metadata-updates.json \
  --output tmp/metadata-apply-log.json 2>&1 | tee tmp/apply-execute.log
```

**Expected Output:**
```
Applying metadata...
✅ Issue #42: Updated (Status, Priority, Estimate)
✅ Issue #43: Updated (Status, Priority, Estimate, Start, End)
✅ Issue #51: Updated (Status, Priority)
...

✅ Applied: 19
✅ Skipped: 0
✅ Errors: 0

✅ Log saved to tmp/metadata-apply-log.json
```

- [ ] Verify in GitHub:
```bash
# Open ProjectV2 and check fields are populated
open "https://github.com/users/mzfshark/projects/5"

# Verify:
# - Status column shows values
# - Priority column shows values  
# - Estimate hours column shows numbers
# - Start/End dates appear for sprints
```

### ✅ Stage 5 Complete
- [ ] Metadata updates generated ✅
- [ ] Dry run verified ✅
- [ ] Metadata applied to all issues ✅
- [ ] GitHub ProjectV2 fields populated ✅

**Time Elapsed:** ~80 minutes total

---

## STAGE 6: REPORTS (10 minutes)

**Objective:** Generate sync reports and validation summaries

### 6.1 Generate Sync Report
- [ ] Create report:
```bash
npm run reports -- \
  --creation-log tmp/creation-log.json \
  --mapping tmp/mapping.json \
  --metadata-log tmp/metadata-apply-log.json \
  --output tmp/sync-report.json 2>&1 | tee tmp/report.log
```

**Expected Output:**
```
✅ Generating sync report...
✅ Report saved to tmp/sync-report.json

Summary:
- Total issues created: 19
- Total issues mapped: 19
- Total metadata applied: 19
- Errors: 0
- Warnings: 0

Field coverage:
- Status: 19/19 (100%)
- Priority: 19/19 (100%)
- Estimate: 12/19 (63%)
- Start Date: 11/19 (58%)
- End Date: 11/19 (58%)
```

- [ ] View report:
```bash
cat tmp/sync-report.json | jq '.'
```

### 6.2 Generate Markdown Summary
- [ ] Create readable summary:
```bash
npm run reports:markdown -- \
  --report tmp/sync-report.json \
  --output SYNC_REPORT.md
```

**Expected Output:**
```markdown
# Synchronization Report: Multi-Repo Planning → GitHub ProjectV2

**Execution Date:** 2026-01-21 16:30:00 UTC
**Organization:** Axodus
**Project:** DEV Dashboard (#23)

## Summary

✅ **All operations completed successfully**

| Repository | Issues Created | Mapped | Metadata Applied | Status |
|---|---|---|---|---|
| AragonOSX | 8 | 8 | 8 | ✅ |
| aragon-app | 5 | 5 | 5 | ✅ |
| Aragon-app-backend | 6 | 6 | 6 | ✅ |
| **TOTAL** | **19** | **19** | **19** | **✅** |

...
```

- [ ] Review markdown report:
```bash
cat SYNC_REPORT.md
```

### 6.3 Health Check
- [ ] Run project health check:
```bash
npm run health-check -- \
  --owner Axodus \
  --number 23 2>&1 | tee tmp/health-check.log
```

**Expected Output:**
```
ProjectV2 Health Check: Axodus/DEV Dashboard (#23)
═══════════════════════════════════════════════════

✅ Project accessible: Yes
✅ Fields loaded: 14 fields
✅ Issues in project: 19 items
✅ Sub-issues linked: 16/19 (84%)
✅ Metadata coverage:
   ✅ Status: 19/19 (100%)
   ✅ Priority: 19/19 (100%)
   ✅ Estimate: 12/19 (63%)
   ✅ Start Date: 11/19 (58%)
   ✅ End Date: 11/19 (58%)

🟡 Warnings:
   - 7 issues missing estimate (expected for epic-level items)

✅ ProjectV2 is healthy
```

### 6.4 Generate Bidirectional Sync Config
- [ ] Create sync configuration:
```bash
npm run generate:sync-config -- \
  --mapping tmp/mapping.json \
  --output .gitissue/sync-config.json
```

**Expected Output:**
```
✅ Sync config generated
✅ Saved to .gitissue/sync-config.json

This config enables future syncs:
- Update PLAN.md → pull latest from GitHub
- Push PLAN.md changes → update GitHub issues
- Keep markdown ↔ GitHub in sync
```

### ✅ Stage 6 Complete
- [ ] Sync report generated ✅
- [ ] Markdown summary created ✅
- [ ] Health check passed ✅
- [ ] Sync config created ✅

**Time Elapsed:** ~90 minutes total

---

## POST-EXECUTION VALIDATION (10 minutes)

### Verify All Systems
- [ ] Open ProjectV2:
```bash
open "https://github.com/users/mzfshark/projects/5"
```

**Checklist:**
- [ ] All 19 issues appear in project board
- [ ] Issues grouped by repository (labels)
- [ ] Status field populated (In Progress, Todo, Done)
- [ ] Priority field populated (High, Medium, Low)
- [ ] Estimate hours showing for sprint items
- [ ] Start/End dates populated
- [ ] Sub-issue relationships visible

### Spot Check Issues
- [ ] Click on parent issue (#42):
  - [ ] Title correct: `[AragonOSX | #PLAN-001]: HarmonyVoting E2E...`
  - [ ] Body contains full PLAN.md content
  - [ ] Labels applied (repo:AragonOSX, type:plan, area:contracts, etc)
  - [ ] Sub-issues linked in ProjectV2

- [ ] Click on sub-issue (#43):
  - [ ] Parent relationship shown
  - [ ] Metadata fields populated
  - [ ] Status = "In Progress"
  - [ ] Priority = "High"

### View Markdown Summary
- [ ] Review final report:
```bash
cat SYNC_REPORT.md
```

**Expected contains:**
- ✅ Execution date & organization
- ✅ Total issues created: 19
- ✅ Total mapped: 19
- ✅ Total metadata applied: 19
- ✅ Zero errors
- ✅ Field coverage stats
- ✅ By-repository breakdown

---

## FINAL CHECKLIST: EXECUTION COMPLETE ✅

### All Stages Done
- [x] STAGE 1: SETUP ✅ (Schema loaded, config created)
- [x] STAGE 2: PREPARE ✅ (engine-input.json generated, 45 items)
- [x] STAGE 3: CREATE + ORGANIZE ✅ (19 parent + 45 child/grandchild issues, manually organized)
- [x] STAGE 4: FETCH ✅ (GitHub data fetched, mapping created)
- [x] STAGE 5: APPLY METADATA ✅ (All fields populated)
- [x] STAGE 6: REPORTS ✅ (Sync report generated, health check passed)

### Outputs Generated
- [x] config.json
- [x] tmp/axodus-project-23-schema.json
- [x] tmp/engine-input.json
- [x] tmp/creation-log.json
- [x] tmp/github-project-data.json
- [x] tmp/mapping.json
- [x] tmp/metadata-updates.json
- [x] tmp/metadata-apply-log.json
- [x] tmp/sync-report.json
- [x] SYNC_REPORT.md
- [x] .gitissue/sync-config.json

### Ready for Next Phase
- [x] GitHub ProjectV2 fully populated with 19 issues
- [x] All metadata fields applied (status, priority, estimate, dates)
- [x] Sub-issue hierarchy established
- [x] Bidirectional sync config ready (for future updates)

---

## Time Summary

| Stage | Time | Notes |
|---|---|---|
| 1: Setup | 15 min | Schema + config |
| 2: Prepare | 30 min | Parse markdown |
| 3: Create + Organize | 2-3 hours | **Manual UI work** |
| 4: Fetch | 15 min | Query GitHub |
| 5: Apply Metadata | 20 min | Update fields |
| 6: Reports | 10 min | Generate summary |
| **TOTAL** | **~4-5 hours** | **Mostly manual UI work** |

---

## What's Next?

### Immediate (Today)
1. ✅ Share SYNC_REPORT.md with team
2. ✅ Review ProjectV2 board: https://github.com/users/mzfshark/projects/5
3. ✅ Start tracking work on issues

### Near-term (This Week)
1. ✅ Update issue status as work progresses
2. ✅ Log hours against Estimate
3. ✅ Review metadata accuracy

### Future (Ongoing)
1. When PLAN.md changes → Re-run STAGE 2-6 to sync
2. When GitHub issues change → Run sync in reverse (GitHub → markdown)
3. Use `.gitissue/sync-config.json` for automated syncs (future enhancement)

---

**Document Version:** 1.0  
**Status:** Ready to Execute  
**Last Updated:** 2026-01-21

---

## Questions or Issues?

If stuck at any stage:
1. Check logs in `tmp/` directory
2. Review error messages in `.log` files
3. Refer to EXECUTION_FLOW.md for technical details
4. Check EXECUTOR_ARCHITECTURE.md for implementation details
