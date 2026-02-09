#!/usr/bin/env node
/* eslint-env node */
/* global require, process, console */
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

// Blocking sleep utility (works in Node.js): use Atomics.wait on a SharedArrayBuffer
function sleep(ms) {
  try {
    const sab = new SharedArrayBuffer(4);
    const ia = new Int32Array(sab);
    Atomics.wait(ia, 0, 0, ms);
  } catch (e) {
    // Fallback: busy-wait (shouldn't normally happen)
    const end = Date.now() + ms;
    while (Date.now() < end) { /* noop */ }
  }
}

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

// Optional: process a single plan file (basename or path) or auto-process per metadata.planFiles
const planArg = getArg('--plan'); // e.g. PLAN.md or docs/plans/SPRINT_001.md
const batchSize = parseInt(getArg('--batch-size') || process.env.LINK_BATCH_SIZE || '10', 10);
const delayMs = parseInt(getArg('--delay-ms') || process.env.LINK_DELAY_MS || '5000', 10);
const maxRetries = parseInt(getArg('--max-retries') || process.env.LINK_MAX_RETRIES || '5', 10);
const maxBackoffMs = parseInt(getArg('--max-backoff-ms') || process.env.LINK_MAX_BACKOFF_MS || '60000', 10);
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
console.log(`[INFO] Batch size: ${batchSize}, delay-ms: ${delayMs}, max-retries: ${maxRetries}`);

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

// Auto-detect parent issue from isParentPlan flag if not provided (global fallback)
if (!parentIssueNumber) {
  for (const [, item] of stableMap) {
    if (item.isParentPlan && item.issueNumber) {
      parentIssueNumber = item.issueNumber;
      console.log(`[INFO] Auto-detected parent issue: #${parentIssueNumber}`);
      break;
    }
  }
}

// If caller requested a single plan via --plan, allow per-plan parent detection instead
if (!parentIssueNumber && !planArg) {
  console.error('ERROR: Parent issue number not found.');
  console.error('HINT: Provide --parent-number <n>, set gitissuer.hierarchy.parentIssueNumber in config,');
  console.error('      or ensure the parent plan issue was created (isParentPlan: true).');
  process.exit(1);
}

// ─────────────────────────────────────────────────────────────────────────────
// Build Link Plan (support per-plan processing)
// ─────────────────────────────────────────────────────────────────────────────

const tasks = Array.isArray(metadata.tasks) ? metadata.tasks : [];
const subtasks = Array.isArray(metadata.subtasks) ? metadata.subtasks : [];

