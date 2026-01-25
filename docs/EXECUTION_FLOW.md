# EXECUTION FLOW: Multi-Repo Planning Synchronization

**Purpose:** Complete workflow for syncing 21 planning markdown files across 3 repositories to GitHub ProjectV2  
**Scope:** Axodus/AragonOSX, Axodus/aragon-app, Axodus/Aragon-app-backend  
**Version:** 1.0  
**Last Updated:** 2026-01-21

---

## Overview: 5-Stage Pipeline

```
┌─────────────────────────────────────────────────────────────────┐
│ STAGE 1: SETUP                                                  │
│ • Configure GitIssue-Manager for 3 repos                        │
│ • Verify GitHub auth + ProjectV2 schema                         │
│ • Create config.json with repo definitions                      │
└──────────────────────┬──────────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────────┐
│ STAGE 2: PREPARE                                                │
│ • Parse 21 markdown files (PLAN.md, BUG.md, FEATURE.md, etc)   │
│ • Generate engine-input.json with:                              │
│   ├─ Issue title + body (from markdown)                         │
│   ├─ Labels (extracted from metadata)                           │
│   ├─ Metadata schema (estimate, startDate, endDate, etc)        │
│   └─ Acceptance criteria + nested structure                     │
│ • Output: engine-input.json ready for GitHub creation           │
└──────────────────────┬──────────────────────────────────────────┘
                       │
        ┌──────────────▼──────────────────┐
        │  CREATE ISSUES IN GITHUB        │
        │  (parent issues only at first)  │
        └──────────────┬───────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────────┐
│ STAGE 3: ORGANIZE MANUALLY (USER IN GitHub UI)                 │
│                                                                  │
│ USER ACTIONS:                                                   │
│ • Open each parent issue in GitHub                              │
│ • Drag-and-drop child issues as sub-issues                      │
│ • Organize sub-sub-issues (hierarchical)                        │
│ • ⚠️  Cannot be automated (GitHub API limitation)               │
│                                                                  │
│ OUTPUT: Parent-child relationships finalized in ProjectV2       │
└──────────────────────┬──────────────────────────────────────────┘
                       │
        ┌──────────────▼──────────────────┐
        │  USER CONFIRMS READY            │
        │  (in console, user runs step 3) │
        └──────────────┬───────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────────┐
│ STAGE 4: FETCH                                                  │
│ • Query GitHub API: fetch all issues + sub-issues               │
│ • Build mapping:                                                │
│   ├─ markdown.md item ← → github.issue (number)                │
│   ├─ child_item ← → parent_issue.sub_issue                     │
│   └─ Store relationships in metadata.json                       │
│ • Validate: all markdown items found in GitHub                  │
└──────────────────────┬──────────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────────┐
│ STAGE 5: APPLY METADATA                                         │
│ • Parse metadata from markdown:                                 │
│   ├─ [estimate:Xh] → ProjectV2 "Estimate hours" field           │
│   ├─ [start:YYYY-MM-DD] → ProjectV2 "Start task" field          │
│   ├─ [end:YYYY-MM-DD] → ProjectV2 "End Task" field              │
│   ├─ [status:DONE|TODO|IN_PROGRESS] → ProjectV2 "Status" field  │
│   ├─ [priority:high|medium|low] → ProjectV2 "Priority" field    │
│   └─ [labels:type:X, area:Y] → GitHub issue labels              │
│ • Batch update via GraphQL mutations                            │
│ • Generate sync audit log                                       │
└──────────────────────┬──────────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────────┐
│ STAGE 6: REPORTS                                                │
│ • Generate sync report:                                         │
│   ├─ Issues created: X                                          │
│   ├─ Metadata applied: Y                                        │
│   ├─ Sub-issues linked: Z                                       │
│   └─ Errors/warnings: N                                         │
│ • ProjectV2 health check (field values vs schema)               │
│ • Output: sync-report.json + markdown summary                   │
└─────────────────────────────────────────────────────────────────┘
```

---

## STAGE 1: SETUP

### Objective
Initialize GitIssue-Manager for 3-repo sync with GitHub ProjectV2 schema validation.

