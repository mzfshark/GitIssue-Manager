#!/usr/bin/env node
/* eslint-env node */
/* global require, console, process, __dirname */

const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const UPDATES_BEGIN = '<!-- GITISSUER:UPDATES:BEGIN -->';
const UPDATES_END = '<!-- GITISSUER:UPDATES:END -->';

function readJson(p) {
  return JSON.parse(fs.readFileSync(p, 'utf8')); // nosemgrep
}

function writeTextAtomic(p, text) {
  fs.mkdirSync(path.dirname(p), { recursive: true });
  const tmp = `${p}.tmp-${process.pid}`;
  fs.writeFileSync(tmp, text, 'utf8'); // nosemgrep
  fs.renameSync(tmp, p);
}

function writeJsonAtomic(p, obj) {
  writeTextAtomic(p, JSON.stringify(obj, null, 2));
}

function repoIsAllowed(repo) {
  return repo && (repo.startsWith('mzfshark/') || repo.startsWith('Axodus/'));
}

function resolveRepoRootAbs(localPath) {
  const managerRoot = path.resolve(__dirname, '..');
  if (!localPath) return managerRoot;
  if (path.isAbsolute(localPath)) return localPath;
  return path.resolve(managerRoot, localPath);
}

function normalizeExplicitId(explicitId) {
  if (!explicitId) return null;
  return String(explicitId).trim().toUpperCase();
}

function isLikelyNodeId(value) {
  if (!value) return false;
  const s = String(value).trim();
  if (!s) return false;
  if (/^\d+$/.test(s)) return false;
  return /^[A-Za-z0-9_]{10,}$/.test(s);
}

function ghApi(args) {
  const out = execFileSync('gh', ['api', ...args], { encoding: 'utf8' });
  return out ? JSON.parse(out) : null;
}

function ghApiNoJson(args) {
  return execFileSync('gh', ['api', ...args], { encoding: 'utf8' });
}

function parseEstimateHours(value) {
  if (value == null) return null;
  const s = String(value).trim();
  if (!s) return null;
  const hm = s.match(/^(\d+(?:\.\d+)?)\s*h$/i);
  if (hm) return parseFloat(hm[1]);
  if (/^\d+(?:\.\d+)?$/.test(s)) return parseFloat(s);
  return null;
}

function extractUpdatesSection(text) {
  const start = text.indexOf(UPDATES_BEGIN);
  const end = text.indexOf(UPDATES_END);
  if (start < 0 || end < 0 || end <= start) return null;
  return text.substring(start + UPDATES_BEGIN.length, end);
}

function parseUpdates(markdownText) {
  const section = extractUpdatesSection(markdownText);
  if (section == null) return [];

  const lines = section.split(/\r?\n/);
  const updates = [];

  let current = null;
  let inMultilineComment = false;

  function pushCurrent() {
    if (current) updates.push(current);
    current = null;
    inMultilineComment = false;
  }

  for (let idx = 0; idx < lines.length; idx++) {
    const raw = lines[idx];
    const line = raw.trimEnd();
    const trimmed = line.trim();

    if (!trimmed) continue;
    if (trimmed.startsWith('#')) continue;

    if (trimmed.startsWith('@')) {
      pushCurrent();
      const m = trimmed.match(/^@([^\s]+)\s+(open|reopen|close)\s*$/i);
      if (!m) {
        throw new Error(`Invalid update header at line ${idx + 1}: ${trimmed}`);
      }
      current = {
        inputId: m[1],
        action: m[2].toLowerCase(),
        labels: [],
        comment: null,
        estimateHours: null,
        endDate: null,
      };
      continue;
    }

    if (!current) {
      throw new Error(`Unexpected content outside an update block at line ${idx + 1}: ${trimmed}`);
    }

    if (inMultilineComment) {
      // Any non-key line is part of the multiline comment (indented or not).
      // Stop only when we see a new @block header, handled above.
      current.comment = (current.comment ? `${current.comment}\n` : '') + raw;
      continue;
    }

    const kv = trimmed.match(/^([A-Za-z][A-Za-z0-9_-]*)\s*:\s*(.*)$/);
    if (!kv) {
      throw new Error(`Invalid key/value at line ${idx + 1}: ${trimmed}`);
    }

    const key = kv[1];
    const value = kv[2];

    if (key === 'labels') {
      const parts = value.split(',').map((v) => v.trim()).filter(Boolean);
      current.labels = Array.from(new Set([...(current.labels || []), ...parts]));
    } else if (key === 'comment') {
      if (value.trim() === '|') {
        current.comment = '';
        inMultilineComment = true;
      } else {
        current.comment = value;
      }
    } else if (key === 'estimate') {
      current.estimateHours = parseEstimateHours(value);
      if (current.estimateHours == null) {
        throw new Error(`Invalid estimate value at line ${idx + 1}: ${value}`);
      }
    } else if (key === 'endDate') {
      const v = value.trim();
      if (!/^\d{4}-\d{2}-\d{2}$/.test(v)) {
        throw new Error(`Invalid endDate (expected YYYY-MM-DD) at line ${idx + 1}: ${value}`);
      }
      current.endDate = v;
    } else {
      throw new Error(`Unsupported key '${key}' at line ${idx + 1}`);
    }
  }

  pushCurrent();
  return updates;
}

