#!/usr/bin/env node
/*
Client-side preparer:
- Scans Markdown checklists
- Generates tasks/subtasks JSON
- Produces a single engine-input.json that the server-side executor can consume

No external dependencies.
*/

/* eslint-env node */
/* global require, __dirname, process, console */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

function sha1(str) {
  return crypto.createHash('sha1').update(str).digest('hex');
}

function extractExplicitId(text) {
  if (!text) return null;
  const m = String(text).trim().match(/^([A-Za-z]+)[-_](\d{2,})\b/);
  if (!m) return null;
  return `${m[1].toUpperCase()}-${m[2]}`;
}

function computePlanFingerprint(planFiles) {
  const parts = (Array.isArray(planFiles) ? planFiles : [])
    .map((p) => `${p.path}:${p.sha1}`)
    .sort();
  return sha1(parts.join('\n'));
}

/**
 * Extract file-level canonical key from plan content.
 * Looks for [key:...] in the title line (first H1) or first 10 lines.
 */
function extractFileKey(content) {
  const lines = content.split(/\r?\n/).slice(0, 10);
  for (const line of lines) {
    const match = line.match(/\[key:([^\]]+)\]/i);
    if (match) return match[1].trim();
  }
  return null;
}

/**
 * Extract plan title from first H1 heading.
 * Strips inline tags like [key:...], [priority:...], etc.
 */
function extractPlanTitle(content) {
  const match = content.match(/^#\s+(.+)$/m);
  if (!match) return 'Untitled Plan';
  // Remove inline tags
  return match[1].replace(/\[(?:key|estimate|priority|status|start|end|labels?|label):[^\]]+\]/gi, '').trim();
}

/**
 * Extract plan ID from filename (e.g., PLAN_SPRINT_1.md -> PLAN-SPRINT-1).
 */
function extractPlanIdFromFilename(relFile) {
  const basename = path.basename(relFile, '.md');
  // Match patterns like PLAN, PLAN_SPRINT_1, EPIC_001, TASK_oauth2
  const match = basename.match(/^([A-Z]+(?:[-_][A-Z0-9]+)*)/i);
  if (!match) return null;
  return match[1].toUpperCase().replace(/_/g, '-');
}

/**
 * Extract metadata block from plan file header.
 * Parses lines like **Priority:** HIGH, **Status:** In Progress, etc.
 */