### Steps

#### 1.1 Verify GitHub Authentication
```bash
gh auth status
# Expected: Logged in to github.com as mzfshark
# Scopes: repo, project, org
```

#### 1.2 Load ProjectV2 Schema
```bash
# For each repo, fetch and validate ProjectV2 schema
node scripts/register_project_fields.js \
  --owner Axodus \
  --number 23 \
  --out tmp/axodus-project-23-schema.json

# Output: JSON with 14 fields (id, name, dataType)
# Fields include: TITLE, ASSIGNEES, SINGLE_SELECT, DATE, NUMBER, etc.
```

#### 1.3 Create config.json
```json
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
```

#### 1.4 Validate Setup
```bash
# Test: Can we reach all repos and the project?
gh api repos/Axodus/AragonOSX --jq '.name, .owner.login'
gh api repos/Axodus/aragon-app --jq '.name, .owner.login'
gh api repos/Axodus/Aragon-app-backend --jq '.name, .owner.login'
gh project view 23 --owner Axodus
```

**Output:** ✅ All repos accessible, ProjectV2 schema loaded

---

## STAGE 2: PREPARE

### Objective
Parse 21 markdown files and generate structured JSON input for issue creation.

### Steps

#### 2.1 Parse Markdown Files

**Input:** 21 files across 3 repos
```
AragonOSX/
  ├─ PLAN.md
  ├─ BUG.md
  ├─ FEATURE.md
  ├─ SPRINT.md
  └─ ROADMAP.md

aragon-app/
  ├─ PLAN.md
  ├─ BUG.md
  └─ FEATURE.md

Aragon-app-backend/
  ├─ PLAN.md
  ├─ BUG.md
  └─ FEATURE.md
```

**Parser Logic:**
```javascript
// Pseudo-code for parsing strategy

const parseMarkdown = (filePath, repo) => {
  const content = fs.readFileSync(filePath, 'utf8');
  const items = [];
  
  // Extract:
  // 1. Title (# or ## heading)
  // 2. Body (paragraphs until next heading)
  // 3. Metadata (from inline tags)
  // 4. Nested structure (### = sub-item)
  
  // Metadata regex pattern:
  const metaRegex = /\[([a-z]+):([^\]]+)\]/g;
  
  return items.map(item => ({
    title: item.title,
    body: item.body,
    labels: extractLabels(item.metadata),
    estimate: item.metadata.estimate || null,
    startDate: item.metadata.start || null,
    endDate: item.metadata.end || null,
    status: item.metadata.status || 'TODO',
    priority: item.metadata.priority || 'medium',
    parentTitle: item.parentTitle || null, // For nesting
    repo: repo,
    sourceFile: filePath,
    sourceLine: item.lineNumber
  }));
};
```

#### 2.2 Generate engine-input.json

**Command:**
```bash
node scripts/prepare.js \
  --config config.json \
  --output tmp/engine-input.json \
  --repos AragonOSX,aragon-app,Aragon-app-backend
```

