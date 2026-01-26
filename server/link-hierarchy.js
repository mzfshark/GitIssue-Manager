#!/usr/bin/env node
/**
 * link-hierarchy.js
 * 
 * Native Node.js implementation for linking parent↔sub-issue hierarchy via GitHub GraphQL API.
 * Replaces the bash-based STAGE 5 from e2e-flow-v2.sh for better reliability and maintainability.
 * 
 * Usage:
 *   node server/link-hierarchy.js --config <path> [--dry-run] [--parent-number <n>] [--replace-parent]
 *     [--engine-output-file <path>] [--metadata-file <path>]
 * 
 * Reads engine-output.json to get stableId → issueNumber mapping, then calls addSubIssue mutation
 * for each parent↔child relation.
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// ─────────────────────────────────────────────────────────────────────────────
// CLI Argument Parsing
// ─────────────────────────────────────────────────────────────────────────────

const args = process.argv.slice(2);

function getArg(name) {
  const idx = args.indexOf(name);
  if (idx === -1) return null;
  return args[idx + 1] || null;
}

const configPath = getArg('--config');
const dryRun = args.includes('--dry-run');
const replaceParent = args.includes('--replace-parent');
const parentNumberArg = getArg('--parent-number');
const engineOutputFileArg = getArg('--engine-output-file');
const metadataFileArg = getArg('--metadata-file');

if (!configPath) {
  console.error('Usage: node link-hierarchy.js --config <path> [--dry-run] [--parent-number <n>] [--replace-parent] [--engine-output-file <path>] [--metadata-file <path>]');
  process.exit(1);
}

if (!fs.existsSync(configPath)) {
  console.error(`ERROR: Config file not found: ${configPath}`);
  process.exit(1);
}

// ─────────────────────────────────────────────────────────────────────────────
// Load Configuration
// ─────────────────────────────────────────────────────────────────────────────

const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
const repoFull = config.repo || `${config.owner}/${config.repoName}`;
const [owner, repo] = repoFull.split('/');

// Resolve paths
const defaultEngineOutputPath = config.outputs?.engineOutputPath || `./tmp/${repoFull.replace('/', '-')}/engine-output.json`;
const defaultMetadataPath = config.outputs?.metadataPath || config.outputs?.tasksPath?.replace('tasks.json', 'metadata.json') || `./tmp/${repoFull.replace('/', '-')}/metadata.json`;

// Allow wrapper to pass explicit artifact paths from the same run.
const engineOutputPath = engineOutputFileArg || defaultEngineOutputPath;
const metadataPath = metadataFileArg || defaultMetadataPath;

// Parent issue number: CLI arg > config > null
let parentIssueNumber = parentNumberArg ? parseInt(parentNumberArg, 10) : null;
if (!parentIssueNumber && config.gitissuer?.hierarchy?.parentIssueNumber) {
  parentIssueNumber = config.gitissuer.hierarchy.parentIssueNumber;
}

console.log(`[INFO] Repository: ${repoFull}`);
console.log(`[INFO] Engine output: ${engineOutputPath}`);
console.log(`[INFO] Metadata: ${metadataPath}`);
console.log(`[INFO] Parent issue: ${parentIssueNumber || '(auto-detect from engine-output)'}`);
console.log(`[INFO] Dry run: ${dryRun}`);
console.log(`[INFO] Replace parent: ${replaceParent}`);

// ─────────────────────────────────────────────────────────────────────────────
// Load Artifacts
// ─────────────────────────────────────────────────────────────────────────────

if (!fs.existsSync(engineOutputPath)) {
  console.error(`ERROR: Engine output not found: ${engineOutputPath}`);
  console.error('HINT: Run "gitissuer sync --repo ... --dry-run" first to generate artifacts.');
  process.exit(1);
}

const engineOutput = JSON.parse(fs.readFileSync(engineOutputPath, 'utf8'));

let metadata = { tasks: [], subtasks: [] };
if (fs.existsSync(metadataPath)) {
  metadata = JSON.parse(fs.readFileSync(metadataPath, 'utf8'));
} else {
  console.warn(`WARN: Metadata file not found: ${metadataPath}`);
  console.warn('HINT: Will use engine-output only for hierarchy detection.');
}

// ─────────────────────────────────────────────────────────────────────────────
// Build StableId → Issue Mapping
// ─────────────────────────────────────────────────────────────────────────────

function buildStableMap(engineOut) {
  const map = new Map();
  const results = Array.isArray(engineOut?.results) ? engineOut.results : [];
  
  for (const r of results) {
    const tasks = Array.isArray(r?.tasks) ? r.tasks : [];
    for (const t of tasks) {
      if (!t?.stableId) continue;
      
      // Prefer entries that have issueNumber (dry-run produces null)
      const prev = map.get(t.stableId);
      if (!prev || (!prev.issueNumber && t.issueNumber)) {
        map.set(t.stableId, {
          stableId: t.stableId,
          issueNumber: t.issueNumber ?? null,
          issueNodeId: t.issueNodeId ?? null,
          parentStableId: t.parentStableId ?? null,
          isParentPlan: t.isParentPlan ?? false,
        });
      }
    }
  }
  
  return map;
}

const stableMap = buildStableMap(engineOutput);
console.log(`[INFO] Loaded ${stableMap.size} items from engine-output`);

// Auto-detect parent issue from isParentPlan flag if not provided
if (!parentIssueNumber) {
  for (const [, item] of stableMap) {
    if (item.isParentPlan && item.issueNumber) {
      parentIssueNumber = item.issueNumber;
      console.log(`[INFO] Auto-detected parent issue: #${parentIssueNumber}`);
      break;
    }
  }
}

if (!parentIssueNumber) {
  console.error('ERROR: Parent issue number not found.');
  console.error('HINT: Provide --parent-number <n>, set gitissuer.hierarchy.parentIssueNumber in config,');
  console.error('      or ensure the parent plan issue was created (isParentPlan: true).');
  process.exit(1);
}

// ─────────────────────────────────────────────────────────────────────────────
// Build Link Plan
// ─────────────────────────────────────────────────────────────────────────────

const tasks = Array.isArray(metadata.tasks) ? metadata.tasks : [];
const subtasks = Array.isArray(metadata.subtasks) ? metadata.subtasks : [];

const linkPlan = [];

// All top-level tasks become sub-issues of the parent issue
for (const t of tasks) {
  if (!t?.stableId) continue;
  const hit = stableMap.get(t.stableId) || {};
  
  // Skip the parent plan itself
  if (hit.isParentPlan) continue;
  
  linkPlan.push({
    kind: 'task->parent',
    parentType: 'pai',
    parentIssueNumber: parentIssueNumber,
    parentStableId: null,
    childStableId: t.stableId,
    childIssueNumber: hit.issueNumber ?? null,
    childNodeId: hit.issueNodeId ?? null,
  });
}

// All subtasks become sub-issues of their parentStableId
for (const s of subtasks) {
  if (!s?.stableId || !s.parentStableId) continue;
  const child = stableMap.get(s.stableId) || {};
  const parent = stableMap.get(s.parentStableId) || {};
  
  linkPlan.push({
    kind: 'subtask->parent',
    parentType: 'stable',
    parentStableId: s.parentStableId,
    parentIssueNumber: parent.issueNumber ?? null,
    parentNodeId: parent.issueNodeId ?? null,
    childStableId: s.stableId,
    childIssueNumber: child.issueNumber ?? null,
    childNodeId: child.issueNodeId ?? null,
  });
}

// If metadata is empty, fall back to engine-output parentStableId relationships
if (linkPlan.length === 0) {
  console.log('[INFO] No metadata found, building plan from engine-output parentStableId...');
  
  for (const [stableId, item] of stableMap) {
    if (item.isParentPlan) continue;
    
    if (item.parentStableId) {
      const parent = stableMap.get(item.parentStableId) || {};
      linkPlan.push({
        kind: 'child->parent',
        parentType: parent.isParentPlan ? 'pai' : 'stable',
        parentStableId: item.parentStableId,
        parentIssueNumber: parent.isParentPlan ? parentIssueNumber : (parent.issueNumber ?? null),
        parentNodeId: parent.issueNodeId ?? null,
        childStableId: stableId,
        childIssueNumber: item.issueNumber ?? null,
        childNodeId: item.issueNodeId ?? null,
      });
    } else {
      // No parent → link to PAI
      linkPlan.push({
        kind: 'orphan->pai',
        parentType: 'pai',
        parentIssueNumber: parentIssueNumber,
        parentStableId: null,
        childStableId: stableId,
        childIssueNumber: item.issueNumber ?? null,
        childNodeId: item.issueNodeId ?? null,
      });
    }
  }
}

console.log(`[INFO] Link plan: ${linkPlan.length} relationships to process`);

// ─────────────────────────────────────────────────────────────────────────────
// GraphQL Helpers
// ─────────────────────────────────────────────────────────────────────────────

function ghApi(query, variables = {}) {
  const payload = JSON.stringify({ query, variables });
  const escaped = payload.replace(/'/g, "'\\''");
  
  try {
    const result = execSync(`gh api graphql -f query='${escaped}'`, {
      encoding: 'utf8',
      stdio: ['pipe', 'pipe', 'pipe'],
    });
    return JSON.parse(result);
  } catch (err) {
    const stderr = err.stderr?.toString() || '';
    const stdout = err.stdout?.toString() || '';
    console.error(`GraphQL error: ${stderr || stdout}`);
    return null;
  }
}

function ghApiWithVars(query, vars) {
  // Build CLI args for each variable
  const varArgs = Object.entries(vars)
    .map(([k, v]) => {
      if (typeof v === 'number') {
        return `-F ${k}=${v}`;
      } else if (typeof v === 'boolean') {
        return `-F ${k}=${v}`;
      } else {
        return `-f ${k}='${String(v).replace(/'/g, "'\\''")}'`;
      }
    })
    .join(' ');
  
  const escapedQuery = query.replace(/'/g, "'\\''");
  const cmd = `gh api graphql -f query='${escapedQuery}' ${varArgs}`;
  
  try {
    const result = execSync(cmd, {
      encoding: 'utf8',
      stdio: ['pipe', 'pipe', 'pipe'],
    });
    return JSON.parse(result);
  } catch (err) {
    const stderr = err.stderr?.toString() || '';
    const stdout = err.stdout?.toString() || '';
    console.error(`GraphQL error: ${stderr || stdout}`);
    return null;
  }
}

function resolveIssueInfo(issueNumber) {
  const query = `
    query($owner: String!, $repo: String!, $number: Int!) {
      repository(owner: $owner, name: $repo) {
        issue(number: $number) {
          id
          number
          parent { number }
        }
      }
    }
  `;
  
  const result = ghApiWithVars(query, { owner, repo, number: issueNumber });
  const issue = result?.data?.repository?.issue;
  return {
    id: issue?.id ?? null,
    number: issue?.number ?? issueNumber,
    parentNumber: issue?.parent?.number ?? null,
  };
}

function addSubIssue(parentNodeId, childNodeId, replaceParentFlag) {
  const query = `
    mutation($issueId: ID!, $subIssueId: ID!, $replaceParent: Boolean) {
      addSubIssue(input: {issueId: $issueId, subIssueId: $subIssueId, replaceParent: $replaceParent}) {
        issue { number }
        subIssue { number }
      }
    }
  `;
  
  const escaped = query.replace(/'/g, "'\\''");
  const replaceVal = replaceParentFlag ? 'true' : 'false';
  const cmd = `gh api graphql -f query='${escaped}' -f issueId='${parentNodeId}' -f subIssueId='${childNodeId}' -F replaceParent=${replaceVal}`;
  
  try {
    const result = execSync(cmd, {
      encoding: 'utf8',
      stdio: ['pipe', 'pipe', 'pipe'],
    });
    return JSON.parse(result);
  } catch (err) {
    const stderr = err.stderr?.toString() || '';
    const stdout = err.stdout?.toString() || '';
    // Check if already linked (not an error)
    const combined = `${stderr}\n${stdout}`;
    if (
      combined.includes('already a sub-issue') ||
      combined.includes('Issue may not contain duplicate sub-issues')
    ) {
      return { alreadyLinked: true };
    }
    console.error(`addSubIssue error: ${stderr || stdout}`);
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Execute Link Plan
// ─────────────────────────────────────────────────────────────────────────────

let linkCount = 0;
let skipCount = 0;
let failCount = 0;
let alreadyLinkedCount = 0;

// Cache for node IDs
const nodeIdCache = new Map();

async function resolveNodeIdCached(issueNumber) {
  if (!issueNumber) return null;
  if (nodeIdCache.has(issueNumber)) {
    return nodeIdCache.get(issueNumber);
  }
  const info = resolveIssueInfo(issueNumber);
  if (info?.id) nodeIdCache.set(issueNumber, info.id);
  return info?.id ?? null;
}

// Resolve parent issue node ID upfront
let parentNodeId = null;
if (!dryRun) {
  parentNodeId = resolveIssueInfo(parentIssueNumber)?.id;
  if (!parentNodeId) {
    console.error(`ERROR: Failed to resolve node ID for parent issue #${parentIssueNumber}`);
    process.exit(1);
  }
  console.log(`[INFO] Parent issue node ID: ${parentNodeId}`);
}

console.log('');
console.log('─'.repeat(60));
console.log('  LINKING HIERARCHY');
console.log('─'.repeat(60));
console.log('');

for (const link of linkPlan) {
  const { kind, parentType, parentStableId, childStableId, childIssueNumber, childNodeId } = link;
  let { parentIssueNumber: linkParentNumber, parentNodeId: linkParentNodeId } = link;
  const desiredParentNumber = parentType === 'pai' ? parentIssueNumber : linkParentNumber;
  
  // Skip if child issue number is missing
  if (!childIssueNumber) {
    if (dryRun) {
      console.log(`[DRY-RUN] Would link (missing child issue) stableId=${childStableId?.slice(0, 12)}... kind=${kind}`);
      skipCount++;
    } else {
      console.error(`[FAIL] Missing child issue number for stableId=${childStableId?.slice(0, 12)}... Re-run deploy without --dry-run.`);
      failCount++;
    }
    continue;
  }

  // Never attempt to link an issue as a sub-issue of itself.
  if (desiredParentNumber && childIssueNumber === desiredParentNumber) {
    if (dryRun) {
      console.log(`[DRY-RUN] Would skip self-link #${childIssueNumber} -> #${desiredParentNumber}`);
    } else {
      console.log(`[SKIP] #${childIssueNumber} self-link avoided`);
    }
    skipCount++;
    continue;
  }
  
  // DRY RUN mode
  if (dryRun) {
    if (parentType === 'pai') {
      console.log(`[DRY-RUN] Would link #${childIssueNumber} as sub-issue of PAI #${parentIssueNumber}`);
    } else {
      console.log(`[DRY-RUN] Would link #${childIssueNumber} as sub-issue of #${linkParentNumber || '?'} (${parentStableId?.slice(0, 12)}...)`);
    }
    linkCount++;
    continue;
  }

  // LIVE mode - resolve node IDs
  let targetParentNodeId = null;
  
  if (parentType === 'pai') {
    targetParentNodeId = parentNodeId;
    linkParentNumber = parentIssueNumber;
  } else {
    // Resolve parent node ID
    if (linkParentNodeId) {
      targetParentNodeId = linkParentNodeId;
    } else if (linkParentNumber) {
      targetParentNodeId = resolveIssueNodeId(linkParentNumber);
    }
    
    if (!targetParentNodeId) {
      console.error(`[FAIL] Cannot resolve parent node ID for #${linkParentNumber} (${parentStableId?.slice(0, 12)}...)`);
      failCount++;
      continue;
    }
  }
  
  // Resolve child node ID
  const childInfo = resolveIssueInfo(childIssueNumber);
  const targetChildNodeId = childNodeId || childInfo?.id;
  
  if (!targetChildNodeId) {
    console.error(`[FAIL] Cannot resolve child node ID for #${childIssueNumber}`);
    failCount++;
    continue;
  }

  // If the child already has a parent:
  // - If it's already the target parent, count as already linked.
  // - If it's a different parent and replaceParent=false, skip.
  if (childInfo?.parentNumber) {
    if (childInfo.parentNumber === linkParentNumber) {
      console.log(`[SKIP] #${childIssueNumber} already linked to #${linkParentNumber}`);
      alreadyLinkedCount++;
      continue;
    }
    if (!replaceParent) {
      console.log(`[SKIP] #${childIssueNumber} already has parent #${childInfo.parentNumber} (use --replace-parent to move)`);
      skipCount++;
      continue;
    }
  }
  
  // Execute addSubIssue mutation
  const result = addSubIssue(targetParentNodeId, targetChildNodeId, replaceParent);
  
  if (result?.alreadyLinked) {
    console.log(`[SKIP] #${childIssueNumber} already linked to #${linkParentNumber}`);
    alreadyLinkedCount++;
  } else if (result?.data?.addSubIssue) {
    console.log(`[OK] Linked #${childIssueNumber} as sub-issue of #${linkParentNumber}`);
    linkCount++;
  } else {
    console.error(`[FAIL] Failed to link #${childIssueNumber} to #${linkParentNumber}`);
    failCount++;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary
// ─────────────────────────────────────────────────────────────────────────────

console.log('');
console.log('─'.repeat(60));
console.log('  SUMMARY');
console.log('─'.repeat(60));
console.log(`  Linked:         ${linkCount}`);
console.log(`  Already linked: ${alreadyLinkedCount}`);
console.log(`  Skipped:        ${skipCount}`);
console.log(`  Failed:         ${failCount}`);
console.log(`  Total:          ${linkPlan.length}`);
console.log('─'.repeat(60));

if (dryRun) {
  console.log('');
  console.log('[INFO] Dry run complete. No changes made.');
  console.log('[INFO] Run with --confirm (via gitissuer sync) to apply changes.');
}

// Exit with error code if there were failures
if (failCount > 0) {
  process.exit(1);
}

console.log('');
console.log('✓ Link hierarchy completed');
