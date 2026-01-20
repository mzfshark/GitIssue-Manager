#!/usr/bin/env node
const spawnSync = require('child_process').spawnSync;
const fs = require('fs');
const path = require('path');

function usage() {
  console.error('Usage: apply_subtasks.js --schema <schema.json> --mapping <mapping.json>');
  console.error('mapping.json format: [{"parentProjectItemId":"PVTI_...","childProjectItemId":"PVTI_..."}, ...]');
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
const schemaPath = argv.schema;
const mappingPath = argv.mapping;

if (!schemaPath || !mappingPath) usage();

const schema = JSON.parse(fs.readFileSync(path.resolve(schemaPath), 'utf8'));
const mapping = JSON.parse(fs.readFileSync(path.resolve(mappingPath), 'utf8'));

const projectId = schema.projectId;
const parentField = (schema.fields || []).find(f => f.name && f.name.toLowerCase().includes('parent')) || null;
if (!parentField) {
  console.error('Could not find a "parent" field in schema. Fields present:', (schema.fields || []).map(f=>f.name));
  process.exit(2);
}

const gql = 'mutation($input: UpdateProjectV2ItemFieldValueInput!){ updateProjectV2ItemFieldValue(input:$input){ projectV2Item{ id } } }';

for (const item of mapping) {
  const parentId = item.parentProjectItemId;
  const childId = item.childProjectItemId;
  if (!parentId || !childId) {
    console.error('Skipping invalid mapping entry:', item);
    continue;
  }

  const inputObj = {
    projectId: projectId,
    itemId: childId,
    fieldId: parentField.id,
    // Use contentId to set relationship to the parent project item
    value: { contentId: parentId }
  };

  const args = ['api', 'graphql', '-f', `query=${gql}`, '-f', `input=${JSON.stringify(inputObj)}`];
  const res = spawnSync('gh', args, { encoding: 'utf8' });
  if (res.error) {
    console.error('gh call failed:', res.error);
    continue;
  }
  if (res.status !== 0) {
    console.error('gh returned non-zero status:', res.status, res.stderr);
    continue;
  }

  let parsed;
  try { parsed = JSON.parse(res.stdout); } catch (e) { console.error('Failed to parse gh output', e, res.stdout); continue; }
  if (parsed.errors) {
    console.error('GraphQL errors for mapping', item, parsed.errors);
    continue;
  }
  console.log('Updated child', childId, '-> parent', parentId);
}
