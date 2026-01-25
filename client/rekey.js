#!/usr/bin/env node
/* eslint-env node */
/* global require, __dirname, process, console */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const CROCKFORD_BASE32 = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

function usage() {
  // Intentionally no shell interpolation here.
  console.log(`Usage: node client/rekey.js --config <path> [--plan <file>|--plans <csv>] [--plans-dir <path>] (--dry-run|--confirm)

Injects missing [key:<ULID>] tags into Markdown planning files (headings with TYPE-NNN and checklist items).

Options:
  --config <path>       Repo config (sync-helper/configs/<owner>-<repo>.json or repo-local .gitissuer/gitissuer.sync.json)
  --plan <file>         Single plan file (relative to repo root or docs/plans)
  --plans <csv>         Multiple plan files (comma-separated)
  --plans-dir <path>    Override plans dir (default: <repo>/docs/plans)
  --dry-run             Print intended edits only (no file writes)
  --confirm             Apply edits in place
`);
}

function readJson(p) {
  return JSON.parse(fs.readFileSync(p, 'utf8'));
}

function hasDotSegment(relPath) {
  return relPath.split(/[\\/]/).some((seg) => seg.startsWith('.'));
}

function extractLinkedMarkdownFiles(planPath, absRoot) {
  const content = fs.readFileSync(planPath, 'utf8');
  const links = new Set();
  const linkRe = /\[[^\]]*\]\(([^)]+)\)/g;
  let match;

  while ((match = linkRe.exec(content)) !== null) {
    let link = match[1].trim();
    if (!link || link.startsWith('http://') || link.startsWith('https://') || link.startsWith('mailto:') || link.startsWith('#')) {
      continue;
    }
    link = link.split('#')[0];
    if (!link || !link.toLowerCase().endsWith('.md')) continue;

    const resolved = path.resolve(path.dirname(planPath), link);
    const rel = path.relative(absRoot, resolved);
    if (rel.startsWith('..')) continue;
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
  const candidate = isAbs ? plan : path.resolve(plansDir, plan);
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

function loadConfig(cfgPath) {
  const cfg = readJson(cfgPath);

  let targets;
  if (Array.isArray(cfg.targets)) {
    targets = cfg.targets;
  } else if (cfg.repo) {
    targets = [{
      repo: cfg.repo,
      localPath: cfg.localPath || '.',
      enableProjectSync: !!cfg.enableProjectSync,
      outputs: cfg.outputs || {},
    }];
  } else {
    throw new Error('Config must have either a targets array or repo field');
  }

  if (!targets.length) {
    throw new Error('Config must have at least one target');
  }

  return { cfg, targets };
}

function encodeTime(timeMs) {
  let t = timeMs;
  const out = new Array(10);
  for (let i = 9; i >= 0; i--) {
    out[i] = CROCKFORD_BASE32[t % 32];
    t = Math.floor(t / 32);
  }
  return out.join('');
}

function randomBase32Values(count) {
  // count=16 => 80 bits
  const bytes = crypto.randomBytes(10);
  const out = [];
  let buffer = 0;
  let bufferBits = 0;

  for (const b of bytes) {
    buffer = (buffer << 8) | b;
    bufferBits += 8;
    while (bufferBits >= 5 && out.length < count) {
      const shift = bufferBits - 5;
      const value = (buffer >> shift) & 31;
      out.push(value);
      bufferBits -= 5;
      buffer = buffer & ((1 << bufferBits) - 1);
    }
  }

  while (out.length < count) out.push(0);
  return out;
}

function incrementBase32Values(values) {
  for (let i = values.length - 1; i >= 0; i--) {
    if (values[i] === 31) {
      values[i] = 0;
      continue;
    }
    values[i] += 1;
    return;
  }
}

function makeUlidFactory() {
  let lastTime = -1;
  let lastRandom = null;

  return function ulid() {
    const now = Date.now();
    const timePart = encodeTime(now);

    let randomValues;
    if (now === lastTime && lastRandom) {
      randomValues = lastRandom.slice();
      incrementBase32Values(randomValues);
    } else {
      randomValues = randomBase32Values(16);
    }

    lastTime = now;
    lastRandom = randomValues;

    const randomPart = randomValues.map((v) => CROCKFORD_BASE32[v]).join('');
    return `${timePart}${randomPart}`;
  };
}

function lineHasKeyTag(text) {
  return /\[key:[^\]]+\]/i.test(text);
}

function lineLooksLikeParentHeading(text) {
  // Matches headings that include something like EPIC-001 / TASK-12 etc.
  return /\b[A-Z]+-\d+\b/.test(text);
}

