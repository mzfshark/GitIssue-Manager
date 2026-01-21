#!/usr/bin/env node
const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

function usage() {
  console.error('Usage: register_project_fields.js --owner <OWNER> --number <PROJECT_NUMBER> --out <OUT.json>');
  process.exit(1);
}

function parseArgs() {
  const args = {};
  const a = process.argv.slice(2);
  for (let i = 0; i < a.length; i++) {
    const v = a[i];
    if (v.startsWith('--')) {
      const k = v.slice(2);
      const nxt = a[i + 1];
      if (nxt && !nxt.startsWith('-')) { args[k] = nxt; i++; } else { args[k] = true; }
    } else if (v.startsWith('-')) {
      const k = v.slice(1);
      const nxt = a[i + 1];
      if (nxt && !nxt.startsWith('-')) { args[k] = nxt; i++; } else { args[k] = true; }
    }
  }
  return args;
}

const argv = parseArgs();
const owner = argv.owner || argv.o;
const number = argv.number || argv.n;
const out = argv.out || argv.oout || 'project-schema.json';

if (!owner || !number) usage();

// Precise GraphQL query that lists fields and single-select options
const query = `query{ organization(login:\"${owner}\"){ projectV2(number:${number}){ id fields(first:100){ nodes{ __typename ... on ProjectV2Field{ id name dataType } ... on ProjectV2IterationField{ id name dataType } ... on ProjectV2SingleSelectField{ id name dataType options{ id name } } } } } } }`;

try {
  // Use gh api graphql and parse output
  const cmd = `gh api graphql -f query='${query.replace(/'/g, "'\\'\"")}'`;
  const raw = execSync(cmd, { encoding: 'utf8' });
  const parsed = JSON.parse(raw);
  if (parsed.errors) {
    console.error('GraphQL errors:', JSON.stringify(parsed.errors, null, 2));
    process.exit(2);
  }

  const project = parsed.data && parsed.data.organization && parsed.data.organization.projectV2;
  if (!project) {
    console.error('Project not found in GraphQL response');
    process.exit(3);
  }

  const result = { projectId: project.id, fields: project.fields.nodes };
  const outPath = path.resolve(process.cwd(), out);
  fs.writeFileSync(outPath, JSON.stringify(result, null, 2), 'utf8');
  console.log('Wrote project schema to', outPath);
} catch (err) {
  console.error('Failed to fetch project fields:', err && err.message ? err.message : err);
  process.exit(4);
}