function extractPlanMetadata(content) {
  const meta = {};
  const lines = content.split(/\r?\n/).slice(0, 20);
  for (const line of lines) {
    const priorityMatch = line.match(/\*\*Priority:\*\*\s*(.+)/i);
    if (priorityMatch) meta.priority = priorityMatch[1].trim();
    
    const statusMatch = line.match(/\*\*Status:\*\*\s*(.+)/i);
    if (statusMatch) meta.status = statusMatch[1].trim();
    
    const endDateMatch = line.match(/\*\*End Date Goal:\*\*\s*(.+)/i);
    if (endDateMatch) meta.endDate = endDateMatch[1].trim();
    
    const estimateMatch = line.match(/\*\*Estimative Hours:\*\*\s*(\d+)/i);
    if (estimateMatch) meta.estimateHours = parseInt(estimateMatch[1], 10);
  }
  return meta;
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

function resolvePlanFile(absRoot, plansDir, plan) {
  if (!plan) return null;
  const isAbs = path.isAbsolute(plan);
  const candidate = isAbs
    ? plan
    : path.resolve(plansDir, plan);
  if (fs.existsSync(candidate) && fs.statSync(candidate).isFile()) return candidate;
  const fallback = isAbs ? null : path.resolve(absRoot, plan);
  if (fallback && fs.existsSync(fallback) && fs.statSync(fallback).isFile()) return fallback;
  return null;
}

function getPlanFiles(absRoot, selectedPlans, plansDir) {
  const files = [];
  const planPath = path.join(absRoot, 'PLAN.md');
  const resolvedPlansDir = plansDir || path.join(absRoot, 'docs', 'plans');

  if (Array.isArray(selectedPlans) && selectedPlans.length > 0) {
    const missing = [];
    for (const plan of selectedPlans) {
      const resolved = resolvePlanFile(absRoot, resolvedPlansDir, plan);
      if (resolved) files.push(resolved);
      else missing.push(plan);
    }
    if (missing.length) {
      console.error('Selected plan files not found:', missing.join(', '));
      return [];
    }
  } else {
    const fallbackPlanPath = path.join(absRoot, 'docs', 'plans', 'PLAN.md');
    if (fs.existsSync(planPath)) {
      files.push(planPath);
    } else if (fs.existsSync(fallbackPlanPath)) {
      files.push(fallbackPlanPath);
    } else {
      console.warn('PLAN.md not found at:', planPath);
      console.warn('PLAN.md not found at:', fallbackPlanPath);
      return [];
    }
  }

  const linkedFiles = new Set();
  for (const f of files) {
    const linked = extractLinkedMarkdownFiles(f, absRoot);
    for (const lf of linked) linkedFiles.add(lf);
  }

  for (const lf of linkedFiles) files.push(lf);

  return Array.from(new Set(files));
}

function parseTags(text) {
  // Supported inline tags:
  // [estimate:2h] [priority:URGENT] [status:In Progress] [start:2026-01-01] [end:2026-01-31] [labels:plan,backend] [key:01J...]
  const out = { cleaned: text };
  const tagRe = /\[(estimate|priority|status|start|end|label|labels|key):([^\]]+)\]/gi;
  let m;
  while ((m = tagRe.exec(text)) !== null) {
    const key = m[1].toLowerCase();
    const value = m[2].trim();
    if (key === 'estimate') {
      const hm = value.match(/(\d+(?:\.\d+)?)h/i);
      if (hm) out.estimateHours = parseFloat(hm[1]);
    } else if (key === 'key') {
      // Canonical identity key for stable issue mapping. Keep as-is (trimmed).
      // Recommended: ULID/UUID-like token without spaces.
      out.key = value;
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

function parseChecklistWithIndent(content, fileHint) {
  const lines = content.split(/\r?\n/);
  const items = [];
  const headingParents = [];
  const parentPattern = /\b[A-Z]+-\d+\b/;

  const headings = []; // candidates
  const headingStack = []; // { stableId, level, usedAsParent }

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const headingMatch = line.match(/^(#{1,6})\s+(.+)$/);
    if (headingMatch) {
      const headingLevel = headingMatch[1].length;
      const headingText = headingMatch[2].trim();
      while (headingStack.length && headingStack[headingStack.length - 1].level >= headingLevel) {
        headingStack.pop();
      }

      const tags = parseTags(headingText);
      const canonicalKey = tags.key || null;
      const stableId = canonicalKey
        ? sha1(`key:${canonicalKey}`)
        : sha1(`heading:${fileHint || ''}:${headingLevel}:${tags.cleaned}`);

      const h = {
        stableId,
        canonicalKey,
        line: i + 1,
        text: tags.cleaned,
        rawText: headingText,
        level: headingLevel,
        usedAsParent: false,
        isExplicitParent: parentPattern.test(headingText),
        meta: {
          estimateHours: tags.estimateHours,
          priority: tags.priority,
          status: tags.status,
          startDate: tags.startDate,
          endDate: tags.endDate,
          labels: tags.labels,
          key: canonicalKey,
        },
      };

      headings.push(h);
      headingStack.push({ stableId: h.stableId, level: headingLevel, ref: h });
      continue;
    }

    const m = line.match(/^(\s*)[-*]\s+\[( |x|X)\]\s+(.*)$/);
    if (!m) continue;
    const indent = m[1].replace(/\t/g, '    ').length;
    const checked = m[2].toLowerCase() === 'x';
    const rawText = m[3].trim();
    const tags = parseTags(rawText);

    const currentHeading = headingStack.length ? headingStack[headingStack.length - 1].ref : null;
    if (indent === 0 && currentHeading) {
      // Be conservative: only create parent issues for headings that are clearly intended as issue headers.
      // - Explicit IDs like EPIC-001 / TASK-12
      // - Or headings carrying a canonical [key:...] tag
      if (currentHeading.isExplicitParent || currentHeading.canonicalKey) {
        currentHeading.usedAsParent = true;
      }
    }

    items.push({
      indent,
      checked,
      text: tags.cleaned,
      rawText,
      line: i + 1,
      parentHeadingStableId: indent === 0 && currentHeading ? currentHeading.stableId : null,
      meta: {
        estimateHours: tags.estimateHours,
        priority: tags.priority,
        status: tags.status,
        startDate: tags.startDate,
        endDate: tags.endDate,
        labels: tags.labels,
        key: tags.key || null,
      },
    });
  }

  for (const h of headings) {
    if (!h.usedAsParent && !h.isExplicitParent) continue;
    headingParents.push({
      stableId: h.stableId,
      canonicalKey: h.canonicalKey,
      line: h.line,
      text: h.text,
      rawText: h.rawText,
      level: h.level,
      meta: h.meta,
    });
  }

  return { items, headingParents };
}

function mergeLabels(defaultLabels, itemLabels) {
  const combined = [...(defaultLabels || []), ...(itemLabels || [])];
  return Array.from(new Set(combined.map((l) => l.trim()).filter(Boolean)));
}

function buildHierarchy(relFile, content, items, defaults, headingParents, owner) {
  const tasks = [];
  const subtasks = [];
  const stack = []; // { indent, stableId }
  const headingMap = new Map();

  // NEW: Create parent issue from the plan file itself
  const fileKey = extractFileKey(content);
  const planStableId = fileKey
    ? sha1(`key:${fileKey}`)
    : sha1(`file:${relFile}`);
  const planTitle = extractPlanTitle(content);
  const planId = extractPlanIdFromFilename(relFile);
  const planMeta = extractPlanMetadata(content);

  const planTask = {
    stableId: planStableId,
    canonicalKey: fileKey,
    explicitId: planId,
    file: relFile,
    line: 1,
    text: planTitle,
    body: content, // FULL FILE CONTENT
    checked: false,
    labels: mergeLabels(defaults.defaultLabels, ['plan-parent']),
    priority: planMeta.priority || defaults.defaultPriority,
    status: planMeta.status || defaults.defaultStatus,
    startDate: defaults.defaultStartDate,
    endDate: planMeta.endDate || defaults.defaultEndDate,
    estimateHours: planMeta.estimateHours || 0,
    isParentPlan: true, // FLAG: this is a parent plan issue
    assignee: owner || null, // AUTO-ASSIGN to owner
  };

  tasks.push(planTask);
  headingMap.set(planStableId, planTask);

  // Process heading parents (sections like EPIC-001, TASK-001)
  for (const heading of headingParents || []) {
    // Avoid duplicating the plan parent: if the first H1 heading carries the same canonical key,
    // it will hash to the same stableId as the file-level plan task.
    // That would create a subtask whose parentStableId is itself, leading to self-link attempts.
    if (heading?.stableId === planStableId) {
      continue;
    }

    const labels = mergeLabels(defaults.defaultLabels, heading.meta.labels);
    const priority = heading.meta.priority ?? defaults.defaultPriority;
    const status = heading.meta.status ?? defaults.defaultStatus;
    const startDate = heading.meta.startDate ?? defaults.defaultStartDate;
    const endDate = heading.meta.endDate ?? defaults.defaultEndDate;
    const estimateHours = heading.meta.estimateHours ?? defaults.defaultEstimateHours;

    const base = {
      stableId: heading.stableId,
      canonicalKey: heading.canonicalKey || heading.meta && heading.meta.key || null,
      explicitId: extractExplicitId(heading.rawText) || extractExplicitId(heading.text),
      file: relFile,
      line: heading.line,
      text: heading.text,
      checked: false,
      labels,
      priority,
      status,
      startDate,
      endDate,
      estimateHours,
      parentStableId: planStableId, // Link heading sections to plan parent
    };

    // Heading sections become subtasks of the plan parent
    subtasks.push(base);
    headingMap.set(heading.stableId, base);
  }

  for (const it of items) {
    const canonicalKey = it.meta && it.meta.key ? it.meta.key : null;
    const stableId = canonicalKey ? sha1(`key:${canonicalKey}`) : sha1(`${relFile}:${it.line}:${it.rawText}`);

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
      canonicalKey,
      explicitId: extractExplicitId(it.rawText) || extractExplicitId(it.text),
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

    const headingParent = (!parent && it.parentHeadingStableId && headingMap.has(it.parentHeadingStableId))
      ? { stableId: it.parentHeadingStableId }
      : null;

    // All items become subtasks - either under their heading parent, indent parent, or the plan parent
    const effectiveParentStableId = (parent || headingParent)
      ? (parent || headingParent).stableId
      : planStableId; // Default to plan parent

    subtasks.push({ ...base, parentStableId: effectiveParentStableId });

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
  const planIndex = args.indexOf('--plan');
  const planArg = (planIndex >= 0 && args[planIndex + 1]) ? args[planIndex + 1] : '';
  const plansIndex = args.indexOf('--plans');
  const plansArg = (plansIndex >= 0 && args[plansIndex + 1]) ? args[plansIndex + 1] : '';
  const plansDirIndex = args.indexOf('--plans-dir');
  const plansDirArg = (plansDirIndex >= 0 && args[plansDirIndex + 1]) ? args[plansDirIndex + 1] : '';
  const selectedPlans = [];
  if (plansArg) {
    selectedPlans.push(...plansArg.split(',').map((p) => p.trim()).filter(Boolean));
  }
  if (planArg) {
    selectedPlans.push(planArg.trim());
  }

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

    const plansDir = plansDirArg ? path.resolve(outBaseDir, plansDirArg) : '';
    const mdFiles = getPlanFiles(absRoot, selectedPlans, plansDir);
    if (!mdFiles.length) {
      console.warn('No PLAN.md or linked files found for:', target.repo);
      continue;
    }
    let tasks = [];
    let subtasks = [];

    for (const f of mdFiles) {
      const relFile = path.relative(absRoot, f).replace(/\\/g, '/');
      const content = fs.readFileSync(f, 'utf8');
      const parsed = parseChecklistWithIndent(content, relFile);
      if (!parsed.items.length && (!parsed.headingParents || !parsed.headingParents.length)) continue;
      const built = buildHierarchy(relFile, content, parsed.items, defaults, parsed.headingParents, cfg.owner);
      tasks = tasks.concat(built.tasks);
      subtasks = subtasks.concat(built.subtasks);
      if (built.tasks.length === 1 && built.subtasks.length === 0) {
        console.warn('No subtasks detected for:', relFile);
        console.warn('Tip: Add checklist items (- [ ] task) to the plan file.');
      }
    }

    sumSubtaskEstimates(tasks, subtasks, defaults.defaultEstimateHours);

    writeJson(path.resolve(outBaseDir, tasksPath), tasks);
    writeJson(path.resolve(outBaseDir, subtasksPath), subtasks);

    const planFiles = mdFiles.map((f) => ({
      path: path.relative(absRoot, f).replace(/\\/g, '/'),
      absPath: f,
      sha1: sha1(fs.readFileSync(f, 'utf8')),
    }));
    const planFingerprint = computePlanFingerprint(planFiles);

    engine.targets.push({
      repo: target.repo,
      localPath,
      planFiles,
      planFingerprint,
      enableProjectSync: !!target.enableProjectSync,
      tasks,
      subtasks,
    });

    // Write engine input in the GitIssue-Manager repo (cwd) so the executor can always find it.
    writeJson(path.resolve(outBaseDir, engineInputPath), engine);

    // Build and write metadata file for this target
    const metadataPath = out.metadataPath || path.join(path.dirname(tasksPath), 'metadata.json');
    const allowedLabels = Array.isArray(cfg.labels && cfg.labels.allowed) ? cfg.labels.allowed : [];
    const metadata = {
      generatedAt: new Date().toISOString(),
      repo: target.repo,
      planFiles,
      labels: {
        allowed: allowedLabels,
        source: (cfg.labels && cfg.labels.source) ? cfg.labels.source : '',
      },
      project: cfg.project || { url: '', number: 0, fieldIds: {} },
      timing: cfg.timing || { afterPaiSeconds: 0, afterChildrenSeconds: 0, afterLinkSeconds: 0 },
      validation: {
        enforceLabelAllowlist: (cfg.validation && typeof cfg.validation.enforceLabelAllowlist === 'boolean')
          ? cfg.validation.enforceLabelAllowlist
          : allowedLabels.length > 0,
        enforceNoOrphans: (cfg.validation && typeof cfg.validation.enforceNoOrphans === 'boolean')
          ? cfg.validation.enforceNoOrphans
          : false,
        enforcePaiContentMatch: (cfg.validation && typeof cfg.validation.enforcePaiContentMatch === 'boolean')
          ? cfg.validation.enforcePaiContentMatch
          : true,
      },
      defaults: {
        defaultEstimateHours: defaults.defaultEstimateHours,
        defaultPriority: defaults.defaultPriority,
        defaultStatus: defaults.defaultStatus,
        defaultStartDate: defaults.defaultStartDate,
        defaultEndDate: defaults.defaultEndDate,
        defaultLabels: defaults.defaultLabels,
      },
      tasks: tasks.map((t) => ({
        stableId: t.stableId,
        canonicalKey: t.canonicalKey || null,
        explicitId: t.explicitId || null,
        file: t.file,
        line: t.line,
        text: t.text,
        checked: t.checked,
        labels: t.labels,
        priority: t.priority,
        status: t.status,
        startDate: t.startDate,
        endDate: t.endDate,
        estimateHours: t.estimateHours,
      })),
      subtasks: subtasks.map((s) => ({
        stableId: s.stableId,
        canonicalKey: s.canonicalKey || null,
        explicitId: s.explicitId || null,
        parentStableId: s.parentStableId,
        file: s.file,
        line: s.line,
        text: s.text,
        checked: s.checked,
        labels: s.labels,
        priority: s.priority,
        status: s.status,
        startDate: s.startDate,
        endDate: s.endDate,
        estimateHours: s.estimateHours,
      })),
    };

    writeJson(path.resolve(outBaseDir, metadataPath), metadata);

    console.log('Prepared:', target.repo);
    console.log('  tasks:', tasks.length, 'subtasks:', subtasks.length);
    console.log('  outputs:', tasksPath, subtasksPath, engineInputPath);
  }
}

main();