function injectKeysIntoMarkdown(absRoot, absFile, opts) {
  const original = fs.readFileSync(absFile, 'utf8');
  const newline = original.includes('\r\n') ? '\r\n' : '\n';
  const lines = original.split(/\r?\n/);

  const ulid = makeUlidFactory();
  const changes = [];

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];

    const headingMatch = line.match(/^(#{1,6})\s+(.+)$/);
    if (headingMatch) {
      const headingText = headingMatch[2].trim();
      if (lineLooksLikeParentHeading(headingText) && !lineHasKeyTag(headingText)) {
        const key = ulid();
        lines[i] = `${headingMatch[1]} ${headingText} [key:${key}]`;
        changes.push({
          file: path.relative(absRoot, absFile).replace(/\\/g, '/'),
          line: i + 1,
          kind: 'heading',
          key,
        });
      }
      continue;
    }

    const checklistMatch = line.match(/^(\s*[-*]\s+\[( |x|X)\]\s+)(.*)$/);
    if (!checklistMatch) continue;

    const text = checklistMatch[3].trim();
    if (!text) continue;
    if (lineHasKeyTag(text)) continue;

    const key = ulid();
    lines[i] = `${checklistMatch[1]}${text} [key:${key}]`;
    changes.push({
      file: path.relative(absRoot, absFile).replace(/\\/g, '/'),
      line: i + 1,
      kind: 'checklist',
      key,
    });
  }

  const updated = lines.join(newline);
  const changed = updated !== original;

  if (!changed) {
    return { changed: false, changes: [] };
  }

  if (opts.confirm) {
    fs.writeFileSync(absFile, updated);
  }

  return { changed: true, changes };
}

function main() {
  const args = process.argv.slice(2);

  if (args.includes('-h') || args.includes('--help')) {
    usage();
    process.exit(0);
  }

  const cfgIndex = args.indexOf('--config');
  const cfgPath = (cfgIndex >= 0 && args[cfgIndex + 1]) ? args[cfgIndex + 1] : '';

  const planIndex = args.indexOf('--plan');
  const planArg = (planIndex >= 0 && args[planIndex + 1]) ? args[planIndex + 1] : '';

  const plansIndex = args.indexOf('--plans');
  const plansArg = (plansIndex >= 0 && args[plansIndex + 1]) ? args[plansIndex + 1] : '';

  const plansDirIndex = args.indexOf('--plans-dir');
  const plansDirArg = (plansDirIndex >= 0 && args[plansDirIndex + 1]) ? args[plansDirIndex + 1] : '';

  const dryRun = args.includes('--dry-run');
  const confirm = args.includes('--confirm');

  if (!cfgPath) {
    console.error('ERROR: --config <path> is required');
    usage();
    process.exit(2);
  }

  if (dryRun && confirm) {
    console.error('ERROR: Choose one: --dry-run or --confirm');
    process.exit(2);
  }

  if (!dryRun && !confirm) {
    console.error('ERROR: Refusing to modify files without --confirm (or preview with --dry-run)');
    process.exit(2);
  }

  if (!fs.existsSync(cfgPath)) {
    console.error('ERROR: Config not found:', cfgPath);
    process.exit(2);
  }

  const selectedPlans = [];
  if (plansArg) {
    selectedPlans.push(...plansArg.split(',').map((p) => p.trim()).filter(Boolean));
  }
  if (planArg) {
    selectedPlans.push(planArg.trim());
  }

  // Match prepare.js behavior: resolve localPath relative to where the command is executed.
  const outBaseDir = process.cwd();

  const { targets } = loadConfig(cfgPath);
  const allChanges = [];

  for (const target of targets) {
    const localPath = target.localPath || '.';
    const absRoot = path.resolve(outBaseDir, localPath);

    if (!fs.existsSync(absRoot)) {
      console.error('ERROR: Target localPath does not exist:', absRoot);
      console.error('Expected path:', localPath);
      console.error('Base dir:', outBaseDir);
      process.exit(3);
    }

    const plansDir = plansDirArg ? path.resolve(outBaseDir, plansDirArg) : '';
    const mdFiles = getPlanFiles(absRoot, selectedPlans, plansDir);
    if (!mdFiles.length) {
      console.warn('WARN: No PLAN.md or linked files found for:', target.repo);
      continue;
    }

    console.log(`Target: ${target.repo}`);
    console.log(`  root: ${absRoot}`);

    for (const file of mdFiles) {
      const res = injectKeysIntoMarkdown(absRoot, file, { confirm });
      if (!res.changed) continue;

      for (const ch of res.changes) {
        const prefix = dryRun ? '[DRY-RUN]' : '[OK]';
        console.log(`${prefix} ${ch.file}:${ch.line} add [key:${ch.key}] (${ch.kind})`);
      }
      allChanges.push(...res.changes.map((c) => ({ ...c, repo: target.repo })));
    }
  }

  if (allChanges.length === 0) {
    console.log(dryRun ? 'No missing keys found (dry-run).' : 'No missing keys found.');
  } else {
    console.log(dryRun ? `Would add ${allChanges.length} keys.` : `Added ${allChanges.length} keys.`);
  }
}

main();