**Output Structure:**
```json
{
  "metadata": {
    "generatedAt": "2026-01-21T14:30:00Z",
    "repos": 3,
    "totalItems": 45,
    "organization": "Axodus",
    "projectNumber": 23
  },
  "repositories": [
    {
      "name": "AragonOSX",
      "owner": "Axodus",
      "items": [
        {
          "id": "PLAN-001",
          "type": "parent",
          "title": "[AragonOSX | #PLAN-001]: HarmonyVoting E2E Production Rollout",
          "body": "<!-- Full PLAN.md content -->",
          "labels": ["type:plan", "area:contracts", "area:indexing", "repo:AragonOSX"],
          "metadata": {
            "estimate": 160,
            "status": "IN_PROGRESS",
            "priority": "high",
            "startDate": "2026-01-21",
            "endDate": "2026-02-28"
          },
          "children": [
            {
              "id": "PLAN-001-SUB-001",
              "type": "child",
              "title": "Indexing Resilience",
              "body": "Reorg-safe indexing with catch-up + backfill",
              "labels": ["type:milestone", "area:indexing"],
              "metadata": {
                "estimate": 42,
                "status": "IN_PROGRESS",
                "priority": "high"
              },
              "children": [
                {
                  "id": "PLAN-001-SUB-001-TASK-001",
                  "type": "grandchild",
                  "title": "Ensure backend handlers cover HarmonyVoting events",
                  "labels": ["type:task", "area:backend"],
                  "metadata": {
                    "estimate": 6,
                    "status": "DONE",
                    "priority": "high"
                  }
                }
              ]
            }
          ]
        },
        {
          "id": "BUG-001",
          "type": "parent",
          "title": "[AragonOSX | #BUG-001]: RPC timeout on reorg recovery",
          "body": "<!-- BUG.md content -->",
          "labels": ["type:bug", "area:backend", "repo:AragonOSX"],
          "metadata": {
            "status": "TODO",
            "priority": "high"
          }
        }
      ]
    },
    {
      "name": "aragon-app",
      "owner": "Axodus",
      "items": [
        {
          "id": "PLAN-002",
          "type": "parent",
          "title": "[aragon-app | #PLAN-002]: Governance UI Resilience",
          "body": "<!-- Full PLAN.md content -->",
          "labels": ["type:plan", "area:frontend", "repo:aragon-app"],
          "children": []
        }
      ]
    },
    {
      "name": "Aragon-app-backend",
      "owner": "Axodus",
      "items": [
        {
          "id": "PLAN-003",
          "type": "parent",
          "title": "[Aragon-app-backend | #PLAN-003]: Event Indexing Pipeline",
          "body": "<!-- Full PLAN.md content -->",
          "labels": ["type:plan", "area:backend", "repo:Aragon-app-backend"],
          "children": []
        }
      ]
    }
  ]
}
```

#### 2.3 Validate engine-input.json
```bash
# Schema validation
ajv validate -s schemas/engine-input.schema.json tmp/engine-input.json

# Expected: All items match schema
# Count: ~45 items (PLAN + BUG + FEATURE + SPRINT + ROADMAP)
```

**Output:** ✅ engine-input.json ready for GitHub creation

---

## STAGE 3: CREATE ISSUES & ORGANIZE MANUALLY

### Objective
Create all parent/child issues in GitHub, then user manually organizes sub-issue hierarchy in ProjectV2 UI.

### Steps

#### 3.1 Create Parent Issues Only (Automated)
```bash
# Create all parent-level issues only
# (Do NOT create child issues yet)
node server/executor.js \
  --action create-parents \
  --input tmp/engine-input.json \
  --dry-run

# Review output, then execute:
node server/executor.js \
  --action create-parents \
  --input tmp/engine-input.json \
  --output tmp/creation-log.json
```

**Output:** 
```json
{
  "created": [
    {
      "repo": "Axodus/AragonOSX",
      "title": "[AragonOSX | #PLAN-001]: HarmonyVoting E2E Production Rollout",
      "issueNumber": 42,
      "issueId": "I_kwDOBfRHZM45123456",
      "url": "https://github.com/Axodus/AragonOSX/issues/42"
    }
  ],
  "errors": []
}
```

#### 3.2 User Action: Organize in GitHub UI

**⚠️ CRITICAL: Manual Step (Cannot be automated)**

User opens each parent issue and:
1. Creates the child issues (or copy-paste from email/list)
2. Links them as sub-issues by drag-and-drop in ProjectV2
3. Organizes sub-sub-issues (3-level hierarchy)

**Example Structure (as seen in ProjectV2):**
```
[AragonOSX | #PLAN-001]: HarmonyVoting E2E Production Rollout
├─ Indexing Resilience (sub-issue)
│  ├─ Ensure backend handlers cover HarmonyVoting events (sub-sub-issue)
│  ├─ Enable historical indexing (sub-sub-issue)
│  └─ Add reorg-safe handling (sub-sub-issue)
├─ Plugin Uninstall (sub-issue)
│  ├─ Define uninstall invariants (sub-sub-issue)
│  ├─ Verify contracts uninstall (sub-sub-issue)
│  └─ Test uninstall with governance permissions (sub-sub-issue)
└─ Metadata Redundancy (sub-issue)
   ├─ Identify metadata sources (sub-sub-issue)
   ├─ Define deterministic fallback (sub-sub-issue)
   └─ App fallback fetching (sub-sub-issue)
```

