# Proposed Logic Adjustments — GitIssuer Plan Execution

**Date:** 2025-07-28  
**Status:** ✅ IMPLEMENTED  
**Issue:** [#73](https://github.com/mzfshark/GitIssue-Manager/issues/73)  
**Scope:** Changes to `prepare.js`, `rekey.js`, `executor.js`

---

## Executive Summary

Adjust the GitIssuer sync workflow so that:

1. **Plan files become parent issues** — The Markdown file itself is the parent; all checklist items are sub-issues.
2. **File content is the issue body** — Parent issue body contains the full plan document (not just metadata markers).
3. **Template-based generation** — Plan templates are filled at generation time with dynamic values.
4. **Improved dedupe** — SYNC verifies existing issues, associates tasks, creates only if not exists.
5. **Key preservation in REKEY** — Observe existing keys and reuse them; only add keys to new items.
6. **Auto-assign parent issues** — Parent issues get assignee = `<OWNER>` or `<USER>`.
7. **Update-only mode** — SYNC can update existing issues without creating new ones.

---

## Current Behavior Analysis

### `client/prepare.js`
- Parses Markdown checklists into `tasks` and `subtasks` arrays.
- **Heading with explicit ID (e.g., `EPIC-001`)** → task (parent candidate).
- **Checklist items** → tasks (indent=0) or subtasks (indent>0).
- **Does NOT** emit the plan file itself as a parent issue.
- **Does NOT** include file content as issue body.

### `client/rekey.js`
- Injects `[key:<ULID>]` into:
  - Headings that match `[A-Z]+-\d+` pattern (e.g., `TASK-001`)
  - Checklist items without keys
- **Already skips** items that have `[key:...]` tags (see `lineHasKeyTag()`).
- ✅ **Already preserves existing keys** — no change needed here.

### `server/executor.js`
- Loads existing issues via `loadStableIdIndex()` using `sync-md` label.
- Dedupes by `Key:` first, then `StableId:` in issue body.
- `buildIssueBody()` creates minimal body with `Source:`, `Key:`, `StableId:` markers.
- **Does NOT** use file content as body.
- **Does NOT** create parent issues from plan files.
- **Does NOT** use GitHub sub-issue API (just `Parent: #N` reference in body).
- `updateIssue()` exists but no `--update-only` flag.

---

## Proposed Changes

### 1. Plan File as Parent Issue (`prepare.js`)

**Goal:** Each plan file generates a parent issue; all items become sub-issues.

**Changes:**
```javascript
// In buildHierarchy(), emit the plan file as a "root" parent task:

function buildHierarchy(relFile, content, items, defaults, headingParents) {
  const tasks = [];
  const subtasks = [];
  
  // NEW: Create parent issue from plan file
  const fileKey = extractFileKey(content); // [key:...] at file level or generate
  const planStableId = fileKey 
    ? sha1(`key:${fileKey}`) 
    : sha1(`file:${relFile}`);
  
  const planTask = {
    stableId: planStableId,
    canonicalKey: fileKey,
    explicitId: extractPlanId(relFile), // e.g., PLAN-001 from filename
    file: relFile,
    line: 1,
    text: extractPlanTitle(content), // First H1 heading or filename
    body: content, // FULL FILE CONTENT
    checked: false,
    labels: mergeLabels(defaults.defaultLabels, ['plan-parent']),
    priority: extractFilePriority(content) || defaults.defaultPriority,
    status: defaults.defaultStatus,
    isParentPlan: true, // NEW FLAG
    assignee: defaults.owner || null, // AUTO-ASSIGN
  };
  
  tasks.push(planTask);
  
  // Existing logic: all items become subtasks under planTask
  for (const it of items) {
    // ...existing item processing...
    subtasks.push({
      ...base,
      parentStableId: parent?.stableId || planStableId, // Default to plan parent
    });
  }
  
  return { tasks, subtasks };
}
```

**New helper functions:**
```javascript
function extractFileKey(content) {
  // Look for [key:...] in file header (first 10 lines)
  const match = content.match(/\[key:([^\]]+)\]/i);
  return match ? match[1] : null;
}

function extractPlanTitle(content) {
  // First H1 heading
  const match = content.match(/^#\s+(.+)$/m);
  return match ? match[1].replace(/\[.*?\]/g, '').trim() : 'Untitled Plan';
}

function extractPlanId(relFile) {
  // Extract PLAN-001, SPRINT-001, etc. from filename
  const basename = path.basename(relFile, '.md');
  const match = basename.match(/^([A-Z]+[-_]?\d+)/);
  return match ? match[1].replace('_', '-') : null;
}
```

---

### 2. File Content as Issue Body (`executor.js`)

**Goal:** Parent issue body = full Markdown content (collapsible for readability).

**Changes:**
```javascript
function buildParentIssueBody(task, repo) {
  const markers = [
    `<!-- Source: ${task.file}:${task.line} -->`,
    `<!-- Key: ${task.canonicalKey || 'none'} -->`,
    `<!-- StableId: ${task.stableId} -->`,
  ].join('\n');
  
  // Wrap large content in collapsible details
  const contentSection = task.body && task.body.length > 500
    ? `<details>\n<summary>📄 Plan Content</summary>\n\n${task.body}\n\n</details>`
    : task.body || '';
  
  return `${markers}\n\n${contentSection}`;
}

function buildIssueBody(task, repo) {
  // Existing logic for non-parent tasks
  if (task.isParentPlan) {
    return buildParentIssueBody(task, repo);
  }
  // ...existing minimal body...
}
```

---

### 3. Auto-Assign Parent Issues (`executor.js`)

**Goal:** Parent issues auto-assigned to owner/user.

**Changes:**
```javascript
async function createIssue(task, repo, labels, { dryRun, assignee }) {
  const body = buildIssueBody(task, repo);
  const title = buildBreadcrumbTitle(task);
  
  // NEW: Auto-assign parent issues
  const effectiveAssignee = task.isParentPlan 
    ? (task.assignee || assignee || engine.owner)
    : assignee;
  
  if (dryRun) {
    console.log(`[DRY-RUN] Would create: ${title}`);
    console.log(`  assignee: ${effectiveAssignee || 'none'}`);
    return { number: null, nodeId: null };
  }
  
  const assigneeArg = effectiveAssignee 
    ? `--assignee "${effectiveAssignee}"`
    : '';
  
  const cmd = `gh issue create --repo "${repo}" --title "${escapeForShell(title)}" --body "${escapeForShell(body)}" ${assigneeArg} --label "${labels.join(',')}"`;
  // ...rest of creation logic...
}
```

---

### 4. Update-Only Mode (`executor.js`)

**Goal:** New `--update-only` flag to skip creation, only update existing issues.

**Changes:**
```javascript
// New CLI flag
const updateOnly = args.includes('--update-only');

// In main sync loop:
for (const task of tasks) {
  const existing = findIssueByCanonicalKey(task, index) 
    || findIssueByStableId(task, index);
  
  if (existing) {
    await updateIssue(existing.number, task, repo, labels, { dryRun });
  } else if (!updateOnly) {
    await createIssue(task, repo, labels, { dryRun, assignee });
  } else {
    console.log(`[SKIP] No existing issue for: ${task.text} (update-only mode)`);
  }
}
```

**New executor options:**
```
gitissuer sync --repo <owner/repo> --dry-run|--confirm [--update-only]

Options:
  --dry-run      Preview changes without writing
  --confirm      Execute changes (required for writes)
  --update-only  Only update existing issues, skip creation
```

---

### 5. Improved Dedupe (`executor.js`)

**Goal:** Better matching and association of tasks with existing issues.

**Current behavior is correct** — dedupes by Key first, then StableId. However, we should:

1. **Add body content matching** for parent issues (detect if content changed):
```javascript
function contentChanged(existing, task) {
  if (!task.isParentPlan) return false;
  // Compare stored content hash vs new content
  const existingHash = extractContentHash(existing.body);
  const newHash = sha1(task.body);
  return existingHash !== newHash;
}

// In buildParentIssueBody:
const contentHash = `<!-- ContentHash: ${sha1(task.body)} -->`;
```

2. **Track update reason** for audit:
```javascript
const updateReason = contentChanged(existing, task) 
  ? 'content-changed'
  : 'metadata-changed';
console.log(`[UPDATE] #${existing.number} (${updateReason})`);
```

---

### 6. Key Preservation in REKEY (`rekey.js`)

**Status:** ✅ Already implemented correctly.

The `lineHasKeyTag()` function skips items that already have `[key:...]`:
```javascript
function lineHasKeyTag(text) {
  return /\[key:[^\]]+\]/i.test(text);
}

