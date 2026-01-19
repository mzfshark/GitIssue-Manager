#!/usr/bin/env node
/*
Client-side preparer:
- Scans Markdown checklists
- Generates tasks/subtasks JSON
- Produces a single engine-input.json that the server-side executor can consume

No external dependencies.
*/

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

function sha1(str) {
  return crypto.createHash('sha1').update(str).digest('hex');
}

function readJson(p) {
  return JSON.parse(fs.readFileSync(p, 'utf8'));
}

function writeJson(p, obj) {
  fs.mkdirSync(path.dirname(p), { recursive: true });
  fs.writeFileSync(p, JSON.stringify(obj, null, 2));
}

function walkMarkdown(dir, files = []) {
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  for (const e of entries) {
    if ([
      'node_modules', '.git', 'tmp', 'dist', 'artifacts', 'cache', 'coverage', 'broadcast'
    ].includes(e.name)) continue;
    const full = path.join(dir, e.name);
    if (e.isDirectory()) walkMarkdown(full, files);
    else if (e.isFile() && e.name.toLowerCase().endsWith('.md')) files.push(full);
  }
  return files;
}

function parseTags(text) {
  // Supported inline tags:
  // [estimate:2h] [priority:P1] [status:In Progress] [start:2026-01-01] [end:2026-01-31]
  const out = { cleaned: text };
  const tagRe = /\[(estimate|priority|status|start|end):([^\]]+)\]/gi;
  let m;
  while ((m = tagRe.exec(text)) !== null) {
    const key = m[1].toLowerCase();
    const value = m[2].trim();
    if (key === 'estimate') {
      const hm = value.match(/(\d+(?:\.\d+)?)h/i);
      if (hm) out.estimateHours = parseFloat(hm[1]);
    } else if (key === 'start') {
      out.startDate = value;
    } else if (key === 'end') {
      out.endDate = value;
    } else if (key === 'priority') {
      out.priority = value;
    } else if (key === 'status') {
      out.status = value;
    }
  }
  out.cleaned = text.replace(tagRe, '').replace(/\s{2,}/g, ' ').trim();
  return out;
}

function parseChecklistWithIndent(content) {
  const lines = content.split(/\r?\n/);
  const items = [];

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const m = line.match(/^(\s*)[-*]\s+\[( |x|X)\]\s+(.*)$/);
    if (!m) continue;
    const indent = m[1].replace(/\t/g, '    ').length;
    const checked = m[2].toLowerCase() === 'x';
    const rawText = m[3].trim();
    const tags = parseTags(rawText);
    items.push({
      indent,
      checked,
      text: tags.cleaned,
      rawText,
      line: i + 1,
      meta: {
        estimateHours: tags.estimateHours,
        priority: tags.priority,
        status: tags.status,
        startDate: tags.startDate,
        endDate: tags.endDate,
      },
    });
  }

  return items;
}

function buildHierarchy(relFile, items) {
  const tasks = [];
  const subtasks = [];
  const stack = []; // { indent, stableId }

  for (const it of items) {
    const stableId = sha1(`${relFile}:${it.line}:${it.rawText}`);

    while (stack.length && stack[stack.length - 1].indent >= it.indent) stack.pop();
    const parent = stack.length ? stack[stack.length - 1] : null;

    const base = {
      stableId,
      file: relFile,
      line: it.line,
      text: it.text,
      checked: it.checked,
      labels: [],
      priority: it.meta.priority || null,
      status: it.meta.status || null,
      startDate: it.meta.startDate || null,
      endDate: it.meta.endDate || null,
      estimateHours: it.meta.estimateHours ?? null,
    };

    if (!parent) {
      tasks.push(base);
    } else {
      subtasks.push({ ...base, parentStableId: parent.stableId });
    }

    stack.push({ indent: it.indent, stableId });
  }

  return { tasks, subtasks };
}

function sumSubtaskEstimates(tasks, subtasks, defaultEstimateHours) {
  const subsByParent = new Map();
  for (const s of subtasks) {
    if (!s.parentStableId) continue;
    const list = subsByParent.get(s.parentStableId) || [];
    list.push(s);
    subsByParent.set(s.parentStableId, list);
  }

  for (const t of tasks) {
    const subs = subsByParent.get(t.stableId) || [];
    const sum = subs.reduce((acc, s) => {
      const est = (typeof s.estimateHours === 'number') ? s.estimateHours : defaultEstimateHours;
      return acc + est;
    }, 0);
    t.estimateHours = sum;
  }
}

function loadConfig(cfgPath) {
  const cfg = readJson(cfgPath);
  const defaults = cfg.defaults || {};
  const defaultEstimateHours = typeof defaults.defaultEstimateHours === 'number' ? defaults.defaultEstimateHours : 1;

  const targets = Array.isArray(cfg.targets) ? cfg.targets : [];
  if (!targets.length) {
    throw new Error('Config must have a targets array');
  }

  return { cfg, defaultEstimateHours, targets };
}

function main() {
  const args = process.argv.slice(2);
  const cfgIndex = args.indexOf('--config');
  const cfgPath = (cfgIndex >= 0 && args[cfgIndex + 1]) ? args[cfgIndex + 1] : path.join(__dirname, '../sync-helper/sync-config.json');

  // Output paths are resolved relative to where the command is executed.
  // This keeps all generated artifacts in the GitIssue-Manager repo even when scanning external repos.
  const outBaseDir = process.cwd();

  if (!fs.existsSync(cfgPath)) {
    console.error('Config not found:', cfgPath);
    process.exit(2);
  }

  const { cfg, defaultEstimateHours, targets } = loadConfig(cfgPath);

  const engine = {
    version: '1.0',
    generatedAt: new Date().toISOString(),
    owner: cfg.owner || 'mzfshark',
    project: cfg.project || { url: '', number: 0, fieldIds: {} },
    targets: [],
  };

  for (const target of targets) {
    const localPath = target.localPath || '.';
    const out = target.outputs || {};
    const tasksPath = out.tasksPath || './tmp/tasks.json';
    const subtasksPath = out.subtasksPath || './tmp/subtasks.json';
    const engineInputPath = out.engineInputPath || './tmp/engine-input.json';

    const absRoot = path.resolve(path.dirname(cfgPath), '..', localPath);
    if (!fs.existsSync(absRoot)) {
      console.error('Target localPath does not exist:', absRoot);
      process.exit(3);
    }

    const mdFiles = walkMarkdown(absRoot);
    let tasks = [];
    let subtasks = [];

    for (const f of mdFiles) {
      const content = fs.readFileSync(f, 'utf8');
      const items = parseChecklistWithIndent(content);
      if (!items.length) continue;
      const relFile = path.relative(absRoot, f).replace(/\\/g, '/');
      const built = buildHierarchy(relFile, items);
      tasks = tasks.concat(built.tasks);
      subtasks = subtasks.concat(built.subtasks);
    }

    sumSubtaskEstimates(tasks, subtasks, defaultEstimateHours);

    writeJson(path.resolve(outBaseDir, tasksPath), tasks);
    writeJson(path.resolve(outBaseDir, subtasksPath), subtasks);

    engine.targets.push({
      repo: target.repo,
      enableProjectSync: !!target.enableProjectSync,
      tasks,
      subtasks,
    });

    // Write engine input in the GitIssue-Manager repo (cwd) so the executor can always find it.
    writeJson(path.resolve(outBaseDir, engineInputPath), engine);

    console.log('Prepared:', target.repo);
    console.log('  tasks:', tasks.length, 'subtasks:', subtasks.length);
    console.log('  outputs:', tasksPath, subtasksPath, engineInputPath);
  }
}

main();