**User Checklist:**
- [ ] AragonOSX PLAN parent issue organized (7 issues)
- [ ] AragonOSX BUG parent issue organized (N issues)
- [ ] AragonOSX FEATURE parent issue organized (N issues)
- [ ] aragon-app PLAN parent issue organized (5 issues)
- [ ] aragon-app BUG parent issue organized (N issues)
- [ ] Aragon-app-backend PLAN parent issue organized (6 issues)
- [ ] Aragon-app-backend BUG parent issue organized (N issues)
- [ ] ✅ All organized? → Proceed to STAGE 4

**Output:** GitHub ProjectV2 populated with all issues, parent-child relationships finalized

---

## STAGE 4: FETCH

### Objective
Query GitHub to fetch final issue structure and build markdown ↔ issue mapping.

### Steps

#### 4.1 Query GitHub for All Issues
```bash
# Fetch all issues + sub-issue relationships from ProjectV2
node scripts/fetch-project-data.js \
  --owner Axodus \
  --number 23 \
  --output tmp/github-project-data.json
```

**Output Structure:**
```json
{
  "projectId": "PVT_kwDOBfRHZM4BM-PB",
  "issues": [
    {
      "number": 42,
      "id": "I_kwDOBfRHZM45123456",
      "title": "[AragonOSX | #PLAN-001]: HarmonyVoting E2E Production Rollout",
      "body": "<!-- Body from creation -->",
      "repository": "Axodus/AragonOSX",
      "labels": ["type:plan", "area:contracts"],
      "subIssues": [
        {
          "number": 43,
          "id": "I_kwDOBfRHZM45123457",
          "title": "Indexing Resilience",
          "parentIssueNumber": 42,
          "subIssues": [
            {
              "number": 44,
              "id": "I_kwDOBfRHZM45123458",
              "title": "Ensure backend handlers cover HarmonyVoting events",
              "parentIssueNumber": 43
            }
          ]
        }
      ]
    }
  ]
}
```

#### 4.2 Build Mapping: Markdown ↔ GitHub Issues
```bash
# Parse engine-input.json and github-project-data.json
# Generate mapping file
node scripts/build-mapping.js \
  --engine-input tmp/engine-input.json \
  --github-data tmp/github-project-data.json \
  --output tmp/mapping.json
```

**Output:**
```json
{
  "mappings": [
    {
      "source": {
        "repo": "AragonOSX",
        "file": "PLAN.md",
        "id": "PLAN-001",
        "title": "HarmonyVoting E2E Production Rollout"
      },
      "github": {
        "issueNumber": 42,
        "issueId": "I_kwDOBfRHZM45123456",
        "url": "https://github.com/Axodus/AragonOSX/issues/42",
        "children": [
          {
            "mdId": "PLAN-001-SUB-001",
            "mdTitle": "Indexing Resilience",
            "issueNumber": 43,
            "issueId": "I_kwDOBfRHZM45123457",
            "grandchildren": [
              {
                "mdId": "PLAN-001-SUB-001-TASK-001",
                "mdTitle": "Ensure backend handlers...",
                "issueNumber": 44,
                "issueId": "I_kwDOBfRHZM45123458"
              }
            ]
          }
        ]
      }
    }
  ]
}
```

#### 4.3 Validate Mapping
```bash
# Ensure all markdown items have GitHub counterparts
node scripts/validate-mapping.js \
  --mapping tmp/mapping.json \
  --expected-count 45

# Output: ✅ All 45 items mapped successfully
# Warnings: None
# Errors: None
```

**Output:** ✅ mapping.json complete and validated

---

## STAGE 5: APPLY METADATA

### Objective
Apply estimate, dates, status, priority to all GitHub issues via ProjectV2 field mutations.

### Steps

