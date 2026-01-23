# E2E Flow Plan: Complete Issue Hierarchy Generation & ProjectV2 Sync

**Status:** Planning Phase  
**Target Release:** 2026-01-28  
**Owner:** mzfshark  

---

## Executive Summary

Implement a complete **E2E (End-to-End) flow** for generating issue hierarchies with full ProjectV2 metadata synchronization, eliminating front-running of dependent stages.

**Reference Issue:** https://github.com/Axodus/AragonOSX/issues/431

---

## Desired User Flow

### Phase 1: Configuration & Selection
```
1. Load e2e-config.json (API keys, org, projects, defaults)
2. Choose repository (Axodus/AragonOSX, Axodus/aragon-app, etc.)
3. List available plans (.md files in docs/plans/)
4. Select plan(s) to process (or "all")
```

### Phase 2: Parent Issue Creation
```
5. Create Issue PAI (Parent Epic) with:
   - Title: "[PLAN-###] {repo}: {plan-title}"
   - Description: PLAN.md content (from ./docs/plans/PLAN.md)
   - Type: EPIC (if repo supports)
   - Assignee: {owner} (from config)
   - Labels: ["plan", "epic"] (from config)
   - Add to ProjectV2: {project-id} (from config)
6. Store Issue PAI ID for next phases
```

### Phase 3: Sub-Issues Generation
```
7. Parse task hierarchy from PLAN.md + SPRINT.md
8. Create sub-issues in order (no re-ordering):
   - Title: "[{type}] {task-title}"
   - Description: {task-description}
   - Type: task|feature|bug|hotfix (from content or config)
   - Assignee: {task-assignee} or {default-owner}
   - Labels: {task-labels}
   - Priority: {task-priority} (if available)
   - Estimate: {task-estimate} (if available)
9. Collect issue IDs in hierarchy map
```

### Phase 4: Hierarchy Linking
```
10. Link issues using `gh issue link`:
    - parent_id -> child_id relationships
    - Build complete parent↔child↔grandchild tree
11. Validate all links created successfully
```

### Phase 5: ProjectV2 Metadata Sync
```
12. Fetch ProjectV2 schema for org (fields, options)
13. For each issue (PAI + children):
    - Set Status (if field exists)
    - Set Priority (if field exists)
    - Set Estimate Hours (if field exists)
    - Set Start Date (if field exists)
    - Set End Date (if field exists)
14. Log all mutations (success/failure)
```

### Phase 6: Reporting & Validation
```
15. Generate audit log:
    - Issues created: [#373, #374, #375, ...]
    - Issues linked: [373→374, 373→375, ...]
    - ProjectV2 updates: [373: status=DONE, ...]
16. Generate summary report with stats
```

---

## Stages Breakdown

### STAGE 1: SETUP
- [ ] Validate config file exists (e2e-config.json)
- [ ] Check GitHub auth (gh auth status)
- [ ] Fetch org info + ProjectV2 schema
- [ ] Verify repositories accessible

**Output:** `config.validated.json`

### STAGE 2: PREPARE
- [ ] Scan docs/plans/ directory
- [ ] Parse PLAN.md + SPRINT.md
- [ ] Build task hierarchy (parent→child→grandchild)
- [ ] Extract metadata (assignee, labels, type, estimate, dates)

**Output:** `preparation-state.json` (hierarchy + metadata)

### STAGE 3: CREATE PAI (Parent Issue)
- [ ] Create Issue PAI with full metadata
- [ ] Add to ProjectV2 immediately
- [ ] Record PAI issue number

**Output:** `parent-issue.json` (number, nodeId, url)

### STAGE 4: CREATE CHILDREN
- [ ] For each task in hierarchy:
  - Create issue with metadata
  - Record issue number + hierarchy level
  - Store in hierarchy map

**Output:** `all-issues.json` (flat list of created issues)

### STAGE 5: LINK HIERARCHY
- [ ] Use `gh issue link` to create parent↔child relationships
- [ ] Validate all links created
- [ ] Store link map

**Output:** `hierarchy-links.json` (parent→children relationships)

### STAGE 6: SYNC PROJECTV2
- [ ] Query ProjectV2 schema for all field types
- [ ] For each issue, set:
  - Status (if Status field exists)
  - Priority (if Priority field exists)
  - Estimate Hours (if custom field exists)
  - Start Date (if custom field exists)
  - End Date (if custom field exists)
- [ ] Handle unsupported fields gracefully

**Output:** `project-sync.json` (mutations log)

### STAGE 7: PROGRESS TRACKING (Optional Enhancement)
- [ ] Generate Progress Tracking section
- [ ] Append to PAI body
- [ ] Update hierarchy-aware checklist

**Output:** `progress-tracking.md`

### STAGE 8: REPORTING
- [ ] Aggregate all stage outputs
- [ ] Generate human-readable report
- [ ] Provide rollback instructions

**Output:** `e2e-execution-report.json` + `e2e-execution-report.md`

---

## Configuration Structure (e2e-config.json)

