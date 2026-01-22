# E2E Flow Implementation Guide

**Status:** Planning Phase - Ready for Development  
**Last Updated:** 2026-01-21  
**Implementation Target:** 2026-01-28  

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         E2E FLOW ARCHITECTURE                           │
└─────────────────────────────────────────────────────────────────────────┘

   CONFIG SETUP
   ├─ Load e2e-config.json
   ├─ Validate GitHub auth
   └─ Fetch ProjectV2 schema
        │
        ▼
   INTERACTIVE SELECTION
   ├─ Choose repository
   ├─ List available plans
   └─ Select plan(s) or "all"
        │
        ▼
   STAGE 1: SETUP
   ├─ Verify configuration
   ├─ Check GitHub access
   └─ Prepare output directories
        │
        ▼
   STAGE 2: PREPARE
   ├─ Parse PLAN.md + SPRINT.md
   ├─ Build task hierarchy
   └─ Extract metadata (assignee, labels, type, etc)
        │
        ▼
   STAGE 3: CREATE PAI
   ├─ Create parent issue with full metadata
   ├─ Add to ProjectV2
   └─ Store issue number for linking
        │
        ▼
   STAGE 4: CREATE CHILDREN
   ├─ Create all sub-issues in hierarchy order
   ├─ Assign metadata to each
   └─ Collect issue numbers for linking
        │
        ▼
   STAGE 5: LINK HIERARCHY
   ├─ Use gh issue link to create parent↔child relationships
   ├─ Build complete tree (parent→child→grandchild)
   └─ Validate all links created
        │
        ▼
   STAGE 6: SYNC PROJECTV2
   ├─ Fetch ProjectV2 schema (fields, options)
   ├─ For each issue:
   │  ├─ Set Status (if field exists)
   │  ├─ Set Priority (if field exists)
   │  ├─ Set Estimate Hours (if field exists)
   │  ├─ Set Start Date (if field exists)
   │  └─ Set End Date (if field exists)
   └─ Log all mutations
        │
        ▼
   STAGE 7: PROGRESS TRACKING (Optional)
   ├─ Generate nested checklist from hierarchy
   ├─ Calculate completion percentages
   └─ Append to PAI body
        │
        ▼
   STAGE 8: REPORTING
   ├─ Generate audit log (issues created, linked, synced)
   ├─ Validate execution quality
   └─ Compare against #431 standards
```

---

## User Journey

### Step 1: Setup Configuration
```bash
# Copy template to actual config
cp config/e2e-config.sample.json config/e2e-config.json

# Edit with actual project IDs and metadata
nano config/e2e-config.json
```

### Step 2: Start E2E Flow
```bash
# Interactive mode (prompts for selections)
pnpm e2e:interactive

# Or specify repo upfront
bash scripts/e2e-flow.sh --repo aragon-osx --plan PLAN.md
```

### Step 3: Monitor Execution
```
[2026-01-21 18:45:00] STAGE 1: SETUP - Configuration & Environment Validation
✅ Config file found: config/e2e-config.json
✅ GitHub CLI found
✅ GitHub authentication verified
✅ Output directory ready: tmp/e2e-execution

[2026-01-21 18:45:01] STAGE 2: PREPARE - Parse Hierarchy from Plans
ℹ️  Repository: aragon-osx
ℹ️  Plan: PLAN.md
ℹ️  Docs path: ./docs/plans
✅ Parsed 56 items from PLAN.md
✅ Parsed 84 items from SPRINT.md
✅ Built hierarchy with 3 levels (parent→child→grandchild)

[2026-01-21 18:45:05] STAGE 3: CREATE PAI - Generate Parent Issue
ℹ️  Creating parent issue: "[PLAN-001] AragonOSX: HarmonyVoting E2E"
✅ Created issue #373 (PAI)
✅ Added to ProjectV2

[2026-01-21 18:45:10] STAGE 4: CREATE CHILDREN - Generate Sub-Issues
ℹ️  Creating 140 sub-issues...
  ├─ Created #374 (Feature: Indexing Resilience)
  ├─ Created #375 (Task: Add reorg-safe handling)
  ├─ Created #376 (Task: Implement catch-up)
  ...
  └─ Created #513 (Last task)