#### 5.1 Parse Metadata from Markdown
```javascript
// Extract metadata from each markdown item

const metadataPattern = /\[([a-z]+):([^\]]+)\]/g;

const parseMetadata = (text) => {
  const metadata = {};
  let match;
  
  while ((match = metadataPattern.exec(text)) !== null) {
    const [, key, value] = match;
    
    switch (key) {
      case 'estimate':
        metadata.estimate = parseInt(value);
        break;
      case 'start':
        metadata.startDate = value; // YYYY-MM-DD
        break;
      case 'end':
        metadata.endDate = value; // YYYY-MM-DD
        break;
      case 'status':
        metadata.status = value; // DONE | TODO | IN_PROGRESS
        break;
      case 'priority':
        metadata.priority = value; // high | medium | low
        break;
    }
  }
  
  return metadata;
};
```

#### 5.2 Build Metadata Update Payload
```bash
# Generate GraphQL mutation payload for all issues
node scripts/build-metadata-updates.js \
  --mapping tmp/mapping.json \
  --engine-input tmp/engine-input.json \
  --output tmp/metadata-updates.json
```

**Output:**
```json
{
  "updates": [
    {
      "issueId": "I_kwDOBfRHZM45123456",
      "issueNumber": 42,
      "fields": {
        "status": {
          "fieldId": "PVTF_kwDOBfRHZM4BM-PB_f1",
          "value": "In Progress"
        },
        "priority": {
          "fieldId": "PVTF_kwDOBfRHZM4BM-PB_f2",
          "value": "High"
        },
        "estimate": {
          "fieldId": "PVTF_kwDOBfRHZM4BM-PB_f3",
          "value": 160
        },
        "startDate": {
          "fieldId": "PVTF_kwDOBfRHZM4BM-PB_f4",
          "value": "2026-01-21"
        },
        "endDate": {
          "fieldId": "PVTF_kwDOBfRHZM4BM-PB_f5",
          "value": "2026-02-28"
        }
      }
    }
  ]
}
```

#### 5.3 Apply Metadata Updates
```bash
# Batch update all issues with metadata
# (Use GraphQL mutations for efficiency)
node scripts/apply-metadata.js \
  --updates tmp/metadata-updates.json \
  --dry-run

# Review changes, then:
node scripts/apply-metadata.js \
  --updates tmp/metadata-updates.json \
  --output tmp/metadata-apply-log.json
```

**Output:**
```json
{
  "applied": 45,
  "skipped": 0,
  "errors": 0,
  "results": [
    {
      "issueNumber": 42,
      "status": "✅ updated",
      "fieldsUpdated": ["status", "priority", "estimate", "startDate", "endDate"]
    }
  ]
}
```

#### 5.4 Validation
```bash
# Fetch issues again and verify metadata
gh api graphql -F owner:string=Axodus -F repo:string=AragonOSX \
  -f query='query($owner:String!,$repo:String!){
    repository(owner:$owner,name:$repo){
      issues(first:10){
        nodes{
          title
          projectItems(first:10){
            nodes{
              fieldValues(first:20){
                nodes{
                  field{name}
                  value
                }
              }
            }
          }
        }
      }
    }
  }'
```

**Output:** ✅ All metadata applied correctly

---

## STAGE 6: REPORTS

### Objective
Generate sync reports and validation summaries.

### Steps

#### 6.1 Generate Sync Report
```bash
# Compile all execution logs into single report
node scripts/generate-sync-report.js \
  --creation-log tmp/creation-log.json \
  --mapping tmp/mapping.json \
  --metadata-log tmp/metadata-apply-log.json \
  --output tmp/sync-report.json
```

