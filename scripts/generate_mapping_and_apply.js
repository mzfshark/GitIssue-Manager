#!/usr/bin/env node
const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');
const readline = require('readline');

function parseArgs() {
  const args = {};
  const a = process.argv.slice(2);
  for (let i = 0; i < a.length; i++) {
    const v = a[i];
    if (v.startsWith('--')) {
      const k = v.slice(2);
      const nxt = a[i + 1];
      if (nxt && !nxt.startsWith('-')) { args[k] = nxt; i++; } else { args[k] = true; }
    } else if (v.startsWith('-')) {
      const k = v.slice(1);
      const nxt = a[i + 1];
      if (nxt && !nxt.startsWith('-')) { args[k] = nxt; i++; } else { args[k] = true; }
    }
  }
  return args;
}

const argv = parseArgs();
const schemaPath = argv.schema || argv.s || 'tmp/Axodus-project-schema.json';
const outputPath = argv.output || argv.o || 'tmp/mapping.json';
const engineOutput = argv.engine || argv.e || null;
const configDir = argv['config-dir'] || argv.c || 'sync-helper/configs';
const repoFilter = argv.repo || argv.r || null;
const selectAll = Boolean(argv.all);
const nonInteractive = Boolean(argv['non-interactive']);

function fileExists(p) {
  try { fs.accessSync(p); return true; } catch (_) { return false; }
}

function readJson(p) {
  return JSON.parse(fs.readFileSync(p, 'utf8'));
}

function ghGraphQL(query) {
  const res = spawnSync('gh', ['api', 'graphql', '-f', `query=${query}`], { encoding: 'utf8' });
  if (res.error) throw res.error;
  if (res.status !== 0) throw new Error(res.stderr || 'gh error');
  return JSON.parse(res.stdout);
}

function listRepoCandidatesFromConfigs(configsDirAbs) {
  if (!fileExists(configsDirAbs)) {
    throw new Error(`Config dir not found: ${configsDirAbs}`);
  }

  const files = fs.readdirSync(configsDirAbs)
    .filter((f) => f.endsWith('.json'))
    .map((f) => path.join(configsDirAbs, f));

  const candidates = [];

  for (const cfgPath of files) {
    let cfg;
    try {
      cfg = readJson(cfgPath);
    } catch (e) {
      candidates.push({
        repo: path.basename(cfgPath, '.json'),
        cfgPath,
        engineOutputPath: null,
        exists: false,
        error: `Invalid JSON: ${e.message}`,
      });
      continue;
    }

    const repo = cfg.repo || (cfg.owner && cfg.repoName ? `${cfg.owner}/${cfg.repoName}` : null);
    const engineOutputPath = cfg.outputs && cfg.outputs.engineOutputPath ? cfg.outputs.engineOutputPath : null;
    const absEngineOutputPath = engineOutputPath ? path.resolve(engineOutputPath) : null;

    candidates.push({
      repo: repo || path.basename(cfgPath, '.json'),
      cfgPath,
      engineOutputPath: absEngineOutputPath,
      exists: absEngineOutputPath ? fileExists(absEngineOutputPath) : false,
      error: null,
    });
  }

  return candidates;
}

function printCandidates(candidates) {
  console.log('\nAvailable repos:');
  for (let i = 0; i < candidates.length; i++) {
    const c = candidates[i];
    const status = c.exists ? 'output:OK' : 'output:MISSING';
    const extra = c.error ? ` (${c.error})` : '';
    console.log(`${String(i + 1).padStart(2, ' ')} ) ${c.repo}  [${status}]${extra}`);
  }
  console.log('');
}

async function promptSelection(candidates) {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  const question = (q) => new Promise((resolve) => rl.question(q, resolve));

  try {
    const answer = String(await question(
      "Select repos by number (comma-separated), 'all', or press Enter to use only outputs that exist: "
    )).trim();

    if (!answer) {
      return candidates.filter((c) => c.exists);
    }
    if (answer.toLowerCase() === 'all') {
      return candidates;
    }

    const nums = answer
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean)
      .map((s) => parseInt(s, 10))
      .filter((n) => Number.isFinite(n) && n >= 1 && n <= candidates.length);

    const uniq = Array.from(new Set(nums));
    return uniq.map((n) => candidates[n - 1]);
  } finally {
    rl.close();
  }
}