✅ All 140 issues created

[2026-01-21 18:46:00] STAGE 5: LINK HIERARCHY - Create Relationships
ℹ️  Linking issues...
  ├─ Linked #374→#373 (parent→child)
  ├─ Linked #375→#374 (child→grandchild)
  ...
✅ All 140 relationships created

[2026-01-21 18:46:30] STAGE 6: SYNC PROJECTV2 - Set Project Fields
ℹ️  Fetching ProjectV2 schema...
ℹ️  Syncing metadata (140 issues)...
  ├─ #373: Status=In Progress ✓, Priority=HIGH ✓, Estimate=160h ✓
  ├─ #374: Status=TODO ✓, Priority=CRITICAL ✓, Estimate=40h ✓
  ...
✅ All metadata synced

[2026-01-21 18:47:00] STAGE 7: PROGRESS TRACKING - Generate Hierarchy Checklist
✅ Generated Progress Tracking (50/140 = 36%)
✅ Appended to PAI #373

[2026-01-21 18:47:05] STAGE 8: REPORTING - Generate Execution Report
✅ Report saved: tmp/e2e-execution/e2e-execution-report.json
✅ Summary: 141 issues (1 PAI + 140 children), 100% linked, 100% synced

╔════════════════════════════════════════════════════════════════╗
║  ✅ E2E FLOW COMPLETED SUCCESSFULLY                             ║
╚════════════════════════════════════════════════════════════════╝
```

### Step 4: Verify Results
```bash
# Check PAI on GitHub
gh issue view 373 --repo Axodus/AragonOSX

# View report
cat tmp/e2e-execution/e2e-execution-report.md
```

---

## Implementation Checklist

### Phase 1: Infrastructure (Week 1)
- [ ] **e2e-config.json** structure finalized
- [ ] **e2e-flow.sh** skeleton with all 8 stages
- [ ] **Package.json** scripts added (`pnpm e2e`, `pnpm e2e:interactive`)
- [ ] **PLAN_E2E_FLOW.md** documentation complete

### Phase 2: Core Implementation (Week 2)
- [ ] STAGE 1 (Setup): Config validation, auth check, dir creation
- [ ] STAGE 2 (Prepare): Parse .md, build hierarchy, extract metadata
- [ ] STAGE 3 (Create PAI): Generate parent issue, add to ProjectV2
- [ ] STAGE 4 (Create Children): Generate all sub-issues with metadata

### Phase 3: Linking & Sync (Week 3)
- [ ] STAGE 5 (Link Hierarchy): Use `gh issue link`, validate relationships
- [ ] STAGE 6 (Sync ProjectV2): Query schema, mutate fields, handle errors
- [ ] Error handling & retry logic for all API calls

### Phase 4: Enhancement & Testing (Week 4)
- [ ] STAGE 7 (Progress Tracking): Generate hierarchy checklist
- [ ] STAGE 8 (Reporting): Audit log, quality validation, #431 comparison
- [ ] Interactive CLI prompts for repo/plan selection
- [ ] E2E testing with all 3 repositories
- [ ] Rollback procedures (optional)

---

## Data Flow

### Input
```
docs/plans/PLAN.md       ┐
docs/plans/SPRINT.md     ├─> Stage 2 (Prepare) ──> Hierarchy JSON
docs/plans/TASK.md       ┘

e2e-config.json          ──> Stage 1 (Setup) ──> Validated Config
```

### Processing
```
Validated Config + Hierarchy
    │
    ├─> Stage 3: Create PAI ──> Issue #373 (PAI)
    │
    ├─> Stage 4: Create Children ──> Issues #374-#513
    │
    ├─> Stage 5: Link Hierarchy ──> Relationships file
    │
    └─> Stage 6: Sync ProjectV2 ──> Mutations log