// In injectKeysIntoMarkdown:
if (lineHasKeyTag(text)) continue; // Already has key, skip
```

No changes needed.

---

## Migration Notes

### Template Structure

Each plan file should follow this structure to work with the new logic:

```markdown
# PLAN-001 - Sprint Name [key:01XXXXXXXXXXXXXXXXXXXX]

**Repository:** repo-name(owner/repo)  
**End Date Goal:** YYYY-MM-DD  
**Priority:** HIGH  
**Status:** In Progress

---

## Executive Summary

Brief description.

---

## Subtasks

- [ ] Task 1 [key:01...] [labels:type:task]
  - [ ] Subtask 1.1 [key:01...]
  - [ ] Subtask 1.2 [key:01...]
- [ ] Task 2 [key:01...]
```

**Key placement:**
- File-level key goes in the title line: `# PLAN-001 - Title [key:...]`
- Task keys go at end of checklist item: `- [ ] Task [key:...]`

### Breaking Changes

1. **Parent issue structure** — Previous sync may have created flat issues. New sync will create parent + sub-issues hierarchy.
2. **Body content** — Parent issues will now contain full file content instead of minimal markers.
3. **Assignee behavior** — Parent issues will be auto-assigned; subtasks remain unassigned by default.

### Rollback Plan

If issues arise:
1. Keep `--update-only` mode to avoid creating duplicates.
2. Previous sync artifacts in `tmp/` can be used to identify old issues.
3. GitHub sub-issues can be unlinked manually if needed.

---

## Implementation Order

1. **Phase 1: prepare.js changes** (parent plan emission)
2. **Phase 2: executor.js changes** (parent body, auto-assign)
3. **Phase 3: executor.js changes** (update-only mode)
4. **Phase 4: Testing** (dry-run on sample repos)
5. **Phase 5: Documentation update**

---

## Questions for User

1. **Sub-issue API vs. body reference:** Should we use GitHub's sub-issue API (if available) or continue with `Parent: #N` body reference?
2. **Content hash tracking:** Should we detect content changes and only update when content differs?
3. **Closed issue handling:** If a plan file is updated but its issue is closed, should we reopen it?

---

**Approval Required:** Please review this proposal and confirm before implementation begins.
