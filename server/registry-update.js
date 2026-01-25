#!/usr/bin/env node
/* eslint-env node */
/* global require, console, process, __dirname */

const fs = require('fs');
const path = require('path');

function readJson(p) {
  return JSON.parse(fs.readFileSync(p, 'utf8')); // nosemgrep
}

function writeJsonAtomic(p, obj) {
  fs.mkdirSync(path.dirname(p), { recursive: true });
  const tmp = `${p}.tmp-${process.pid}`;
  fs.writeFileSync(tmp, JSON.stringify(obj, null, 2)); // nosemgrep
  fs.renameSync(tmp, p);
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

function resolveMaybeRelative(p, baseDir) {
  if (!p) return null;
  const s = String(p);
  if (!s) return null;
  return path.isAbsolute(s) ? s : path.resolve(baseDir, s);
}

function normalizeExplicitId(explicitId) {
  if (!explicitId) return null;
  return String(explicitId).trim().toUpperCase();
}

function indexEngineOutput(engineOutput, repo) {
  const out = new Map();
  const results = Array.isArray(engineOutput && engineOutput.results) ? engineOutput.results : [];
  for (const r of results) {
    if (!r || (repo && r.repo !== repo)) continue;
    const tasks = Array.isArray(r.tasks) ? r.tasks : [];
    for (const t of tasks) {
      if (!t || !t.stableId) continue;
      out.set(String(t.stableId), {
        issueNumber: t.issueNumber ?? null,
        issueNodeId: t.issueNodeId ?? null,
        projectItemId: t.projectItemId ?? null,
      });
    }
  }
  return out;
}

function loadExistingRegistry(registryPath) {
  if (!fs.existsSync(registryPath)) return null; // nosemgrep
  try {
    return readJson(registryPath);
  } catch (e) {
    return null;
  }
}

function mergePreferNonNull(prev, next) {
  if (!prev) return next;
  const merged = { ...prev, ...next };
  for (const k of ['issueNumber', 'issueNodeId', 'issueUrl', 'projectItemId', 'title', 'lastSyncedAt']) {
    if (merged[k] == null && prev[k] != null) merged[k] = prev[k];
  }
  if (prev.source && !merged.source) merged.source = prev.source;
  return merged;
}

function main() {
  const args = process.argv.slice(2);
  const cfgIndex = args.indexOf('--config');
  if (cfgIndex < 0 || !args[cfgIndex + 1]) {
    console.error('Usage: registry-update.js --config <sync-helper/configs/*.json>');
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
    console.error('Refusing to update registry for repo:', repo);
    process.exit(3);
  }

  // Match `client/prepare.js`: output artifacts are written relative to the working directory
  // (typically the GitIssue-Manager repo) so the executor can always find them.
  const outBaseDir = process.cwd();
  const configName = path.basename(configPath, path.extname(configPath));

  // Zero-to-hero: allow missing outputs in config and infer defaults from the repo root.
  // This matches what `prepare` prints: ./tmp/tasks.json ./tmp/subtasks.json ./tmp/engine-input.json
  const repoRootAbsFromCfg = resolveRepoRootAbs(cfg.localPath || '.');
  const inferred = {
    tasksPath: path.join(repoRootAbsFromCfg, 'tmp', 'tasks.json'),
    subtasksPath: path.join(repoRootAbsFromCfg, 'tmp', 'subtasks.json'),
    engineInputPath: path.join(repoRootAbsFromCfg, 'tmp', 'engine-input.json'),
    engineOutputPath: path.join(repoRootAbsFromCfg, 'tmp', 'engine-output.json'),
  };

  // Also support artifacts written into the manager repo under ./tmp/<configName>/...
  // This is the default convention used by configs and the `gitissuer` workflow.
  const inferredManager = {
    engineInputPath: path.join(outBaseDir, 'tmp', configName, 'engine-input.json'),
    engineOutputPath: path.join(outBaseDir, 'tmp', configName, 'engine-output.json'),
  };

  const cfgOutputs = cfg.outputs || {};

  const engineInputPath = resolveMaybeRelative(cfgOutputs.engineInputPath, outBaseDir)
    || resolveMaybeRelative(cfgOutputs.engineInputPath, repoRootAbsFromCfg)
    || (fs.existsSync(inferredManager.engineInputPath) ? inferredManager.engineInputPath : null)
    || (fs.existsSync(inferred.engineInputPath) ? inferred.engineInputPath : null);
  const engineOutputPath = resolveMaybeRelative(cfgOutputs.engineOutputPath, outBaseDir)
    || resolveMaybeRelative(cfgOutputs.engineOutputPath, repoRootAbsFromCfg)
    || (fs.existsSync(inferredManager.engineOutputPath) ? inferredManager.engineOutputPath : null)
    || (fs.existsSync(inferred.engineOutputPath) ? inferred.engineOutputPath : null);

  if (!engineInputPath || !engineOutputPath) {
    console.error('Missing outputs.engineInputPath or outputs.engineOutputPath in config.');
    console.error('Tried inferred paths under repo root:', repoRootAbsFromCfg);
    console.error(' -', inferred.engineInputPath);
    console.error(' -', inferred.engineOutputPath);
    console.error('Tried inferred paths under working directory:', outBaseDir);
    console.error(' -', inferredManager.engineInputPath);
    console.error(' -', inferredManager.engineOutputPath);
    console.error('HINT: Run `gitissuer prepare --repo <owner/name>` and then `gitissuer deploy --dry-run --repo <owner/name>` to generate engine-output.json.');
    process.exit(2);
  }

  if (!fs.existsSync(engineInputPath)) {
    console.error('engine-input.json not found:', engineInputPath);
    process.exit(2);
  }
  if (!fs.existsSync(engineOutputPath)) {
    console.error('engine-output.json not found:', engineOutputPath);
    process.exit(2);
  }

  const engineInput = readJson(engineInputPath);
  const engineOutput = readJson(engineOutputPath);

  const targets = Array.isArray(engineInput && engineInput.targets) ? engineInput.targets : [];
  const target = targets.find((t) => t && t.repo === repo) || targets[0];
  if (!target) {
    console.error('No targets found in engine-input.json for repo:', repo);
    process.exit(2);
  }

  const repoRootAbs = resolveRepoRootAbs(target.localPath || cfg.localPath || '.');
  const registryPath = path.join(repoRootAbs, '.gitissuer', 'registry', 'issue-registry.json');

  const byStable = indexEngineOutput(engineOutput, repo);

  const planFingerprint = target.planFingerprint ?? null;
  const planFiles = Array.isArray(target.planFiles) ? target.planFiles.map((p) => ({ path: p.path, sha1: p.sha1 })) : [];

  const items = [];

  const inputTasks = Array.isArray(target.tasks) ? target.tasks : [];
  const inputSubtasks = Array.isArray(target.subtasks) ? target.subtasks : [];

  for (const t of inputTasks) {
    if (!t || !t.stableId) continue;
    const stableId = String(t.stableId);
    const out = byStable.get(stableId) || {};
    const issueNumber = out.issueNumber ?? null;
    const issueUrl = issueNumber != null ? `https://github.com/${repo}/issues/${issueNumber}` : null;
    items.push({
      stableId,
      explicitId: normalizeExplicitId(t.explicitId),
      kind: 'task',
      issueNumber,
      issueNodeId: out.issueNodeId ?? null,
      issueUrl,
      projectItemId: out.projectItemId ?? null,
      title: t.text || null,
      source: { file: t.file || null, line: t.line || null },
      lastSyncedAt: new Date().toISOString(),
    });
  }

  for (const s of inputSubtasks) {
    if (!s || !s.stableId) continue;
    const stableId = String(s.stableId);
    const out = byStable.get(stableId) || {};
    const issueNumber = out.issueNumber ?? null;
    const issueUrl = issueNumber != null ? `https://github.com/${repo}/issues/${issueNumber}` : null;
    items.push({
      stableId,
      explicitId: normalizeExplicitId(s.explicitId),
      kind: 'subtask',
      issueNumber,
      issueNodeId: out.issueNodeId ?? null,
      issueUrl,
      projectItemId: out.projectItemId ?? null,
      title: s.text || null,
      source: { file: s.file || null, line: s.line || null },
      lastSyncedAt: new Date().toISOString(),
    });
  }

  const prevRegistry = loadExistingRegistry(registryPath);
  const prevItems = Array.isArray(prevRegistry && prevRegistry.items) ? prevRegistry.items : [];
  const prevByStable = new Map(prevItems.filter((x) => x && x.stableId).map((x) => [String(x.stableId), x]));

  const mergedItems = items.map((x) => mergePreferNonNull(prevByStable.get(x.stableId), x));

  const registry = {
    version: '1.0',
    repo,
    updatedAt: new Date().toISOString(),
    planFingerprint,
    planFiles,
    items: mergedItems,
  };

  writeJsonAtomic(registryPath, registry);
  console.log('OK: Registry updated:', registryPath);
  console.log('  items:', mergedItems.length);
}

main();
