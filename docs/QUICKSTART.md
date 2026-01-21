# GitIssue-Manager Quickstart Guide

**Welcome!** This guide walks you through creating your first GitHub issues from a Markdown plan file in 10 minutes.

## Prerequisites
- Node.js 16+ (check: `node --version`)
- A GitHub Personal Access Token (PAT) with `repo` and `project` scopes
- One Markdown file (e.g., `SPRINT.md`) with your plan

## Step 1: Get the PAT and set up environment

### Generate a GitHub PAT
1. Go to https://github.com/settings/tokens (logged in)
2. Click **"Generate new token"** (classic)
3. Give it a name (e.g., `GitIssue-Manager`)
4. Select scopes: `repo` + `project`
5. Click **"Generate"**
6. Copy the token (you'll only see it once!)

### Create `.env` file
In the `GitIssue-Manager` folder, create a file named `.env`:

```bash
GITHUB_TOKEN=ghp_your_token_here_copy_from_step_5
```

**Keep this file secret!** Add to `.gitignore` if needed.

---

## Step 2: Create your first plan file

In your target repo, create `SPRINT.md`:

```markdown
# Sprint 1: Feature X

## FEATURE-001: Add user login
- [ ] Create login form component
  - [ ] Add email input field
  - [ ] Add password field
  - [ ] Add submit button
- [ ] Write backend endpoint
- [ ] Add integration tests

## BUG-001: Fix validator address bug [priority:high]
- [ ] Reproduce the issue
- [ ] Write test case
- [ ] Fix the bug
- [ ] Deploy to staging
```

Save it in your repo.

---

## Step 3: Configure the target repository

Create a config file in `sync-helper/configs/my-repo-config.json`:

```json
{
  "repo": "mzfshark/my-awesome-repo",
  "planFiles": ["SPRINT.md", "PLAN.md"],
  "projectId": "PVT_kwDOAA...",
  "labels": ["sprint", "automated"]
}
```

**Where to find `projectId`:**
1. Open your GitHub repo
2. Click **Projects** tab
3. Open your ProjectV2 board
4. Copy from the URL: `https://github.com/users/mzfshark/projects/15` → `15` is the numeric ID
6. Get the full ID from GraphQL or just use the number

---

## Step 4: Install & prepare

```bash
# Install dependencies
pnpm install

# Run the parser to extract tasks
node client/prepare.js --config sync-helper/configs/my-repo-config.json
```

Check the output:
- ✅ `tmp/engine-input.json` created (contains your tasks)
- ✅ No errors in terminal

---

## Step 5: Preview (dry-run)

Before touching GitHub, see what will be created:

```bash
node server/executor.js --input tmp/engine-input.json --dry-run
```

You'll see:
- Issues to be created (with titles, descriptions)
- Fields to be set (labels, assignee, ProjectV2 board)
- Summary JSON in `logs/dryrun_summary_*.json`

**Review the output:**
```bash
# Open and review
cat logs/dryrun_summary_*.json
```

Look for:
- Issue titles (should have `[repo | #TYPE-NNN]` prefix)
- Descriptions (match your Markdown?)
- Labels (correct?)
- No warnings/errors

---

## Step 6: Execute (create real issues)

Once satisfied with the dry-run, apply the changes:

```bash
node server/executor.js --input tmp/engine-input.json --execute
```

**What happens:**
1. Parser creates issues in GitHub
2. Issues are attached to ProjectV2
3. Labels, priority, assignees are set
4. Audit log is updated in `logs/audit.jsonl`

**Verify:**
- Go to your GitHub repo → Issues tab
- You should see new issues like `[my-awesome-repo | #FEATURE-001]`
- Go to ProjectV2 board → issues should appear

---

## Step 7: Update your plan, sync again

Later, you modify `SPRINT.md`:

```markdown
## FEATURE-001: Add user login
- [x] Create login form component  ← Mark as done
  - [x] Add email input field
  - [x] Add password field
  - [ ] Add submit button         ← Still pending
- [ ] Write backend endpoint       ← Changed!
- [ ] Add integration tests
```

Re-run:
```bash
node client/prepare.js --config sync-helper/configs/my-repo-config.json
node server/executor.js --input tmp/engine-input.json --dry-run
# Review...
node server/executor.js --input tmp/engine-input.json --execute
```

The tool will:
- Detect the `FEATURE-001` issue already exists (via stable ID)
- Update the description + checklist
- No duplicate issue created

---

## Common Issues

### ❓ "No tools support the specified file(s)"
Codacy CLI error (can ignore for now). Files were created OK.

### ❓ "GITHUB_TOKEN not found"
- Did you create `.env` file? Check it exists in the repo root
- Is the token valid? Try generating a new one

### ❓ "Project not found"
- Check `projectId` in config (should be numeric or full ID)
- Verify you have push access to that project

### ❓ Issues not appearing on ProjectV2
- Verify project permissions
- Try two-step: create issue first, then manually add to ProjectV2 in UI
- Check audit log for errors

---

## Next Steps

1. **Automate in CI/CD:** Add a GitHub Action to run the parser/executor on every commit to `SPRINT.md`
2. **Multi-repo:** Create configs for other repos, run per-repo to stay safe
3. **Team workflow:** Agree on naming (`TYPE-NNN`), checklist style, label conventions
4. **Monitoring:** Review `logs/audit.jsonl` regularly (compliance, debugging)

---

## Getting Help

- **Parser issues?** Check `tmp/engine-input.json` structure
- **GitHub API errors?** Review `logs/audit.jsonl` for error details
- **Dry-run looks wrong?** Edit your `.md` file and re-run `prepare.js`

Good luck! 🚀