```

### Output
```
tmp/e2e-execution/
├─ preparation-state.json        (hierarchy + metadata)
├─ parent-issue.json             (PAI info)
├─ all-issues.json               (flat list of created issues)
├─ hierarchy-links.json          (parent→child relationships)
├─ project-sync.json             (ProjectV2 mutations)
├─ progress-tracking.md          (checklist)
├─ e2e-execution-report.json     (structured audit log)
└─ e2e-execution-report.md       (human-readable summary)
```

---

## Error Handling

### Front-Running Prevention
```javascript
// ❌ OLD (front-running):
1. Create PAI
2. (Immediately) Link children
3. (Immediately) Sync ProjectV2
   // Problem: If step 2 fails, step 3 still runs

// ✅ NEW (sequential + validated):
1. Create PAI ──> Verify in GitHub ──> Store ID
2. Create Children ──> Verify all created ──> Store IDs
3. Link Children ──> Verify all linked ──> Log results
4. Sync ProjectV2 ──> Verify mutations ──> Log results
```

### Retry & Backoff
```bash
# For each stage:
- Attempt 1: immediate
- Attempt 2: after 1s (exponential backoff)
- Attempt 3: after 2s
- Fail: Log error + save state for manual review
```

### Rollback Safety
```bash
# Store all issue numbers before any operations
# If failure occurs:
1. Log which issues were created
2. Provide manual deletion script
3. Document what needs manual cleanup
```

---

## Quality Validation (Reference #431)

### Checklist Against Issue #431
- [ ] Issue created with full title context
- [ ] Description includes PLAN.md content
- [ ] Type set to EPIC (if supported)
- [ ] Assignee set to owner
- [ ] Labels applied
- [ ] Added to ProjectV2 immediately
- [ ] All sub-issues created in correct order
- [ ] All sub-issues have metadata (type, assignee, labels)
- [ ] All relationships created (parent↔child↔grandchild)
- [ ] ProjectV2 fields synchronized (Status, Priority, Estimate, Dates)
- [ ] No manual fixes needed
- [ ] Audit trail complete

---

## Testing Strategy

### Unit Tests (Per Stage)
```bash
# Test config validation
pnpm test:stage setup

# Test parsing logic
pnpm test:stage prepare

# Test issue creation (dry-run)
pnpm test:stage create --dry-run
```

### Integration Tests (Full Flow)
```bash
# Test with AragonOSX (smallest)
bash scripts/e2e-flow.sh --repo aragon-app --dry-run

# Test with all 3 repos
bash scripts/e2e-flow.sh --all --dry-run
```

### Manual Validation
```bash
# Compare against #431
gh issue view 431 --repo Axodus/AragonOSX --json body
# Check: title, description, metadata, sub-issues, ProjectV2 fields
```

---

## CLI Commands Reference

```bash
# Interactive flow with prompts
pnpm e2e:interactive

# Specific repository
bash scripts/e2e-flow.sh --repo aragon-osx

# Specific plan
bash scripts/e2e-flow.sh --repo aragon-osx --plan SPRINT.md

# Dry-run (no actual mutations)
bash scripts/e2e-flow.sh --repo aragon-osx --dry-run

# From checkpoint
bash scripts/e2e-flow.sh --resume --from-stage 5

# Help
bash scripts/e2e-flow.sh --help
```

---

## Success Metrics

After implementation, validate:
1. ✅ Zero front-running issues
2. ✅ All issues created correctly (141 = 1 PAI + 140 children)
3. ✅ 100% of relationships linked
4. ✅ 100% of ProjectV2 fields synced (if supported)
5. ✅ Audit trail complete (no missing data)
6. ✅ Can be run multiple times without duplicates
7. ✅ All 3 repos processed successfully
8. ✅ Zero manual fix-ups needed

---

## References

- **Issue #431:** https://github.com/Axodus/AragonOSX/issues/431 (quality reference)
- **Config Template:** `config/e2e-config.sample.json`
- **Flow Script:** `scripts/e2e-flow.sh`
- **Plan Document:** `PLAN_E2E_FLOW.md`

---

## Notes

- This document serves as the implementation blueprint
- The E2E flow eliminates all front-running issues from the previous pipeline
- Each stage validates before proceeding to the next
- Full audit trail is maintained for compliance and debugging
- Compatible with ProjectV2 schema constraints (e.g., no PARENT_ISSUE support)
