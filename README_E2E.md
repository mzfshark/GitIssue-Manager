# E2E Flow - Complete Issue Hierarchy Generator

**Version:** 2.0  
**Status:** Planning Phase - Ready for Development  
**Target Release:** 2026-01-28  

---

## Overview

Complete **end-to-end flow** for generating issue hierarchies with full ProjectV2 metadata synchronization, eliminating front-running of dependent stages.

This solves the sequential dependency problem from the previous pipeline, ensuring:
- ✅ No front-running (each stage validates before next)
- ✅ Full metadata applied upfront
- ✅ No manual fixes needed
- ✅ Complete audit trail

Reference: [Issue #431](https://github.com/Axodus/AragonOSX/issues/431)

---

## Quick Start

### 1. Setup Configuration
```bash
cp config/e2e-config.sample.json config/e2e-config.json
nano config/e2e-config.json
```

Update with your actual ProjectV2 IDs and settings.

### 2. Run Interactive Flow
```bash
pnpm e2e:interactive
```

### 3. Monitor Execution
The script will guide you through:
1. Repository selection
2. Plan selection
3. Issue generation (8 stages)
4. Validation & reporting

---

## The 8 Stages

### 1️⃣ SETUP
Validates configuration and GitHub access
- Load config file
- Verify GitHub auth
- Prepare output directories

### 2️⃣ PREPARE  
Parses .md files and builds hierarchy
- Parse PLAN.md + SPRINT.md
- Extract task hierarchy (parent→child→grandchild)
- Extract metadata (assignee, labels, type, estimate, dates)

### 3️⃣ CREATE PAI
Creates parent issue with full metadata
- Create issue with title, description, type
- Set assignee, labels, priority
- Add to ProjectV2 immediately

### 4️⃣ CREATE CHILDREN
Generates all sub-issues with metadata
- Create each issue in hierarchy order
- Assign full metadata to each
- Maintain parent-child relationships

### 5️⃣ LINK HIERARCHY
Creates issue relationships automatically
- Use `gh issue link` for parent↔child relationships
- Build complete tree (can be multiple levels)
- Validate all links created

### 6️⃣ SYNC PROJECTV2
Synchronizes all metadata to project fields
- Fetch ProjectV2 schema
- Set Status (if field exists)
- Set Priority (if field exists)
- Set Estimate Hours (if field exists)
- Set Start/End Dates (if fields exist)

### 7️⃣ PROGRESS TRACKING (Optional)
Generates nested checklist
- Build hierarchy checklist from issues
- Calculate completion percentages
- Append to PAI body

### 8️⃣ REPORTING
Generates audit trail and validation report
- List all issues created
- List all relationships created
- List all ProjectV2 mutations
- Validate quality against #431 standards

---

## Configuration

### e2e-config.json Structure

```json
{
  "github": {
    "organization": "Axodus",
    "tokenEnv": "GITHUB_TOKEN"
  },
  "repositories": [
    {
      "id": "aragon-osx",
      "fullName": "Axodus/AragonOSX",
      "docsPath": "./docs/plans",
      "defaultOwner": "mzfshark",
      "project": {
        "id": "PVT_kwDOBfRHZM4BM-PB",
        "number": 23,
        "name": "Aragon OSx Sprint 1"
      },
      "metadata": {
        "defaultLabels": ["plan", "sprint1"],
        "defaultAssignee": "mzfshark",
        "defaultType": "EPIC",
        "defaultPriority": "HIGH",
        "defaultStatus": "In Progress"
      }
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
  }
}
```

**Key Fields:**
- `project.id`: ProjectV2 node ID (format: `PVT_kw...`)
- `project.number`: Project number (from URL)
- `fieldMappings`: Maps field names to ProjectV2 field display names

---

## Usage

### Interactive Mode (Recommended)
```bash
pnpm e2e:interactive
```

### Command Line Options
```bash
# Specific repository
bash scripts/e2e-flow.sh --repo aragon-osx

# Specific plan
bash scripts/e2e-flow.sh --repo aragon-osx --plan PLAN.md

# Dry-run (no mutations)
bash scripts/e2e-flow.sh --repo aragon-osx --dry-run

# From checkpoint
bash scripts/e2e-flow.sh --resume --from-stage 5

# Help
bash scripts/e2e-flow.sh --help
```

---

## Output Files

Generated in `tmp/e2e-execution/`:

| File | Contents |
|------|----------|
| `preparation-state.json` | Parsed hierarchy + metadata |
| `parent-issue.json` | PAI information (#issue-number) |
| `all-issues.json` | All created issues (flat list) |
| `hierarchy-links.json` | parent→child relationships |
| `project-sync.json` | ProjectV2 mutations log |
| `progress-tracking.md` | Generated hierarchy checklist |
| `e2e-execution-report.json` | Structured audit log |
| `e2e-execution-report.md` | Human-readable summary |

---

## How It Prevents Front-Running

### ❌ Old Pipeline (Front-Running Problem)
```
1. Create PAI
2. (Immediately) Create children (might fail)
3. (Immediately) Link issues (proceeds even if #2 fails)
4. (Immediately) Sync ProjectV2 (proceeds even if #3 fails)
→ Result: Partial/broken state with no clear recovery path
```

### ✅ New Pipeline (Sequential Validation)
```
1. Create PAI → Verify in GitHub → Store ID
   ↓ (only proceed if valid)
2. Create Children → Verify all in GitHub → Store IDs
   ↓ (only proceed if all valid)
3. Link Issues → Verify all linked → Log results
   ↓ (only proceed if all valid)
4. Sync ProjectV2 → Verify mutations → Log results
   ↓ (only proceed if all valid)
5. Generate Report → Compare #431 → Validate quality
→ Result: Complete + validated state
```

---

## Error Handling

### Retry Strategy
- Attempt 1: immediate
- Attempt 2: after 1s (backoff)
- Attempt 3: after 2s
- Fail: Log error + save state

### Rollback Safety
- Store all issue numbers before any mutations
- If failure occurs, provide deletion script
- Document manual cleanup steps

---

## Validation

### Quality Checklist (Against #431)
- [ ] Issue created with full context
- [ ] Description includes PLAN.md
- [ ] Type set to EPIC
- [ ] Assignee set
- [ ] Labels applied
- [ ] Added to ProjectV2
- [ ] All sub-issues created
- [ ] All relationships created
- [ ] ProjectV2 fields synced
- [ ] No manual fixes needed
- [ ] Audit trail complete

---

## Documentation

| Document | Purpose |
|----------|---------|
| [PLAN_E2E_FLOW.md](./PLAN_E2E_FLOW.md) | Complete design & architecture |
| [E2E_IMPLEMENTATION_GUIDE.md](./E2E_IMPLEMENTATION_GUIDE.md) | Implementation roadmap |
| [README_E2E.md](./README_E2E.md) | This file - quick reference |

---

## Support

### Common Issues

**"Config file not found"**
```bash
cp config/e2e-config.sample.json config/e2e-config.json
```

**"Not authenticated with GitHub"**
```bash
gh auth login
```

**"ProjectV2 fields not synced"**
- Check `fieldMappings` in config
- Verify field names match ProjectV2 UI
- Some fields might not exist in your project

---

## Roadmap

### Phase 1: Infrastructure (Week 1)
- [x] e2e-config.json structure
- [x] e2e-flow.sh skeleton
- [x] Documentation

### Phase 2: Core Implementation (Week 2-3)
- [ ] STAGE 1-4: Create (PAI + children)
- [ ] STAGE 5-6: Link + Sync

### Phase 3: Enhancement (Week 4)
- [ ] STAGE 7-8: Progress Tracking + Reporting
- [ ] Interactive CLI prompts
- [ ] E2E testing

---

## References

- **Issue #431:** https://github.com/Axodus/AragonOSX/issues/431
- **ProjectV2 Docs:** https://docs.github.com/en/issues/planning-and-tracking-with-projects
- **GitHub CLI:** https://cli.github.com/

---

**Last Updated:** 2026-01-21  
**Next Review:** 2026-01-28