**Output:**
```json
{
  "executionDate": "2026-01-21T15:30:00Z",
  "organization": "Axodus",
  "project": {
    "number": 23,
    "name": "DEV Dashboard",
    "id": "PVT_kwDOBfRHZM4BM-PB"
  },
  "repositories": {
    "AragonOSX": {
      "issues": {
        "created": 8,
        "mapped": 8,
        "metadata_applied": 8
      },
      "success": true
    },
    "aragon-app": {
      "issues": {
        "created": 5,
        "mapped": 5,
        "metadata_applied": 5
      },
      "success": true
    },
    "Aragon-app-backend": {
      "issues": {
        "created": 6,
        "mapped": 6,
        "metadata_applied": 6
      },
      "success": true
    }
  },
  "summary": {
    "totalIssuesCreated": 19,
    "totalIssuesMapped": 19,
    "totalMetadataApplied": 19,
    "errors": 0,
    "warnings": 0
  },
  "fieldsCovered": {
    "Status": { "updated": 19, "errors": 0 },
    "Priority": { "updated": 19, "errors": 0 },
    "Estimate hours": { "updated": 12, "skipped": 7 },
    "Start task": { "updated": 11, "skipped": 8 },
    "End Task": { "updated": 11, "skipped": 8 }
  }
}
```

#### 6.2 Generate Markdown Summary
```bash
node scripts/generate-sync-summary.md.js \
  --report tmp/sync-report.json \
  --output tmp/SYNC_REPORT.md
```

**Output: SYNC_REPORT.md**
```markdown
# Synchronization Report: Multi-Repo Planning → GitHub ProjectV2

**Execution Date:** 2026-01-21 15:30:00 UTC  
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

## Field Coverage

| Field | Updated | Skipped | Errors | Notes |
|---|---|---|---|---|
| Status | 19 | 0 | 0 | ✅ All items have status |
| Priority | 19 | 0 | 0 | ✅ All items have priority |
| Estimate hours | 12 | 7 | 0 | ⚠️ 7 items have no estimate (epic-level) |
| Start task | 11 | 8 | 0 | ℹ️ Only sprints have start dates |
| End Task | 11 | 8 | 0 | ℹ️ Only sprints have end dates |

## Issues by Repository

### AragonOSX
- ✅ [#42] HarmonyVoting E2E Production Rollout (PLAN)
  - [#43] Indexing Resilience (sub-issue)
  - [#44-50] 7 sub-sub-issues
- ✅ [#51] Critical RPC Timeout (BUG)
- ✅ [#52-55] Feature requests (4 issues)

### aragon-app
- ✅ [#162] Governance UI Resilience (PLAN)
  - [#163-165] 3 sub-issues
- ✅ [#166] Plugin Installation Bug (BUG)

### Aragon-app-backend
- ✅ [#1] Event Indexing Pipeline (PLAN)
  - [#2-6] 5 sub-issues
- ✅ [#7] Rate Limiter Implementation (FEATURE)

## Next Steps

1. **Verify in ProjectV2 UI:**
   - Open https://github.com/users/mzfshark/projects/5
   - Confirm all 19 issues appear
   - Check metadata fields are populated

2. **Track Progress:**
   - Use ProjectV2 board to manage sprints
   - Update issue status as work progresses
   - Monitor estimate vs actual hours

3. **Maintain Sync:**
   - When updating markdown files, re-run STAGE 2-6
   - Keep github-project-data.json as source of truth
   - Sync bidirectionally (markdown → GitHub and vice-versa)

---
Generated by GitIssue-Manager v1.0
```

#### 6.3 ProjectV2 Health Check
```bash
# Verify project schema integrity
node scripts/health-check-project.js \
  --owner Axodus \
  --number 23
```

**Output:**
```
ProjectV2 Health Check: Axodus/DEV Dashboard (#23)
═════════════════════════════════════════════════

✅ Project accessible: Yes
✅ Fields loaded: 14 fields
✅ Issues in project: 19 items
✅ Sub-issues linked: 16 of 19 (84%)
✅ Metadata coverage:
   ✅ Status: 19/19 (100%)
   ✅ Priority: 19/19 (100%)
   ✅ Estimate: 12/19 (63%)
   ✅ Start Date: 11/19 (58%)
   ✅ End Date: 11/19 (58%)

🟡 Warnings:
   - 7 issues missing estimate (expected for epic-level items)
   - PARENT_ISSUE field not writable (GitHub API limitation)

⚠️ Blocked:
   - None

═════════════════════════════════════════════════════════════════
Summary: ✅ ProjectV2 is healthy and ready for tracking
```

