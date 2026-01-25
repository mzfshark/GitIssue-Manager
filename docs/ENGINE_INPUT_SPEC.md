# GitIssue-Manager Engine Input Mapping

Specification for parsing PLAN.md (and linked Markdown files) into engine-input.json.

**Version:** 1.0  
**Last Updated:** 2026-01-21  
**Status:** Production-ready  

---

## Overview

GitIssue-Manager consumes Markdown planning artifacts and converts them into structured GitHub API calls. This document defines the parsing rules, metadata schema, and output format.

### Input Files (per repository)

```
<repo-root>/
  PLAN.md           ← Main input; parsed for tasks/subtasks
  docs/plans/*.md   ← Optional; you can point to these using --plan/--plans/--plans-dir
  (linked .md files)← PLAN.md can link to other .md files; those are parsed too
```

### Output File
```
GitIssue-Manager/tmp/
  engine-input.json ← Parsed schema ready for GitHub API execution
```

---

## PLAN.md Schema

### File Structure
```markdown
#  #PLAN-001 - <Plan Title>

## Subtasks (Linked)

### PLAN-001: <Milestone>

- [ ] <Top-level item>
  - [ ] <Child item>
```

### Item ID Format (optional but recommended)

**Syntax:** `TYPE-NNN` (case-insensitive)

**Valid Types:** `FEATURE`, `TASK`, `BUG`, `EPIC`, `HOTFIX`, `PLAN`, `SPRINT`

**Examples:**
- `FEATURE-001` → New feature for sprint
- `TASK-042` → Work item (maintenance, refactoring)
- `BUG-007` → Bug fix with acceptance criteria
- `EPIC-001` → Multi-sprint feature (planning level)
- `HOTFIX-001` → Emergency production fix

### Metadata Tags

**Location:** At end of line, in square brackets

**Syntax:**
```
[key:<canonical-key>] [labels:label1, label2] [status:DONE|TODO] [priority:HIGH|MEDIUM|LOW] [estimate:Nh] [start:YYYY-MM-DD] [end:YYYY-MM-DD]
```

**Rules:**
- `key` is the canonical identity. When present, GitIssue-Manager derives `StableId` from `key` to avoid duplicates when items move.
- All tags optional except status (defaults to TODO if missing)
- Labels: comma-separated, no spaces
- Status: case-insensitive (DONE, Done, done all valid)
- Priority: HIGH, MEDIUM, LOW (case-insensitive)
- Estimate: numeric hours (e.g., 4h, 12h)
- Dates: ISO 8601 format (YYYY-MM-DD)

**Example:**
```markdown
- [ ] Implement reorg detection [key:01J0ABCDE...] [labels:type:feature, area:indexing, area:backend] [status:TODO] [priority:high] [estimate:12h] [start:2026-01-20] [end:2026-01-22]
  - [ ] Add unique constraint on block hash [labels:type:task] [status:DONE] [priority:high] [estimate:2h] [start:2026-01-20] [end:2026-01-20]
  - [ ] Test reorg recovery [labels:type:test] [status:TODO] [priority:high] [estimate:6h] [start:2026-01-21] [end:2026-01-22]
```

---

## Parsing Algorithm

### Step 1: Resolve plan files

GitIssue-Manager starts from PLAN.md (or a list of selected plan files via CLI flags) and also parses any linked `.md` files referenced via Markdown links.

It ignores dot-segments (e.g., `.git/`, `.github/`) for safety.

### Step 2: Parse hierarchy
```javascript
{
  title: "Sprint 1: HarmonyVoting E2E Production Rollout",
  goal: "Deliver production-ready HarmonyVoting with safe plugin lifecycle...",
  startDate: "2026-01-21",
  endDate: "2026-02-28",
  status: "Active",
  repository: "AragonOSX"  // Inferred from file location
}
```

### Step 2: Parse Item Hierarchy
For each checklist section (FEATURE-001, TASK-042, etc.):

1. Extract item ID and title
2. Extract description block
3. Extract all metadata tags from title line
4. Parse nested checkboxes (indentation = nesting level)
5. Merge tags from parent + child items

