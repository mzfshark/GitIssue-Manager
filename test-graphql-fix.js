const { execSync } = require('child_process');

// Test the fixed GraphQL query
const query = `query($owner:String!,$number:Int!){ organization(login:$owner){ projectV2(number:$number){ fields(first:100){ nodes{ ... on ProjectV2Field { id name dataType } ... on ProjectV2IterationField { id name dataType } __typename } } } } }`;

try {
  const cmd = `gh api graphql -F query='${query}' -F owner="Axodus" -F number=23`;
  const res = execSync(cmd, { encoding: 'utf8' });
  const parsed = JSON.parse(res);
  
  if (parsed.errors) {
    console.error('❌ ERRORS:', parsed.errors[0].message);
    process.exit(1);
  }
  
  const fields = parsed.data?.organization?.projectV2?.fields?.nodes || [];
  console.log(`✅ SUCCESS: Loaded ${fields.length} fields from project Axodus/23`);
  console.log(`
Fields:
${fields.map(f => `  - ${f.name || f.__typename} (dataType: ${f.dataType || 'N/A'})`).join('\n')}
  `);
} catch (err) {
  console.error('❌ FAILED:', err.message);
  process.exit(1);
}
