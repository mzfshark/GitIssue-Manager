#!/usr/bin/env node
const fs = require('fs');
const { execSync } = require('child_process');
const path = require('path');

function parseEstimate(text) {
  // look for [1h] or 1h patterns
  const m = text.match(/\[(\d+(?:\.\d+)?)h\]|(?:^|\s)(\d+(?:\.\d+)?)h/);
  if (!m) return null;
  const num = m[1] || m[2];
  return parseFloat(num);
}

function loadJson(p) { return JSON.parse(fs.readFileSync(p, 'utf8')); }
function writeJson(p, obj) { fs.writeFileSync(p, JSON.stringify(obj, null, 2)); }

async function main() {
  // lightweight argv parsing (avoid external deps)
  function parseArgs() {
    const out = {};
    const args = process.argv.slice(2);
    for (let i = 0; i < args.length; i++) {
      const a = args[i];
      if (a === '--config' || a === '-c') {
        out.config = args[i+1]; i++;
      } else if (a === '--apply') {
        out.apply = true;
      } else if (a === '--help' || a === '-h') {
        out.help = true;
      }
    }
    return out;
  }

  const argv = parseArgs();
  const cfgPath = argv.config || path.join(__dirname, 'sync-config.json');
  const apply = !!argv.apply;

  // load .env if GH_PAT not present
  const envPath = path.join(process.cwd(), '.env');
  if (!process.env.GH_PAT && fs.existsSync(envPath)) {
    const envRaw = fs.readFileSync(envPath, 'utf8');
    for (const line of envRaw.split(/\r?\n/)) {
      const m = line.match(/^\s*([A-Za-z_][A-Za-z0-9_]*)=(.*)$/);
      if (!m) continue;
      const key = m[1];
      let val = m[2];
      // strip optional surrounding quotes
      if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) {
        val = val.slice(1, -1);
      }
      if (!process.env[key]) process.env[key] = val;
    }
  }

  if (!fs.existsSync(cfgPath)) {
    console.error('Config not found:', cfgPath);
    process.exit(2);
  }
  const cfg = loadJson(cfgPath);
  const tasksPath = cfg.tasksPath || './tmp/tasks.json';
  const subtasksPath = cfg.subtasksPath || './tmp/subtasks.json';

  if (!fs.existsSync(tasksPath) || !fs.existsSync(subtasksPath)) {
    console.error('tasks or subtasks file missing:', tasksPath, subtasksPath);
    process.exit(1);
  }

  const tasks = loadJson(tasksPath);
  const subtasks = loadJson(subtasksPath);

  // index subtasks by parentStableId or parentId
  const subsByParent = {};
  for (const s of subtasks) {
    const parent = s.parentStableId || s.parentId || s.parent || s.parent_task || null;
    if (!parent) continue;
    subsByParent[parent] = subsByParent[parent] || [];
    subsByParent[parent].push(s);
  }

  const defaultEstimate = cfg.defaultEstimateHours || 1;
  let modified = false;

  for (const t of tasks) {
    const stableId = t.stableId || t.id || t.lineHash || t.hash;
    const subs = subsByParent[stableId] || [];
    let sum = 0;
    for (const s of subs) {
      let est = null;
      if (s.estimateHours) est = parseFloat(s.estimateHours);
      if (s.text) est = est || parseEstimate(s.text);
      if (est == null) est = defaultEstimate;
      sum += est;
    }
    // write back into task
    if (t.estimateHours !== sum) {
      t.estimateHours = sum;
      modified = true;
    }
  }

  if (modified) {
    const outPath = tasksPath;
    writeJson(outPath, tasks);
    const audit = { updatedAt: new Date().toISOString(), tasksPath, subtasksPath };
    writeJson(path.join(path.dirname(outPath), 'tasks-audit.json'), audit);
    console.log('Updated tasks with estimateHours');
  } else {
    console.log('No updates needed for estimateHours');
  }

  if (apply) {
    // Attempt to update Project V2 via gh api graphql if possible
    if (!process.env.GH_PAT) {
      console.error('GH_PAT not found in env; cannot apply to Project');
      process.exit(3);
    }
    if (!cfg.projectNumber && !cfg.projectNodeId) {
      console.error('No projectNumber/projectNodeId in config; cannot apply');
      process.exit(4);
    }

    // Resolve project node id if only projectNumber provided
    let projectNodeId = cfg.projectNodeId;
    if (!projectNodeId && cfg.projectNumber) {
      console.log('Resolving project node id for project number', cfg.projectNumber);
      const q = `query($number:Int!){ viewer{ projectV2(number:$number){ id } } }`;
      const vars = JSON.stringify({ number: cfg.projectNumber });
      const cmd = `gh api graphql -f query="${q.replace(/"/g,'\"')}" -f variables='${vars}'`;
      const out = execSync(cmd, { env: process.env, stdio: ['pipe','pipe','pipe'] }).toString();
      try {
        const json = JSON.parse(out);
        projectNodeId = json.data.viewer.projectV2.id;
      } catch (e) {
        console.error('Failed to resolve project node id:', e.message);
        process.exit(5);
      }
    }

    // For each task, update estimate field if estimateFieldId is provided
    const estimateFieldId = cfg.projectFieldIds && cfg.projectFieldIds.estimateFieldId;
    if (!estimateFieldId) {
      console.error('No estimateFieldId in config; skipping project updates');
      process.exit(0);
    }

    for (const t of tasks) {
      if (!t.resourceId) {
        console.log('Task no resourceId (not attached to project), skipping:', t.title || t.text || t.stableId);
        continue;
      }
      const itemId = t.resourceId; // project item node id
      const value = { number: t.estimateHours };
      const mutation = `mutation($input: UpdateProjectV2ItemFieldValueInput!){ updateProjectV2ItemFieldValue(input:$input){ projectV2Item{ id } } }`;
      const variables = { input: { projectId: projectNodeId, itemId, fieldId: estimateFieldId, value } };
      const varsStr = JSON.stringify(variables).replace(/"/g,'\"');
      const cmd = `gh api graphql -f query="${mutation.replace(/"/g,'\"')}" -f variables='${JSON.stringify(variables)}'`;
      console.log('Updating project item estimate for item', itemId, '->', t.estimateHours);
      try {
        const res = execSync(cmd, { env: process.env, stdio: ['pipe','pipe','pipe'] }).toString();
        console.log('Project update response:', res.slice(0, 200));
      } catch (e) {
        console.error('Failed to update project item:', e.message);
      }
    }
  }
}

main().catch(e=>{ console.error(e); process.exit(99); });