**Example Output:**
```javascript
{
  id: "FEATURE-001",
  title: "Indexing Resilience & Catch-Up",
  description: "Implement production-grade indexing...",
  type: "FEATURE",
  status: "TODO",
  priority: "HIGH",
  labels: ["area:indexing", "area:backend"],
  estimate: undefined,
  startDate: undefined,
  endDate: undefined,
  children: [
    {
      id: "FEATURE-001-1",  // Auto-generated for subtasks
      title: "Add reorg-safe handling...",
      status: "TODO",
      priority: "HIGH",
      estimate: 12,
      startDate: "2026-01-20",
      endDate: "2026-01-22",
      children: []
    },
    ...
  ]
}
```

### Step 3: Calculate Sprint Status
```javascript
{
  totalItems: 16,
  completedItems: 11,
  completionPercentage: 69,
  inProgress: 0,
  notStarted: 5
}
```

### Step 4: Generate GitHub Issue Title and Body

**Title:**

GitHub issue titles use breadcrumb format (no `-NNN` numbering in the GitHub title):

`[PLAN / EPIC / FEATURE|TASK|BUG|HOTFIX] - <Title>`

**Body:**

The body always includes `Source`, and includes `Key` when present:

```
Source: <file>#L<line>
Key: <canonical-key>
StableId: <stableId>
```
```markdown
# <Sprint Title>

## Sprint Goal
<Goal>

**Duration:** <Start Date> to <End Date>  
**Status:** <Completion %>

## Work Items

### FEATURE-001: <Title>
- [ ] <Task 1>
  - [ ] <Subtask 1>
  - [ ] <Subtask 2>
- [ ] <Task 2>

### TASK-001: <Title>
...

## Sprint Status

- Total items: <N>
- Completed: <N>
- In progress: <N>
- Not started: <N>
- Completion: <N>%
```

---

## engine-input.json Schema

### File Format
```json
{
  "repositories": [
    {
      "owner": "Axodus",
      "repo": "AragonOSX",
      "branch": "develop",
      "sprint": {
        "title": "Sprint 1: HarmonyVoting E2E Production Rollout",
        "goal": "...",
        "startDate": "2026-01-21",
        "endDate": "2026-02-28",
        "status": "Active",
        "completionPercentage": 69,
        "items": [
          {
            "id": "FEATURE-001",
            "title": "Indexing Resilience & Catch-Up",
            "description": "Implement production-grade indexing...",
            "type": "FEATURE",
            "status": "TODO",
            "priority": "HIGH",
            "labels": ["area:indexing", "area:backend"],
            "estimate": null,
            "startDate": null,
            "endDate": null,
            "children": [
              {
                "id": "FEATURE-001-1",
                "title": "Add reorg-safe handling",
                "status": "DONE",
                "priority": "HIGH",
                "estimate": 12,
                "startDate": "2026-01-20",
                "endDate": "2026-01-22",
                "children": []
              },
              ...
            ]
          },
          ...
        ]
      },
      "projectV2": {
        "projectId": "<GitHub project number>",
        "status": "Ready",  // Set to "Ready" when completionPercentage === 100
        "labels": ["sprint", "production", "harmony-voting"]
      }
    },
    ...
  ],
  "metadata": {
    "version": "1.0",
    "generatedAt": "2026-01-21T14:30:00Z",
    "parser": "gitissue-manager@1.0"
  }
}
```

---

## Dry-Run Output

When running with `--dry-run` flag, GitIssue-Manager outputs:

```json
{
  "operations": [
    {
      "action": "create_issue",
      "repository": "Axodus/AragonOSX",
      "issue": {
        "title": "[Sprint] HarmonyVoting E2E Production Rollout – Sprint 1",
        "body": "<Full markdown body with nested checklist>",
        "labels": ["sprint", "production", "harmony-voting", "area:indexing", "area:contracts"],
        "projectId": "<ProjectV2 ID>",
        "estimatedFields": {
          "status": "TODO",
          "priority": "HIGH",
          "estimate": "69h total"
        }
      }
    },
    {
      "action": "create_issue",
      "repository": "Axodus/aragon-app",
      "issue": { ... }
    },
    ...
  ],
  "summary": {
    "totalOperations": 3,
    "estimatedTime": "5–10 minutes",
    "warnings": [
      "PARENT_ISSUE field not supported in ProjectV2; manual UI linking recommended"
    ]
  }
}
```

---

## Execution Mode