async function main() {
  const schema = readJson(path.resolve(schemaPath));
  const projectId = schema.projectId;
  if (!projectId) {
    console.error('Missing schema.projectId in', schemaPath);
    process.exit(2);
  }

  /** @type {{repo:string,cfgPath?:string,engineOutputPath:string,exists:boolean,error?:string|null}[]} */
  let selected = [];

  if (engineOutput) {
    const abs = path.resolve(engineOutput);
    selected = [{ repo: '(engine)', engineOutputPath: abs, exists: fileExists(abs), error: null }];
  } else {
    const configsAbs = path.resolve(configDir);
    let candidates = listRepoCandidatesFromConfigs(configsAbs);
    if (repoFilter) {
      const rf = String(repoFilter).toLowerCase();
      candidates = candidates.filter((c) => String(c.repo).toLowerCase().includes(rf));
    }

    if (candidates.length === 0) {
      console.error('No repos found in', configDir);
      process.exit(2);
    }

    printCandidates(candidates);

    if (nonInteractive || !process.stdin.isTTY) {
      selected = selectAll ? candidates : candidates.filter((c) => c.exists);
    } else {
      selected = selectAll ? candidates : await promptSelection(candidates);
    }
  }

  // Filter out missing outputs unless explicitly selected; still warn.
  const missing = selected.filter((s) => !s.exists);
  if (missing.length) {
    console.warn('Skipping repos with missing engine-output.json:');
    for (const m of missing) console.warn(' -', m.repo, '=>', m.engineOutputPath);
  }

  selected = selected.filter((s) => s.exists);
  if (selected.length === 0) {
    console.log('No engine-output.json files selected. Nothing to do.');
    process.exit(0);
  }

  const mapping = [];

  for (const sel of selected) {
    const engine = readJson(sel.engineOutputPath);
    const results = (engine.results && engine.results[0] && engine.results[0].tasks) || [];

    const stableToProjectItem = {};
    const stableToIssueNode = {};

    for (const r of results) {
      if (r.projectItemId) stableToProjectItem[r.stableId] = r.projectItemId;
      if (r.issueNodeId) stableToIssueNode[r.stableId] = r.issueNodeId;
    }

    for (const r of results) {
      if (!r.parentStableId) continue;
      const parentStable = r.parentStableId;
      const childStable = r.stableId;
      const parentProjectItemId = stableToProjectItem[parentStable];
      if (!parentProjectItemId) {
        console.error('Parent has no projectItemId, skipping:', parentStable, `(repo=${sel.repo})`);
        continue;
      }

      let childProjectItemId = stableToProjectItem[childStable];
      if (!childProjectItemId) {
        const childIssueNode = stableToIssueNode[childStable];
        if (!childIssueNode) {
          console.error('Child has no issue node id, skipping:', childStable, `(repo=${sel.repo})`);
          continue;
        }
        // attach child to project via GraphQL inline mutation
        const gql = `mutation{ addProjectV2ItemById(input:{projectId:\"${projectId}\",contentId:\"${childIssueNode}\"}){ item{ id } } }`;
        try {
          const out = ghGraphQL(gql);
          if (out.errors) {
            console.error('Error adding project item for', childStable, out.errors);
            continue;
          }
          childProjectItemId = out.data && out.data.addProjectV2ItemById && out.data.addProjectV2ItemById.item && out.data.addProjectV2ItemById.item.id;
          if (childProjectItemId) {
            stableToProjectItem[childStable] = childProjectItemId;
            console.log('Attached child', childStable.substring(0, 10), '->', childProjectItemId, `(repo=${sel.repo})`);
          } else {
            console.error('No item id returned when attaching child', childStable, `(repo=${sel.repo})`);
            continue;
          }
        } catch (err) {
          console.error('Failed to add project item for', childStable, err.message || err);
          continue;
        }
      }

      mapping.push({ parentProjectItemId, childProjectItemId });
    }
  }

  if (mapping.length === 0) {
    console.log('No mappings to apply.');
    process.exit(0);
  }

  fs.writeFileSync(path.resolve(outputPath), JSON.stringify(mapping, null, 2), 'utf8');
  console.log('Wrote mapping to', outputPath);

  // call apply_subtasks.sh
  const sh = path.resolve(__dirname, 'apply_subtasks.sh');
  const spawnRes = spawnSync(sh, [path.resolve(schemaPath), path.resolve(outputPath)], { stdio: 'inherit' });
  if (spawnRes.error) {
    console.error('Failed to run apply_subtasks.sh', spawnRes.error);
    process.exit(2);
  }
  process.exit(spawnRes.status || 0);
}

main().catch((e) => {
  console.error('Failed:', e && e.message ? e.message : e);
  process.exit(2);
});