#### 6.4 Generate Bidirectional Sync Config
```bash
# Create config for future markdown ↔ GitHub syncs
node scripts/generate-sync-config.js \
  --mapping tmp/mapping.json \
  --output .gitissue/sync-config.json
```

**Output: .gitissue/sync-config.json**
```json
{
  "version": "1.0",
  "lastSync": "2026-01-21T15:30:00Z",
  "organization": "Axodus",
  "projectNumber": 23,
  "repositories": [
    {
      "repo": "AragonOSX",
      "owner": "Axodus",
      "branch": "develop",
      "planFiles": {
        "PLAN.md": {
          "parentIssueNumber": 42,
          "children": [
            {
              "title": "Indexing Resilience",
              "issueNumber": 43,
              "grandchildren": [...]
            }
          ]
        }
      }
    }
  ],
  "fieldMapping": {
    "estimate": "PVTF_kwDOBfRHZM4BM-PB_f3",
    "status": "PVTF_kwDOBfRHZM4BM-PB_f1",
    "priority": "PVTF_kwDOBfRHZM4BM-PB_f2",
    "startDate": "PVTF_kwDOBfRHZM4BM-PB_f4",
    "endDate": "PVTF_kwDOBfRHZM4BM-PB_f5"
  },
  "notes": "Use this config to update .md files when syncing GitHub changes back"
}
```

**Output:** ✅ Sync reports and configs generated

---

## Summary & Outputs

### Files Generated

| Stage | File | Purpose |
|---|---|---|
| 1 | config.json | GitIssue-Manager configuration |
| 1 | tmp/axodus-project-23-schema.json | ProjectV2 field schema |
| 2 | tmp/engine-input.json | Structured input for issue creation |
| 3 | tmp/creation-log.json | Log of created issues |
| 4 | tmp/github-project-data.json | Current state of GitHub project |
| 4 | tmp/mapping.json | Markdown ↔ GitHub issue mapping |
| 5 | tmp/metadata-updates.json | GraphQL mutations for metadata |
| 5 | tmp/metadata-apply-log.json | Log of applied metadata |
| 6 | tmp/sync-report.json | JSON sync report |
| 6 | tmp/SYNC_REPORT.md | Markdown sync summary |
| 6 | .gitissue/sync-config.json | Bidirectional sync config |

### Success Criteria

- ✅ All 21 markdown files parsed
- ✅ All parent issues created in GitHub
- ✅ All sub-issue relationships established (manual)
- ✅ All mapping entries validated
- ✅ All metadata fields applied to issues
- ✅ ProjectV2 health check passes
- ✅ Sync report generated

### Known Limitations

1. **PARENT_ISSUE Field:** GitHub ProjectV2 API does not support updating parent-issue field via GraphQL. Links must be established manually in UI.
2. **Sub-Issue Organization:** Cannot be automated due to lack of sub-issue mutation support in GitHub GraphQL API.
3. **Bidirectional Sync:** Currently manual process to sync GitHub changes back to markdown (script provided in Stage 6).

---

## How to Execute

### Prerequisites
```bash
# Install dependencies
cd GitIssue-Manager
npm install

# Configure
cp config.sample.json config.json
# Edit config.json with your repos and project number
```

### Run Pipeline
```bash
# STAGE 1: Setup
npm run setup -- --config config.json

# STAGE 2: Prepare
gitissuer prepare --all

# STAGE 3: Create issues (manually organize in UI after)
npm run create:parents -- --input tmp/engine-input.json

# USER ACTION: Organize in GitHub UI for ~30 minutes

# STAGE 4: Fetch
npm run fetch -- --owner Axodus --number 23

# STAGE 5: Apply metadata
npm run apply:metadata -- --mapping tmp/mapping.json

# STAGE 6: Reports
npm run reports -- --all
```

### Verify
```bash
# Check project in GitHub
open "https://github.com/users/mzfshark/projects/5"

# View sync report
cat tmp/SYNC_REPORT.md
```

---

**Document Version:** 1.0  
**Last Updated:** 2026-01-21  
**Author:** Morpheus Planning Agent