function loadRegistry(repoRootAbs) {
  const p = path.join(repoRootAbs, '.gitissuer', 'registry', 'issue-registry.json');
  if (!fs.existsSync(p)) {
    throw new Error(`Registry not found: ${p} (run registry-update first)`);
  }
  const reg = readJson(p);
  const items = Array.isArray(reg.items) ? reg.items : [];
  const byStableId = new Map();
  const byExplicitId = new Map();

  for (const it of items) {
    if (!it || !it.stableId) continue;
    byStableId.set(String(it.stableId), it);
    const ex = normalizeExplicitId(it.explicitId);
    if (ex) {
      if (!byExplicitId.has(ex)) byExplicitId.set(ex, it);
    }
  }

  return { path: p, registry: reg, byStableId, byExplicitId };
}

function resolveRegistryItem(reg, inputId) {
  const raw = String(inputId).trim();
  if (!raw) return { item: null, error: 'Empty id' };

  // Prefer direct stableId match.
  if (reg.byStableId.has(raw)) {
    return { item: reg.byStableId.get(raw), error: null };
  }

  const ex = normalizeExplicitId(raw);
  if (ex && reg.byExplicitId.has(ex)) {
    return { item: reg.byExplicitId.get(ex), error: null };
  }

  return { item: null, error: `Unknown id '${raw}' (not found in registry)` };
}

function graphqlMutation(query, variables) {
  const args = ['api', 'graphql', '-f', `query=${query}`];
  for (const [k, v] of Object.entries(variables || {})) {
    args.push('-F', `${k}=${v}`);
  }
  const out = execFileSync('gh', args, { encoding: 'utf8' });
  return JSON.parse(out);
}

function updateProjectNumberField(projectId, itemId, fieldId, value) {
  const q = `mutation($projectId:ID!,$itemId:ID!,$fieldId:ID!,$value:Float!){\n  updateProjectV2ItemFieldValue(input:{projectId:$projectId,itemId:$itemId,fieldId:$fieldId,value:{number:$value}}){\n    projectV2Item{ id }\n  }\n}`;
  graphqlMutation(q, { projectId, itemId, fieldId, value });
}

function updateProjectDateField(projectId, itemId, fieldId, value) {
  const q = `mutation($projectId:ID!,$itemId:ID!,$fieldId:ID!,$value:Date!){\n  updateProjectV2ItemFieldValue(input:{projectId:$projectId,itemId:$itemId,fieldId:$fieldId,value:{date:$value}}){\n    projectV2Item{ id }\n  }\n}`;
  graphqlMutation(q, { projectId, itemId, fieldId, value });
}

