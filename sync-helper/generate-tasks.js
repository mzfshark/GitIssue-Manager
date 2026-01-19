#!/usr/bin/env node
const fs = require('fs');
const path = require('path');

function isMarkdown(file) { return file.toLowerCase().endsWith('.md'); }

function walk(dir, files=[]) {
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  for (const e of entries) {
    if (e.name === 'node_modules' || e.name === '.git' || e.name === 'tmp' || e.name === 'dist' || e.name === 'artifacts') continue;
    const full = path.join(dir, e.name);
    if (e.isDirectory()) walk(full, files);
    else if (e.isFile() && isMarkdown(e.name)) files.push(full);
  }
  return files;
}

function sha1(str) {
  const crypto = require('crypto');
  return crypto.createHash('sha1').update(str).digest('hex');
}

function parseChecklist(content) {
  const lines = content.split(/\r?\n/);
  const items = [];
  for (let i = 0; i < lines.length; i++) {
    const m = lines[i].match(/^\s*[-*]\s+\[( |x|X)\]\s+(.*)$/);
    if (m) {
      items.push({ text: m[2].trim(), checked: m[1].toLowerCase() === 'x', line: i+1 });
    }
  }
  return items;
}

function main() {
  const repoRoot = process.cwd();
  const mdFiles = walk(repoRoot);
  const tasks = [];
  const subtasks = [];

  for (const f of mdFiles) {
    try {
      const rel = path.relative(repoRoot, f);
      const content = fs.readFileSync(f, 'utf8');
      const items = parseChecklist(content);
      if (!items.length) continue;
      for (let i = 0; i < items.length; i++) {
        const it = items[i];
        const isParent = i === 0 || /parent|epic|task/i.test(it.text);
        const id = sha1(`${rel}:${it.line}:${it.text}`);
        const obj = { stableId: id, file: rel, line: it.line, text: it.text, checked: it.checked };
        if (isParent) tasks.push(obj);
        else subtasks.push(Object.assign({}, obj, { parentStableId: tasks.length ? tasks[tasks.length-1].stableId : null }));
      }
    } catch (e) {
      console.error('skip', f, e.message);
    }
  }

  const tmpdir = path.join(repoRoot, 'tmp');
  if (!fs.existsSync(tmpdir)) fs.mkdirSync(tmpdir);
  fs.writeFileSync(path.join(tmpdir, 'tasks.json'), JSON.stringify(tasks, null, 2));
  fs.writeFileSync(path.join(tmpdir, 'subtasks.json'), JSON.stringify(subtasks, null, 2));
  console.log('Wrote', tasks.length, 'tasks and', subtasks.length, 'subtasks to tmp/');
}

main();