```json
{
  "github": {
    "owner": "Axodus",
    "token": "$(gh auth token)"  // injected at runtime
  },
  "repositories": [
    {
      "name": "AragonOSX",
      "owner": "Axodus",
      "fullName": "Axodus/AragonOSX",
      "docsPath": "./docs/plans",
      "defaultOwner": "mzfshark",
      "project": {
        "id": "PVT_kwDOBfRHZM4BM-PB",
        "number": 23,
        "name": "Aragon OSx Sprint 1"
      },
      "defaultLabels": ["plan", "harmony"],
      "defaultType": "EPIC",
      "defaultPriority": "HIGH",
      "enabled": true
    },
    {
      "name": "aragon-app",
      "owner": "Axodus",
      "fullName": "Axodus/aragon-app",
      "docsPath": "./docs/plans",
      "defaultOwner": "mzfshark",
      "project": {
        "id": "PVT_kwDOBfRHZM4BM-PC",
        "number": 24,
        "name": "Frontend Sprint 1"
      },
      "defaultLabels": ["plan", "harmony"],
      "defaultType": "EPIC",
      "defaultPriority": "HIGH",
      "enabled": true
    }
  ],
  "projectV2": {
    "fieldMappings": {
      "status": "Status",
      "priority": "Priority",
      "estimateHours": "Estimate Hours",
      "startDate": "Start Date",
      "endDate": "End Date"
    }
  },
  "execution": {
    "maxConcurrentRequests": 3,
    "retryAttempts": 3,
    "retryDelayMs": 1000,
    "stages": [1, 2, 3, 4, 5, 6, 7, 8]
  }
}
```

---

## Data Models

### Preparation State
```json
{
  "repository": "Axodus/AragonOSX",
  "selectedPlan": "PLAN.md",
  "hierarchy": {
    "pai": {
      "title": "AragonOSX: HarmonyVoting E2E",
      "description": "...",
      "type": "EPIC",
      "assignee": "mzfshark",
      "labels": ["plan"],
      "priority": "HIGH",
      "estimateHours": 160,
      "startDate": "2026-01-21",
      "endDate": "2026-02-28"
    },
    "children": [
      {
        "id": "item-001",
        "parentId": "pai",
        "level": 1,
        "title": "Indexing Resilience",
        "description": "...",
        "type": "FEATURE",
        "assignee": "backend-owner",
        "labels": ["feature", "backend"],
        "priority": "CRITICAL",
        "estimateHours": 40,
        "children": [
          {
            "id": "item-001-001",
            "parentId": "item-001",
            "level": 2,
            "title": "Add reorg-safe handling",
            "description": "...",
            "type": "TASK",
            "assignee": "backend-owner",
            "labels": ["task", "backend"],
            "priority": "HIGH",
            "estimateHours": 12
          }
        ]
      }
    ]
  }
}
```

### Created Issues Map
```json
{
  "repository": "Axodus/AragonOSX",
  "parentIssue": {
    "number": 373,
    "nodeId": "I_kwDOLIGtvc7k2S9K",
    "url": "https://github.com/Axodus/AragonOSX/issues/373"
  },
  "childIssues": [
    {
      "stableId": "item-001",
      "number": 374,
      "nodeId": "I_kwDOLIGtvc7k2TC3",
      "level": 1,
      "parentStableId": "pai",
      "url": "https://github.com/Axodus/AragonOSX/issues/374"
    }
  ]
}
```

### Hierarchy Links
```json
{
  "repository": "Axodus/AragonOSX",
  "links": [
    {
      "parentIssueNumber": 373,
      "childIssueNumber": 374,
      "status": "linked"
    }
  ]
}
```

### ProjectV2 Sync Log
```json
{
  "repository": "Axodus/AragonOSX",
  "projectId": "PVT_kwDOBfRHZM4BM-PB",
  "mutations": [
    {
      "issueNumber": 373,
      "fieldId": "status-field-id",
      "fieldName": "Status",
      "newValue": "In Progress",
      "status": "success"
    },
    {
      "issueNumber": 373,
      "fieldId": "priority-field-id",
      "fieldName": "Priority",
      "newValue": "HIGH",
      "status": "success"
    }
  ]
}
```

---

## CLI Interface

```bash
# Full interactive E2E flow
pnpm e2e:interactive

# Specific stages
pnpm e2e:stage 1                    # SETUP
pnpm e2e:stage 2 --repo AragonOSX   # PREPARE
pnpm e2e:stage 3-4                  # CREATE (PAI + Children)
pnpm e2e:stage 5-6                  # LINK + SYNC

# Full pipeline (all stages)
pnpm e2e:full

# Resume from checkpoint
pnpm e2e:resume --from-stage 5

# Rollback (experimental)
pnpm e2e:rollback --repo AragonOSX
```

---

## Implementation Phases

### Phase 1: Infrastructure (Week 1-2)
- [ ] Create e2e-config.json structure
- [ ] Build config validation + loading
- [ ] Implement stage framework

### Phase 2: Core Stages (Week 2-3)
- [ ] STAGE 1-2: Setup + Prepare
- [ ] STAGE 3-4: Create (PAI + Children)
- [ ] STAGE 5-6: Link + Sync

### Phase 3: Enhancement (Week 4)
- [ ] STAGE 7: Progress Tracking
- [ ] STAGE 8: Reporting
- [ ] CLI interface + prompts

### Phase 4: Testing & Validation
- [ ] E2E testing with all 3 repos
- [ ] Rollback procedures
- [ ] Documentation

---

## Success Criteria

- [ ] Config setup wizard works
- [ ] All 8 stages execute without front-running
- [ ] All 3 repos can be processed independently or together
- [ ] Issues created with full metadata (no manual fixes)
- [ ] Hierarchy links created automatically
- [ ] ProjectV2 fields synced (or noted as unsupported)
- [ ] Complete audit trail generated
- [ ] Manual verification against issue #431 shows no gaps

---

## Known Constraints

1. **ProjectV2 PARENT_ISSUE field:** Not supported by GraphQL - use `gh issue link` instead
2. **Rate limiting:** Implement backoff strategy for concurrent mutations
3. **Async operations:** Some GitHub operations are eventually consistent
4. **Data validation:** Ensure metadata is valid before mutations

---

## Reference

**Issue #431 Analysis:**
- Shows complete hierarchy setup ✅
- All metadata applied upfront ✅
- No manual fixes needed ✅
- Audit trail included ✅

**This E2E flow will match/exceed #431 quality.**
