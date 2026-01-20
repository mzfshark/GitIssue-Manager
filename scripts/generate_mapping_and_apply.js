#!/usr/bin/env node
const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

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
const engineOutput = argv.engine || argv.e || 'tmp/Axodus-AragonOSX/engine-output.json';

function ghGraphQL(query) {
  const res = spawnSync('gh', ['api', 'graphql', '-f', `query=${query}`], { encoding: 'utf8' });
  if (res.error) throw res.error;
  if (res.status !== 0) throw new Error(res.stderr || 'gh error');
  return JSON.parse(res.stdout);
}

const schema = JSON.parse(fs.readFileSync(path.resolve(schemaPath), 'utf8'));
const engine = JSON.parse(fs.readFileSync(path.resolve(engineOutput), 'utf8'));

const projectId = schema.projectId;
const results = (engine.results && engine.results[0] && engine.results[0].tasks) || [];

const stableToProjectItem = {};
const stableToIssueNode = {};

for (const r of results) {
  if (r.projectItemId) stableToProjectItem[r.stableId] = r.projectItemId;
  if (r.issueNodeId) stableToIssueNode[r.stableId] = r.issueNodeId;
}

const mapping = [];

for (const r of results) {
  if (!r.parentStableId) continue;
  const parentStable = r.parentStableId;
  const childStable = r.stableId;
  const parentProjectItemId = stableToProjectItem[parentStable];
  if (!parentProjectItemId) {
    console.error('Parent has no projectItemId, skipping:', parentStable);
    continue;
  }

  let childProjectItemId = stableToProjectItem[childStable];
  if (!childProjectItemId) {
    const childIssueNode = stableToIssueNode[childStable];
    if (!childIssueNode) { console.error('Child has no issue node id, skipping:', childStable); continue; }
    // attach child to project via GraphQL inline mutation
    const gql = `mutation{ addProjectV2ItemById(input:{projectId:\"${projectId}\",contentId:\"${childIssueNode}\"}){ item{ id } } }`;
    try {
      const out = ghGraphQL(gql);
      if (out.errors) { console.error('Error adding project item for', childStable, out.errors); continue; }
      childProjectItemId = out.data && out.data.addProjectV2ItemById && out.data.addProjectV2ItemById.item && out.data.addProjectV2ItemById.item.id;
      if (childProjectItemId) {
        stableToProjectItem[childStable] = childProjectItemId;
        console.log('Attached child', childStable, '->', childProjectItemId);
      } else {
        console.error('No item id returned when attaching child', childStable);
        continue;
      }
    } catch (err) {
      console.error('Failed to add project item for', childStable, err.message || err);
      continue;
    }
  }

  mapping.push({ parentProjectItemId, childProjectItemId });
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
if (spawnRes.error) { console.error('Failed to run apply_subtasks.sh', spawnRes.error); process.exit(2); }
process.exit(spawnRes.status || 0);
