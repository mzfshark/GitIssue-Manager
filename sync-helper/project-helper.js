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

function extractProjectNumberFromUrl(url) {
  if (!url) return null;
  const m = url.match(/^https:\/\/github\.com\/users\/[^/]+\/projects\/(\d+)(?:$|\/|\?)/);
  return m ? parseInt(m[1], 10) : null;
}

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

  const legacyTasksPath = cfg.tasksPath;
  const legacySubtasksPath = cfg.subtasksPath;
  const targets = Array.isArray(cfg.targets) ? cfg.targets : [];

  function getDefaultEstimateHours() {
    if (cfg.defaults && typeof cfg.defaults.defaultEstimateHours === 'number') return cfg.defaults.defaultEstimateHours;
    if (typeof cfg.defaultEstimateHours === 'number') return cfg.defaultEstimateHours;
    return 1;
  }

  function processOne(tasksPath, subtasksPath) {
    if (!fs.existsSync(tasksPath) || !fs.existsSync(subtasksPath)) {
      console.error('tasks or subtasks file missing:', tasksPath, subtasksPath);
      process.exit(1);
    }

    const tasks = loadJson(tasksPath);
    const subtasks = loadJson(subtasksPath);

    const subsByParent = {};
    for (const s of subtasks) {
      const parent = s.parentStableId || s.parentId || s.parent || s.parent_task || null;
      if (!parent) continue;
      subsByParent[parent] = subsByParent[parent] || [];
      subsByParent[parent].push(s);
    }

    const defaultEstimate = getDefaultEstimateHours();
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
      if (t.estimateHours !== sum) {
        t.estimateHours = sum;
        modified = true;
      }
    }

    if (modified) {
      writeJson(tasksPath, tasks);
      const audit = { updatedAt: new Date().toISOString(), tasksPath, subtasksPath };
      writeJson(path.join(path.dirname(tasksPath), 'tasks-audit.json'), audit);
      console.log('Updated tasks with estimateHours:', tasksPath);
    } else {
      console.log('No updates needed for estimateHours:', tasksPath);
    }

    return tasks;
  }

  // Backward compatibility: if no targets array, use legacy paths.
  if (!targets.length) {
    const tasksPath = legacyTasksPath || './tmp/tasks.json';
    const subtasksPath = legacySubtasksPath || './tmp/subtasks.json';
    const tasks = processOne(tasksPath, subtasksPath);

    if (apply) {
      if (cfg.enableProjectSync === false) {
        console.log('enableProjectSync=false; skipping Project V2 updates');
        process.exit(0);
      }
      await applyProjectUpdates(cfg, tasks);
    }
    return;
  }

  // New config: process each target outputs
  for (const t of targets) {
    const out = t.outputs || {};
    const tasksPath = out.tasksPath || './tmp/tasks.json';
    const subtasksPath = out.subtasksPath || './tmp/subtasks.json';
    const tasks = processOne(tasksPath, subtasksPath);

    if (apply) {
      if (t.enableProjectSync === false) {
        console.log('enableProjectSync=false; skipping Project V2 updates for', t.repo);
        continue;
      }
      await applyProjectUpdates(cfg, tasks);
    }
  }

  return;

}

async function applyProjectUpdates(cfg, tasks) {
  const projectCfg = cfg.project || {};
  const fieldIds = projectCfg.fieldIds || {};

  if (!process.env.GH_PAT) {
    console.error('GH_PAT not found in env; cannot apply to Project');
    process.exit(3);
  }

  const projectNumberFromUrl = extractProjectNumberFromUrl(projectCfg.url);
  const effectiveProjectNumber = projectCfg.number || projectNumberFromUrl;

  if (!effectiveProjectNumber && !cfg.projectNodeId) {
    console.error('No project number (or projectNodeId) in config; cannot apply');
    process.exit(4);
  }

  let projectNodeId = cfg.projectNodeId;
  if (!projectNodeId && effectiveProjectNumber) {
    console.log('Resolving project node id for project number', effectiveProjectNumber);
    const q = `query($number:Int!){ viewer{ projectV2(number:$number){ id } } }`;
    const vars = JSON.stringify({ number: effectiveProjectNumber });
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

  const estimateFieldId = fieldIds.estimateHoursFieldId;
  if (!estimateFieldId) {
    console.error('No estimateHoursFieldId in config; skipping project updates');
    return;
  }

  for (const t of tasks) {
    if (!t.resourceId) {
      console.log('Task has no resourceId (not attached to project), skipping:', t.title || t.text || t.stableId);
      continue;
    }
    const itemId = t.resourceId;
    const value = { number: t.estimateHours };
    const mutation = `mutation($input: UpdateProjectV2ItemFieldValueInput!){ updateProjectV2ItemFieldValue(input:$input){ projectV2Item{ id } } }`;
    const variables = { input: { projectId: projectNodeId, itemId, fieldId: estimateFieldId, value } };
    const cmd = `gh api graphql -f query="${mutation.replace(/"/g,'\"')}" -f variables='${JSON.stringify(variables)}'`;
    console.log('Updating project item estimateHours for item', itemId, '->', t.estimateHours);
    try {
      execSync(cmd, { env: process.env, stdio: ['pipe','pipe','pipe'] }).toString();
    } catch (e) {
      console.error('Failed to update project item:', e.message);
    }
  }
}

main().catch(e=>{ console.error(e); process.exit(99); });
