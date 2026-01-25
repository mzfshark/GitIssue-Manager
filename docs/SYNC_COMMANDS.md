# GitIssue-Manager Sync Commands (Ready for Approval)

Production-grade sync commands to push SPRINT.md artifacts to GitHub ProjectV2.

**Generated:** 2026-01-21  
**Status:** Ready for approval and execution  
**Scope:** HarmonyVoting E2E production rollout  

---

## Pre-Execution Checklist

- [x] All SPRINT.md files created and validated
- [x] All BUG.md files created (internal reference)
- [x] PRODUCTION_SCOPE.md and ENGINE_INPUT_SPEC.md documented
- [x] Metadata tags consistent across all repos
- [x] No duplicate item IDs
- [x] GitHub PAT available (in .env)

---

## Dry-Run Commands (No GitHub writes)

Execute these commands to preview changes before applying them:

### 1. AragonOSX (Contracts)
```bash
cd GitIssue-Manager
NODE_ENV=test node client/prepare.js \
  --repo "Axodus/AragonOSX" \
  --branch "develop" \
  --sprint-file "../AragonOSX/SPRINT.md" \
  --project-url "https://github.com/users/mzfshark/projects/5" \
  --dry-run
```

**Expected Output:**
- Parsed items: 16
- Completion: 69%
- Preview issue title: `[Sprint] HarmonyVoting E2E Production Rollout – Sprint 1`
- Labels: `sprint,production,harmony-voting,area:indexing,area:contracts`

### 2. aragon-app (Frontend)
```bash
cd GitIssue-Manager
NODE_ENV=test node client/prepare.js \
  --repo "Axodus/aragon-app" \
  --branch "develop" \
  --sprint-file "../aragon-app/SPRINT.md" \
  --project-url "https://github.com/users/mzfshark/projects/5" \
  --dry-run
```

**Expected Output:**
- Parsed items: 15
- Completion: 73%
- Preview issue title: `[Sprint] Frontend UI & UX Production Release – Sprint 1`
- Labels: `sprint,production,harmony-voting,area:frontend`

### 3. Aragon-app-backend (Backend API & Indexer)
```bash
cd GitIssue-Manager
NODE_ENV=test node client/prepare.js \
  --repo "Axodus/Aragon-app-backend" \
  --branch "development" \
  --sprint-file "../Aragon-app-backend/SPRINT.md" \
  --project-url "https://github.com/users/mzfshark/projects/5" \
  --dry-run
```

**Expected Output:**
- Parsed items: 12
- Completion: 17%
- Preview issue title: `[Sprint] Backend Indexing Production Rollout – Sprint 1`
- Labels: `sprint,production,harmony-voting,area:backend,area:indexing`

---

## Execution Commands (Write to GitHub)

**⚠️ Approval Required:** Only run after reviewing dry-run output.

### 1. AragonOSX (Contracts)
```bash
cd GitIssue-Manager
GITHUB_TOKEN=<your-token> node server/executor.js \
  --action "create_sprint_issue" \
  --repo "Axodus/AragonOSX" \
  --branch "develop" \
  --sprint-file "../AragonOSX/SPRINT.md" \
  --project-url "https://github.com/users/mzfshark/projects/5" \
  --execute
```

**Result:**
- Creates issue #XXX: `[Sprint] HarmonyVoting E2E Production Rollout – Sprint 1`
- Attaches to ProjectV2 board
- Sets status: TODO (current completion 69%)
- Logs to `logs/audit.jsonl`

### 2. aragon-app (Frontend)
```bash
cd GitIssue-Manager
GITHUB_TOKEN=<your-token> node server/executor.js \
  --action "create_sprint_issue" \
  --repo "Axodus/aragon-app" \
  --branch "develop" \
  --sprint-file "../aragon-app/SPRINT.md" \
  --project-url "https://github.com/users/mzfshark/projects/5" \
  --execute
```

**Result:**
- Creates issue #XXX: `[Sprint] Frontend UI & UX Production Release – Sprint 1`
- Attaches to ProjectV2 board
- Sets status: TODO (current completion 73%)
- Logs to `logs/audit.jsonl`

### 3. Aragon-app-backend (Backend API & Indexer)
```bash
cd GitIssue-Manager
GITHUB_TOKEN=<your-token> node server/executor.js \
  --action "create_sprint_issue" \
  --repo "Axodus/Aragon-app-backend" \
  --branch "development" \
  --sprint-file "../Aragon-app-backend/SPRINT.md" \
  --project-url "https://github.com/users/mzfshark/projects/5" \
  --execute
```

**Result:**
- Creates issue #XXX: `[Sprint] Backend Indexing Production Rollout – Sprint 1`
- Attaches to ProjectV2 board
- Sets status: TODO (current completion 17%)
- Logs to `logs/audit.jsonl`

---

## Batch Execution (All at once)

```bash
cd GitIssue-Manager

# Dry-run all repos
node scripts/prepare.sh \
  --repos "aragon-osx,aragon-app,aragon-app-backend" \
  --dry-run

# Execute (after approval)
GITHUB_TOKEN=<your-token> node scripts/prepare.sh \
  --repos "aragon-osx,aragon-app,aragon-app-backend" \
  --execute \
  --project "5"  # ProjectV2 number
```

---

## GitHub CLI Alternative (Simpler)

If GitIssue-Manager is not ready, you can use `gh` CLI directly:

### 1. AragonOSX
```bash
gh issue create \
  --repo "Axodus/AragonOSX" \
  --title "[Sprint] HarmonyVoting E2E Production Rollout – Sprint 1" \
  --body-file "AragonOSX/SPRINT.md" \
  --label "sprint,production,harmony-voting,area:indexing,area:contracts" \
  --project "https://github.com/users/mzfshark/projects/5"
```

### 2. aragon-app
```bash
gh issue create \
  --repo "Axodus/aragon-app" \
  --title "[Sprint] Frontend UI & UX Production Release – Sprint 1" \
  --body-file "aragon-app/SPRINT.md" \
  --label "sprint,production,harmony-voting,area:frontend" \
  --project "https://github.com/users/mzfshark/projects/5"
```

### 3. Aragon-app-backend
```bash
gh issue create \
  --repo "Axodus/Aragon-app-backend" \
  --title "[Sprint] Backend Indexing Production Rollout – Sprint 1" \
  --body-file "Aragon-app-backend/SPRINT.md" \
  --label "sprint,production,harmony-voting,area:backend,area:indexing" \
  --project "https://github.com/users/mzfshark/projects/5"
```

---

## Post-Execution Verification

After issues are created, verify:

1. **Three issues created:**
   - `[Sprint] HarmonyVoting E2E Production Rollout – Sprint 1` in AragonOSX
   - `[Sprint] Frontend UI & UX Production Release – Sprint 1` in aragon-app
   - `[Sprint] Backend Indexing Production Rollout – Sprint 1` in Aragon-app-backend

2. **All issues attached to ProjectV2:**
   - Open https://github.com/users/mzfshark/projects/5
   - Verify 3 new items visible
   - Check status field (should be TODO)

3. **Labels applied correctly:**
   - Each issue should have: `sprint`, `production`, `harmony-voting`, + area tags

4. **Audit log updated:**
   - Check `logs/audit.jsonl` for 3 new entries
   - Each entry should have status: `success`

---

## Rollback Plan

If something goes wrong:

### Option 1: Delete Issues (via GitHub CLI)
```bash
# Get issue numbers first
gh issue list --repo "Axodus/AragonOSX" --label "sprint,harmony-voting" --limit 1

# Delete (close + mark as not planned)
gh issue close --repo "Axodus/AragonOSX" --issue <number> --reason "not_planned"
```

### Option 2: Delete Manually
- Open each issue in GitHub
- Click "..." menu → "Delete issue"
- Confirm

### Option 3: Revert Sprint SPRINT.md
If you need to adjust the sprint definition:
1. Edit the SPRINT.md file
2. Re-run sync with `--update` flag (if supported)
3. Manually update issue body

---

## Monitoring & Updates

### Daily Status Updates

To update sprint issue status daily (recommended):

```bash
# Generate updated issue body from current SPRINT.md
node client/prepare.js \
  --repo "Axodus/AragonOSX" \
  --sprint-file "../AragonOSX/SPRINT.md" \
  --action "update_issue" \
  --issue-number <number> \
  --execute
```

### Weekly Status Report

GitIssue-Manager can generate a consolidated status report across all 3 repos:

```bash
node scripts/status-report.js \
  --repos "aragon-osx,aragon-app,aragon-app-backend" \
  --output "SPRINT_STATUS_WEEK_1.md"
```

---

## Environment Setup

Before running commands, ensure:

1. **GitHub PAT in .env:**
   ```bash
   cd GitIssue-Manager
   echo "GITHUB_TOKEN=ghp_your_token_here" > .env
   ```

2. **Node 16+ installed:**
   ```bash
   node --version  # Should be v16 or higher
   ```

3. **Dependencies installed:**
   ```bash
   cd GitIssue-Manager
   npm install  # or yarn install
   ```

4. **File paths correct:**
   ```bash
   # Verify SPRINT.md files exist
   ls -la ../AragonOSX/SPRINT.md
   ls -la ../aragon-app/SPRINT.md
   ls -la ../Aragon-app-backend/SPRINT.md
   ```

---

## Approval Checklist

Before executing any commands:

- [ ] All dry-run outputs reviewed and approved
- [ ] No conflicts with existing GitHub issues
- [ ] Team lead confirmed release timeline
- [ ] ProjectV2 board URL verified
- [ ] GitHub PAT token has `repo` + `project` scopes
- [ ] Backup of SPRINT.md files created (git commit)

---

## Questions & Support

- **Why separate sync commands?** To allow per-repo approval and rollback.
- **Can I sync PLAN.md too?** No; PLAN.md stays internal (reference only).
- **What about BUG.md?** BUG.md is internal; not synced (reference in sprint issue).
- **How do I update an issue after creation?** Use `--action update_issue --issue-number <N>`.
- **What if GitHub API rate limits?** GitIssue-Manager implements exponential backoff; wait ~1 hour.

---

## Next Steps

1. **Review dry-run output:**
   ```bash
   cd GitIssue-Manager
  gitissuer sync --repo "mzfshark/AragonOSX" --dry-run
   ```

2. **Approve in this document:**
   - [ ] Dry-run output looks good
   - [ ] Ready to execute

3. **Execute batch sync:**
   ```bash
  GITHUB_TOKEN=<token> gitissuer sync --repo "mzfshark/AragonOSX" --confirm
   ```

4. **Verify in GitHub:**
   - Check https://github.com/users/mzfshark/projects/5
   - Confirm 3 sprint issues visible

---

**Document Status:** Ready for approval  
**Last Updated:** 2026-01-21  
**Next Review:** After sprint issue creation