When running without `--dry-run`, GitIssue-Manager:

1. **Validates** all parsed items against repository constraints
2. **Creates** issues via GitHub API in order (per repository)
3. **Attaches** to ProjectV2 board with metadata
4. **Logs** all operations to `logs/audit.jsonl` (JSONL format for streaming)

### Audit Log Entry (JSONL)
```json
{
  "timestamp": "2026-01-21T14:35:42Z",
  "action": "create_issue",
  "repository": "Axodus/AragonOSX",
  "issueNumber": 415,
  "title": "[Sprint] HarmonyVoting E2E Production Rollout – Sprint 1",
  "labels": ["sprint", "production", "harmony-voting"],
  "assignee": null,
  "projectV2": { "status": "TODO" },
  "completionPercentage": 69,
  "actor": "mzfshark",
  "status": "success"
}
```

---

## Error Handling

### Parsing Errors
- **Missing item ID:** Error; halt parsing for file
- **Invalid metadata tag:** Warning; skip tag
- **Malformed date:** Warning; treat as null

### GitHub API Errors
- **Issue creation fails:** Log error; skip to next item
- **ProjectV2 attach fails:** Log warning; issue created but not attached
- **Rate limit hit:** Pause and retry (exponential backoff)

---

## PLAN.md & BUG.md

These files are NOT parsed for issue generation.

**Purpose:**
- PLAN.md: Long-term strategic planning; reference documentation
- BUG.md: Known issues; investigation tracking

**Handling:**
- Not processed by engine parser
- Kept in repository root for team reference
- Manually linked in sprint issue (as "See also:" section)

---

## Validation Rules

### Pre-sync Checklist
```
✓ All items have TYPE-NNN ID
✓ No duplicate IDs across repositories
✓ All metadata tags syntactically valid
✓ Dates in ISO 8601 format
✓ Labels are comma-separated, no spaces
✓ Status values are: TODO, IN_PROGRESS, DONE
✓ Priority values are: LOW, MEDIUM, HIGH
✓ Estimate > 0 (hours)
✓ Description is non-empty
```

### Post-parse Validation
```
✓ Item count matches expected total
✓ Completion percentage is 0–100
✓ No orphaned children (parent exists)
✓ Dates are logical (start ≤ end)
```

---

## Example: Full Parsing Flow

### Input (SPRINT.md)
```markdown
# Sprint 1: HarmonyVoting E2E

**Sprint Goal:** Production-ready indexing

## FEATURE-001: Reorg Safety [area:indexing] [priority:high]

**Description:** Implement reorg detection and recovery.

- [ ] Add idempotency checks [labels:type:task] [status:DONE] [priority:high] [estimate:2h]
  - [ ] Add unique constraint [labels:type:task] [status:DONE] [estimate:1h]
```

### Parsed JSON
```json
{
  "items": [
    {
      "id": "FEATURE-001",
      "title": "Reorg Safety",
      "type": "FEATURE",
      "description": "Implement reorg detection and recovery.",
      "status": "TODO",
      "priority": "HIGH",
      "labels": ["area:indexing"],
      "children": [
        {
          "id": "FEATURE-001-1",
          "title": "Add idempotency checks",
          "status": "DONE",
          "priority": "HIGH",
          "estimate": 2,
          "labels": ["type:task"],
          "children": [
            {
              "id": "FEATURE-001-1-1",
              "title": "Add unique constraint",
              "status": "DONE",
              "estimate": 1,
              "labels": ["type:task"]
            }
          ]
        }
      ]
    }
  ],
  "completionPercentage": 50  // 2 DONE out of 4 items
}
```

### GitHub Issue Body
```markdown
## FEATURE-001: Reorg Safety

Implement reorg detection and recovery.

- [ ] Add idempotency checks [type:task]
  - [x] Add unique constraint [type:task] (~1h)
```

---

## Next Steps

1. Validate all SPRINT.md files against this schema
2. Run dry-run (no GitHub writes): `gitissuer sync --repo "mzfshark/AragonOSX" --dry-run`
3. Review output in console and `tmp/engine-input.json`
4. Approve and execute (writes to GitHub): `GITHUB_TOKEN=<token> gitissuer sync --repo "mzfshark/AragonOSX" --confirm`
5. Verify issues created in GitHub and attached to ProjectV2