function buildLinkPlanForSets(localTasks, localSubtasks, parentNumberForPlan) {
  const lp = [];

  // top-level tasks -> plan parent
  for (const t of localTasks) {
    if (!t?.stableId) continue;
    const hit = stableMap.get(t.stableId) || {};
    if (hit.isParentPlan) continue;
    lp.push({
      kind: 'task->parent',
      parentType: 'pai',
      parentIssueNumber: parentNumberForPlan,
      parentStableId: null,
      childStableId: t.stableId,
      childIssueNumber: hit.issueNumber ?? null,
      childNodeId: hit.issueNodeId ?? null,
    });
  }

  // subtasks -> their parentStableId
  for (const s of localSubtasks) {
    if (!s?.stableId || !s.parentStableId) continue;
    const child = stableMap.get(s.stableId) || {};
    const parent = stableMap.get(s.parentStableId) || {};
    lp.push({
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

  // fallback: if empty, use engine-output parentStableId map for these stableIds
  if (lp.length === 0) {
    for (const [stableId, item] of stableMap) {
      // only include items that belong to localTasks/localSubtasks by stableId
      const belongs = localTasks.find(x => x.stableId === stableId) || localSubtasks.find(x => x.stableId === stableId);
      if (!belongs) continue;
      if (item.isParentPlan) continue;
      if (item.parentStableId) {
        const parent = stableMap.get(item.parentStableId) || {};
        lp.push({
          kind: 'child->parent',
          parentType: parent.isParentPlan ? 'pai' : 'stable',
          parentStableId: item.parentStableId,
          parentIssueNumber: parent.isParentPlan ? parentNumberForPlan : (parent.issueNumber ?? null),
          parentNodeId: parent.issueNodeId ?? null,
          childStableId: stableId,
          childIssueNumber: item.issueNumber ?? null,
          childNodeId: item.issueNodeId ?? null,
        });
      } else {
        lp.push({
          kind: 'orphan->pai',
          parentType: 'pai',
          parentIssueNumber: parentNumberForPlan,
          parentStableId: null,
          childStableId: stableId,
          childIssueNumber: item.issueNumber ?? null,
          childNodeId: item.issueNodeId ?? null,
        });
      }
    }
  }

  return lp;
}

// Helper: execute linking for a built linkPlan under a specific parent
function executeLinkPlanFor(planLabel, linkPlanLocal, parentNumberForPlan) {
  console.log(`[INFO] Plan: ${planLabel} → ${linkPlanLocal.length} relationships to process`);

  // Resolve parent node ID upfront
  let parentNodeIdLocal = null;
  if (!dryRun) {
    if (!parentNumberForPlan) {
      console.error(`[WARN] No parent issue provided for plan ${planLabel}; skipping`);
      return { linked: 0, skipped: 0, failed: 0, already: 0 };
    }
    parentNodeIdLocal = resolveIssueInfo(parentNumberForPlan)?.id;
    if (!parentNodeIdLocal) {
      console.error(`ERROR: Failed to resolve node ID for parent issue #${parentNumberForPlan} (plan ${planLabel})`);
      return { linked: 0, skipped: 0, failed: 1, already: 0 };
    }
    console.log(`[INFO] Parent issue node ID for plan ${planLabel}: ${parentNodeIdLocal}`);
  }

  // Execute the linking loop (similar to main loop below)
  let linkCountLocal = 0;
  let skipCountLocal = 0;
  let failCountLocal = 0;
  let alreadyLinkedCountLocal = 0;

  // Process linkPlanLocal in batches to avoid GitHub API rate limits
  for (let i = 0; i < linkPlanLocal.length; i += batchSize) {
    const batch = linkPlanLocal.slice(i, i + batchSize);
    for (const link of batch) {
      const { kind, parentType, parentStableId, childStableId, childIssueNumber } = link;
      let { parentIssueNumber: linkParentNumber, parentNodeId: linkParentNodeId } = link;
      const desiredParentNumber = parentType === 'pai' ? parentNumberForPlan : linkParentNumber;

      if (!childIssueNumber) {
        if (dryRun) {
          console.log(`[DRY-RUN] Would link (missing child issue) stableId=${childStableId?.slice(0, 12)}... kind=${kind}`);
          skipCountLocal++;
        } else {
          console.error(`[FAIL] Missing child issue number for stableId=${childStableId?.slice(0, 12)}... Re-run deploy without --dry-run.`);
          failCountLocal++;
        }
        continue;
      }

      if (desiredParentNumber && childIssueNumber === desiredParentNumber) {
        if (dryRun) {
          console.log(`[DRY-RUN] Would skip self-link #${childIssueNumber} -> #${desiredParentNumber}`);
        } else {
          console.log(`[SKIP] #${childIssueNumber} self-link avoided`);
        }
        skipCountLocal++;
        continue;
      }

      if (dryRun) {
        if (parentType === 'pai') {
          console.log(`[DRY-RUN] Would link #${childIssueNumber} as sub-issue of PAI #${parentNumberForPlan}`);
        } else {
          console.log(`[DRY-RUN] Would link #${childIssueNumber} as sub-issue of #${linkParentNumber || '?'} (${parentStableId?.slice(0, 12)}...)`);
        }
        linkCountLocal++;
        continue;
      }

      // LIVE mode - resolve parent/child node IDs
      let targetParentNodeId = null;
      if (parentType === 'pai') {
        targetParentNodeId = parentNodeIdLocal;
        linkParentNumber = parentNumberForPlan;
      } else {
        if (linkParentNodeId) {
          targetParentNodeId = linkParentNodeId;
        } else if (linkParentNumber) {
          targetParentNodeId = resolveIssueNodeId(linkParentNumber);
        }
        if (!targetParentNodeId) {
          console.error(`[FAIL] Cannot resolve parent node ID for #${linkParentNumber} (${parentStableId?.slice(0, 12)}...)`);
          failCountLocal++;
          continue;
        }
      }

      const childInfo = resolveIssueInfo(childIssueNumber);
      const targetChildNodeId = link.childNodeId || childInfo?.id;
      if (!targetChildNodeId) {
        console.error(`[FAIL] Cannot resolve child node ID for #${childIssueNumber}`);
        failCountLocal++;
        continue;
      }

      if (childInfo?.parentNumber) {
        if (childInfo.parentNumber === linkParentNumber) {
          console.log(`[SKIP] #${childIssueNumber} already linked to #${linkParentNumber}`);
          alreadyLinkedCountLocal++;
          continue;
        }
        if (!replaceParent) {
          console.log(`[SKIP] #${childIssueNumber} already has parent #${childInfo.parentNumber} (use --replace-parent to move)`);
          skipCountLocal++;
          continue;
        }
      }

      const result = retryAddSubIssue(targetParentNodeId, targetChildNodeId, replaceParent);
      if (result?.alreadyLinked) {
        console.log(`[SKIP] #${childIssueNumber} already linked to #${linkParentNumber}`);
        alreadyLinkedCountLocal++;
      } else if (result?.data?.addSubIssue) {
        console.log(`[OK] Linked #${childIssueNumber} as sub-issue of #${linkParentNumber}`);
        linkCountLocal++;
      } else {
        console.error(`[FAIL] Failed to link #${childIssueNumber} to #${linkParentNumber}`);
        failCountLocal++;
      }
    }

    // Pause between batches to reduce chance of hitting rate limits
    if (i + batchSize < linkPlanLocal.length) {
      try { sleep(delayMs); } catch (e) { /* ignore */ }
    }
  }

  console.log('');
  console.log('─'.repeat(60));
  console.log(`  Plan: ${planLabel} — Linked: ${linkCountLocal}, Already: ${alreadyLinkedCountLocal}, Skipped: ${skipCountLocal}, Failed: ${failCountLocal}`);
  console.log('─'.repeat(60));

  return { linked: linkCountLocal, skipped: skipCountLocal, failed: failCountLocal, already: alreadyLinkedCountLocal };
}

// Determine plan candidates: explicit --plan or metadata.planFiles
let planCandidates = [];
if (planArg) {
  planCandidates = [planArg];
} else if (Array.isArray(metadata.planFiles) && metadata.planFiles.length > 0) {
  planCandidates = metadata.planFiles.map(p => p.path);
}

// If we have planCandidates, process each plan separately; otherwise fall back to global behavior
if (planCandidates.length > 0) {
  let totals = { linked: 0, skipped: 0, failed: 0, already: 0 };
  for (const planPath of planCandidates) {
    const base = path.basename(planPath);
    const tasksForPlan = tasks.filter(t => t.file === planPath || t.file === base);
    const subtasksForPlan = subtasks.filter(s => s.file === planPath || s.file === base);

    if (tasksForPlan.length === 0 && subtasksForPlan.length === 0) {
      console.log(`[INFO] No tasks/subtasks found for plan ${planPath}; skipping`);
      continue;
    }

    // Determine parent issue for this plan: CLI arg (only when --plan used), config fallback, or auto-detect via isParentPlan in stableMap
    let parentForThisPlan = null;
    if (planArg && parentNumberArg) {
      parentForThisPlan = parseInt(parentNumberArg, 10);
    } else if (config.gitissuer?.hierarchy?.parentIssueNumber) {
      parentForThisPlan = config.gitissuer.hierarchy.parentIssueNumber;
    } else {
      // try to find isParentPlan among stableIds in tasksForPlan or detect by metadata markers
      // 1) prefer explicit isParentPlan flag from engine-output
      for (const t of tasksForPlan) {
        const v = stableMap.get(t.stableId);
        if (v && v.isParentPlan && v.issueNumber) {
          parentForThisPlan = v.issueNumber;
          break;
        }
      }

      // 2) look for metadata marker label 'plan-parent' or explicitId starting with 'PLAN'
      if (!parentForThisPlan) {
        for (const t of tasksForPlan) {
          const labels = Array.isArray(t.labels) ? t.labels.map(x => String(x).toLowerCase()) : [];
          const explicit = t.explicitId || '';
          if (labels.includes('plan-parent') || String(explicit).toUpperCase().startsWith('PLAN')) {
            const v = stableMap.get(t.stableId);
            if (v && v.issueNumber) {
              parentForThisPlan = v.issueNumber;
              break;
            }
          }
        }
      }

      // 3) fallback: pick a top-level task from metadata that maps to an issueNumber
      if (!parentForThisPlan && tasksForPlan.length > 0) {
        for (const t of tasksForPlan) {
          const v = stableMap.get(t.stableId);
          if (v && v.issueNumber) {
            parentForThisPlan = v.issueNumber;
            break;
          }
        }
      }
    }

    const linkPlanLocal = buildLinkPlanForSets(tasksForPlan, subtasksForPlan, parentForThisPlan);
    const res = executeLinkPlanFor(planPath, linkPlanLocal, parentForThisPlan);
    totals.linked += res.linked; totals.skipped += res.skipped; totals.failed += res.failed; totals.already += res.already;
  }

  console.log('');
  console.log('[INFO] All plans processed. Totals:', totals);
  if (totals.failed > 0) process.exit(1);
  process.exit(0);
}

// If no planCandidates found, fall back to legacy/global processing below.

// ─────────────────────────────────────────────────────────────────────────────
// Legacy: Build Link Plan (global)
// ─────────────────────────────────────────────────────────────────────────────

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

// `ghApi` was removed because `ghApiWithVars` is used consistently below.

// Helper to resolve node ID synchronously (wrapper around resolveIssueInfo)
function resolveIssueNodeId(issueNumber) {
  const info = resolveIssueInfo(issueNumber);
  return info?.id ?? null;
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
    const message = stderr || stdout || String(err);
    console.error(`addSubIssue error: ${message}`);
    return { error: message };
  }
}

// Retry wrapper for addSubIssue with exponential backoff on transient errors (rate limits)
function retryAddSubIssue(parentNodeId, childNodeId, replaceParentFlag) {
  let attempt = 0;
  let lastResult = null;
  while (attempt < maxRetries) {
    lastResult = addSubIssue(parentNodeId, childNodeId, replaceParentFlag);
    // Success cases
    if (lastResult && (lastResult.alreadyLinked || lastResult.data)) return lastResult;

    // If explicit error message, inspect for rate-limit or transient
    const errMsg = lastResult?.error ? String(lastResult.error).toLowerCase() : '';
    const isRateLimit = errMsg.includes('rate limit') || errMsg.includes('api rate limit') || errMsg.includes('403');
    const isTransient = isRateLimit || errMsg.includes('timeout') || errMsg.includes('temporarily');

    attempt += 1;
    if (attempt >= maxRetries || !isTransient) break;

    const backoff = Math.min((2 ** attempt) * 1000, maxBackoffMs);
    console.warn(`[WARN] addSubIssue transient error detected; retrying in ${backoff}ms (attempt ${attempt}/${maxRetries})`);
    try { sleep(backoff); } catch (e) { /* ignore */ }
  }
  return lastResult;
}

// ─────────────────────────────────────────────────────────────────────────────
// Execute Link Plan
// ─────────────────────────────────────────────────────────────────────────────

let linkCount = 0;
let skipCount = 0;
let failCount = 0;
let alreadyLinkedCount = 0;

// Note: we intentionally do synchronous resolution via `resolveIssueInfo()` in this script.

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
  // Pause briefly between live updates to avoid hitting API rate limits
  try { sleep(5000); } catch (e) { /* ignore sleep errors */ }
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
