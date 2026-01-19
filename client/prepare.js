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

function hasDotSegment(relPath) {
  return relPath.split(/[\\/]/).some((seg) => seg.startsWith('.'));
}

function extractLinkedMarkdownFiles(planPath, absRoot) {
  const content = fs.readFileSync(planPath, 'utf8');
  const links = new Set();
  const linkRe = /\[[^\]]*\]\(([^)]+)\)/g;
  let m;
  while ((m = linkRe.exec(content)) !== null) {
    let link = m[1].trim();
    if (!link || link.startsWith('http://') || link.startsWith('https://') || link.startsWith('mailto:') || link.startsWith('#')) {
      continue;
    }
    link = link.split('#')[0];
    if (!link || !link.toLowerCase().endsWith('.md')) continue;
    const resolved = path.resolve(path.dirname(planPath), link);
    const rel = path.relative(absRoot, resolved);
    if (rel.startsWith('..') || path.isAbsolute(rel) && !resolved.startsWith(absRoot)) continue;
    if (hasDotSegment(rel)) continue;
    if (fs.existsSync(resolved) && fs.statSync(resolved).isFile()) {
      links.add(resolved);
    }
  }
  return Array.from(links);
}

function getPlanFiles(absRoot) {
  const planPath = path.join(absRoot, 'PLAN.md');
  if (!fs.existsSync(planPath)) {
    console.warn('PLAN.md not found at:', planPath);
    return [];
  }

  const files = [planPath];
  const linked = extractLinkedMarkdownFiles(planPath, absRoot);
  for (const f of linked) files.push(f);
  return files;
}

function parseTags(text) {
  // Supported inline tags:
  // [estimate:2h] [priority:URGENT] [status:In Progress] [start:2026-01-01] [end:2026-01-31] [labels:plan,backend]
  const out = { cleaned: text };
  const tagRe = /\[(estimate|priority|status|start|end|label|labels):([^\]]+)\]/gi;
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
    } else if (key === 'label' || key === 'labels') {
      const parts = value.split(',').map((v) => v.trim()).filter(Boolean);
      if (parts.length) out.labels = parts;
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
        labels: tags.labels,
      },
    });
  }

  return items;
}

function mergeLabels(defaultLabels, itemLabels) {
  const combined = [...(defaultLabels || []), ...(itemLabels || [])];
  return Array.from(new Set(combined.map((l) => l.trim()).filter(Boolean)));
}

function buildHierarchy(relFile, items, defaults) {
  const tasks = [];
  const subtasks = [];
  const stack = []; // { indent, stableId }

  for (const it of items) {
    const stableId = sha1(`${relFile}:${it.line}:${it.rawText}`);

    while (stack.length && stack[stack.length - 1].indent >= it.indent) stack.pop();
    const parent = stack.length ? stack[stack.length - 1] : null;

    const labels = mergeLabels(defaults.defaultLabels, it.meta.labels);
    const priority = it.meta.priority ?? defaults.defaultPriority;
    const status = it.meta.status ?? (it.checked ? 'DONE' : defaults.defaultStatus);
    const startDate = it.meta.startDate ?? defaults.defaultStartDate;
    const endDate = it.meta.endDate ?? defaults.defaultEndDate;
    const estimateHours = it.meta.estimateHours ?? defaults.defaultEstimateHours;

    const base = {
      stableId,
      file: relFile,
      line: it.line,
      text: it.text,
      checked: it.checked,
      labels,
      priority,
      status,
      startDate,
      endDate,
      estimateHours,
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
  const normalizedDefaults = {
    defaultEstimateHours: typeof defaults.defaultEstimateHours === 'number' ? defaults.defaultEstimateHours : 1,
    defaultPriority: defaults.defaultPriority || 'NORMAL',
    defaultStatus: defaults.defaultStatus || 'TODO',
    defaultStartDate: defaults.defaultStartDate || 'TBD',
    defaultEndDate: defaults.defaultEndDate || 'TBD',
    defaultLabels: Array.isArray(defaults.defaultLabels) && defaults.defaultLabels.length ? defaults.defaultLabels : ['plan'],
  };

  // Support both old format (with targets array) and new format (single repo)
  let targets;
  if (Array.isArray(cfg.targets)) {
    // Old format - multi-target
    targets = cfg.targets;
  } else if (cfg.repo) {
    // New format - single repo config
    targets = [{
      repo: cfg.repo,
      localPath: cfg.localPath || '.',
      enableProjectSync: !!cfg.enableProjectSync,
      outputs: cfg.outputs || {}
    }];
  } else {
    throw new Error('Config must have either a targets array or repo field');
  }

  if (!targets.length) {
    throw new Error('Config must have at least one target');
  }

  return { cfg, defaults: normalizedDefaults, targets };
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

  const { cfg, defaults, targets } = loadConfig(cfgPath);

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

    // Resolve localPath relative to GitIssue-Manager root (outBaseDir)
    const absRoot = path.resolve(outBaseDir, localPath);
    if (!fs.existsSync(absRoot)) {
      console.error('Target localPath does not exist:', absRoot);
      console.error('Expected path:', localPath);
      console.error('Base dir:', outBaseDir);
      process.exit(3);
    }

    const mdFiles = getPlanFiles(absRoot);
    if (!mdFiles.length) {
      console.warn('No PLAN.md or linked files found for:', target.repo);
      continue;
    }
    let tasks = [];
    let subtasks = [];

    for (const f of mdFiles) {
      const content = fs.readFileSync(f, 'utf8');
      const items = parseChecklistWithIndent(content);
      if (!items.length) continue;
      const relFile = path.relative(absRoot, f).replace(/\\/g, '/');
      const built = buildHierarchy(relFile, items, defaults);
      tasks = tasks.concat(built.tasks);
      subtasks = subtasks.concat(built.subtasks);
    }

    sumSubtaskEstimates(tasks, subtasks, defaults.defaultEstimateHours);

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
