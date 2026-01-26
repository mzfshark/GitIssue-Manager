#!/usr/bin/env node
/* eslint-env node */
/* global require, console, process */

const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

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

function extractStableIdFromBody(body) {
  if (!body) return null;
  const m = String(body).match(/\bStableId\s*:\s*([0-9a-f]{16,64})\b/i);
  return m ? m[1] : null;
}

function ghApi(args) {
  const out = execFileSync('gh', ['api', ...args], { encoding: 'utf8' });
  return out ? JSON.parse(out) : null;
}

function resolveOutputPath(configPath, cfg, explicitOut) {
  if (explicitOut) {
    return path.isAbsolute(explicitOut) ? explicitOut : path.resolve(process.cwd(), explicitOut);
  }

  const configName = path.basename(configPath, path.extname(configPath));
  const configured = cfg.outputs && cfg.outputs.githubStatePath ? String(cfg.outputs.githubStatePath) : '';
  if (configured) {
    return path.isAbsolute(configured) ? configured : path.resolve(process.cwd(), configured);
  }

  return path.resolve(process.cwd(), 'tmp', configName, 'github-state.json');
}

function main() {
  const args = process.argv.slice(2);
  const cfgIndex = args.indexOf('--config');
  const outIndex = args.indexOf('--output');
  const includeBody = args.includes('--include-body');

  if (cfgIndex < 0 || !args[cfgIndex + 1]) {
    console.error('Usage: preflight-fetch.js --config <sync-helper/configs/*.json> [--output <path>] [--include-body]');
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
    console.error('Refusing to fetch issues for repo:', repo);
    process.exit(3);
  }

  const outputPath = resolveOutputPath(configPath, cfg, (outIndex >= 0 && args[outIndex + 1]) ? args[outIndex + 1] : null);

  const all = [];
  let page = 1;
  while (true) {
    const items = ghApi([
      `repos/${repo}/issues`,
      '-X',
      'GET',
      '-f',
      'state=all',
      '-f',
      'labels=sync-md',
      '-f',
      'per_page=100',
      '-f',
      `page=${page}`,
    ]);

    if (!Array.isArray(items) || items.length === 0) break;

    for (const issue of items) {
      if (!issue || issue.pull_request) continue;
      const stableId = extractStableIdFromBody(issue.body);
      if (!stableId) continue;

      all.push({
        number: issue.number,
        nodeId: issue.node_id || null,
        title: issue.title || null,
        state: issue.state || null,
        updatedAt: issue.updated_at || null,
        createdAt: issue.created_at || null,
        labels: Array.isArray(issue.labels) ? issue.labels.map((l) => (typeof l === 'string' ? l : l.name)).filter(Boolean) : [],
        assignees: Array.isArray(issue.assignees) ? issue.assignees.map((a) => a && a.login).filter(Boolean) : [],
        stableId,
        body: includeBody ? (issue.body || '') : null,
      });
    }

    if (items.length < 100) break;
    page += 1;
  }

  const payload = {
    fetchedAt: new Date().toISOString(),
    repo,
    labelFilter: 'sync-md',
    issues: all,
  };

  writeJsonAtomic(outputPath, payload);
  console.log('OK: Preflight fetch wrote:', outputPath);
  console.log('  repo:', repo);
  console.log('  issues:', all.length);
}

main();