function main() {
  const args = process.argv.slice(2);
  const cfgIndex = args.indexOf('--config');
  const fileIndex = args.indexOf('--file');

  const confirm = args.includes('--confirm');
  const dryRun = args.includes('--dry-run') || args.includes('--dryrun') || !confirm;

  if (cfgIndex < 0 || !args[cfgIndex + 1]) {
    console.error('Usage: apply-issue-updates.js --config <sync-helper/configs/*.json> [--file <ISSUE_UPDATES.md>] [--dry-run|--confirm]');
    process.exit(2);
  }

  const configPath = args[cfgIndex + 1];
  if (!fs.existsSync(configPath)) {
    console.error('Config file not found:', configPath);
    process.exit(2);
  }
  const cfg = readJson(configPath);

  const repo = cfg.repo || null;
  if (!repo || !repoIsAllowed(repo)) {
    console.error('Refusing to apply updates for repo:', repo);
    process.exit(3);
  }

  const repoRootAbs = resolveRepoRootAbs(cfg.localPath || '.');

  const updateFilePath = (fileIndex >= 0 && args[fileIndex + 1])
    ? path.resolve(args[fileIndex + 1])
    : path.join(repoRootAbs, 'ISSUE_UPDATES.md');

  if (!fs.existsSync(updateFilePath)) {
    console.error('ISSUE_UPDATES.md not found:', updateFilePath);
    process.exit(2);
  }

  const updateText = fs.readFileSync(updateFilePath, 'utf8');

  let parsedUpdates;
  try {
    parsedUpdates = parseUpdates(updateText);
  } catch (e) {
    console.error('Failed to parse ISSUE_UPDATES section:', e.message);
    process.exit(2);
  }

  const reg = loadRegistry(repoRootAbs);

  const allowedLabels = Array.isArray(cfg.labels && cfg.labels.allowed) ? cfg.labels.allowed : null;

  const report = {
    version: '1.0',
    generatedAt: new Date().toISOString(),
    repo,
    mode: dryRun ? 'dry-run' : 'apply',
    updates: [],
  };

  const ts = new Date().toISOString().replace(/[:.]/g, '').replace('T', '_').replace('Z', 'Z');
  const updatesDir = path.join(repoRootAbs, '.gitissuer', 'updates');
  const reportJsonPath = path.join(updatesDir, `${ts}-apply-report.json`);
  const reportMdPath = path.join(updatesDir, `${ts}-apply-report.md`);

  if (parsedUpdates.length === 0) {
    const md = [
      '# GitIssuer Apply Report',
      '',
      `Repo: ${repo}`,
      `Mode: ${report.mode}`,
      '',
      'No actionable updates found. Add a bounded section:',
      '',
      UPDATES_BEGIN,
      '@PLAN-003 close',
      'labels: type:plan',
      'comment: |',
      '  Example comment',
      UPDATES_END,
      '',
    ].join('\n');
    writeJsonAtomic(reportJsonPath, report);
    writeTextAtomic(reportMdPath, md);
    console.log('OK: No updates to apply. Report written:', reportJsonPath);
    process.exit(0);
  }

  for (const u of parsedUpdates) {
    const entry = {
      inputId: String(u.inputId),
      resolvedStableId: null,
      resolvedIssueNumber: null,
      action: u.action,
      labels: Array.isArray(u.labels) ? u.labels : [],
      comment: u.comment != null ? String(u.comment).trimEnd() : null,
      estimateHours: u.estimateHours ?? null,
      endDate: u.endDate ?? null,
      notes: [],
      status: 'planned',
      error: null,
    };

    const resolved = resolveRegistryItem(reg, u.inputId);
    if (!resolved.item) {
      entry.status = 'failed';
      entry.error = resolved.error;
      report.updates.push(entry);
      break;
    }

    const item = resolved.item;
    entry.resolvedStableId = String(item.stableId);
    entry.resolvedIssueNumber = item.issueNumber ?? null;

    if (item.issueNumber == null) {
      entry.status = 'failed';
      entry.error = 'Registry item has no issueNumber yet (run executor + registry-update first)';
      report.updates.push(entry);
      break;
    }

    const issueNumber = item.issueNumber;

    // Validate labels against allowlist when present.
    if (allowedLabels && entry.labels.length) {
      const invalid = entry.labels.filter((l) => !allowedLabels.includes(l));
      if (invalid.length) {
        entry.status = 'failed';
        entry.error = `Labels not allowed by config: ${invalid.join(', ')}`;
        report.updates.push(entry);
        break;
      }
    }

    if (dryRun) {
      entry.status = 'planned';
      report.updates.push(entry);
      continue;
    }

    try {
      // State transition
      if (entry.action === 'close') {
        ghApiNoJson([`repos/${repo}/issues/${issueNumber}`, '-X', 'PATCH', '-f', 'state=closed']);
      } else {
        ghApiNoJson([`repos/${repo}/issues/${issueNumber}`, '-X', 'PATCH', '-f', 'state=open']);
      }

      // Labels: add-only semantics
      for (const l of entry.labels) {
        ghApiNoJson([`repos/${repo}/issues/${issueNumber}/labels`, '-X', 'POST', '-f', `labels[]=${l}`]);
      }

      // Comment
      if (entry.comment) {
        ghApiNoJson([`repos/${repo}/issues/${issueNumber}/comments`, '-X', 'POST', '-f', `body=${entry.comment}`]);
      }

      // Project fields (best effort)
      const projectId = cfg.project && (cfg.project.projectNodeId || cfg.project.nodeId) ? (cfg.project.projectNodeId || cfg.project.nodeId) : null;
      const fieldIds = cfg.project && cfg.project.fieldIds ? cfg.project.fieldIds : {};
      const estimateFieldId = fieldIds.estimateHoursFieldId || null;
      const endDateFieldId = fieldIds.endDateFieldId || null;

      if ((entry.estimateHours != null || entry.endDate != null) && !item.projectItemId) {
        entry.notes.push('Skipped ProjectV2 updates: missing registry projectItemId.');
      } else if ((entry.estimateHours != null || entry.endDate != null) && !projectId) {
        entry.notes.push('Skipped ProjectV2 updates: missing config project.projectNodeId.');
      } else {
        if (entry.estimateHours != null) {
          if (!isLikelyNodeId(estimateFieldId)) {
            entry.notes.push('Skipped estimateHours update: missing/invalid estimateHoursFieldId.');
          } else {
            updateProjectNumberField(projectId, item.projectItemId, String(estimateFieldId), entry.estimateHours);
          }
        }
        if (entry.endDate != null) {
          if (!isLikelyNodeId(endDateFieldId)) {
            entry.notes.push('Skipped endDate update: missing/invalid endDateFieldId.');
          } else {
            updateProjectDateField(projectId, item.projectItemId, String(endDateFieldId), entry.endDate);
          }
        }
      }

      entry.status = 'applied';
      report.updates.push(entry);
    } catch (e) {
      entry.status = 'failed';
      entry.error = String(e && e.message ? e.message : e).substring(0, 240);
      report.updates.push(entry);
      break;
    }
  }

  const mdLines = [
    '# GitIssuer Apply Report',
    '',
    `Repo: ${repo}`,
    `Mode: ${report.mode}`,
    `Registry: ${reg.path}`,
    '',
    '## Updates',
    '',
  ];

  for (const u of report.updates) {
    const target = u.resolvedIssueNumber != null ? `#${u.resolvedIssueNumber}` : '(unresolved)';
    mdLines.push(`- ${u.status.toUpperCase()}: ${u.action} ${u.inputId} -> ${target}`);
    if (u.error) mdLines.push(`  - Error: ${u.error}`);
    if (u.notes && u.notes.length) mdLines.push(`  - Notes: ${u.notes.join(' | ')}`);
  }

  writeJsonAtomic(reportJsonPath, report);
  writeTextAtomic(reportMdPath, mdLines.join('\n') + '\n');

  console.log('OK: Apply report written:', reportJsonPath);
  if (!dryRun) console.log('OK: Updates applied.');
}

main();
