#!/usr/bin/env node
// Helper script to list and manage configured repositories

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const CONFIG_DIR = path.join(__dirname, '../sync-helper/configs');

function listConfigs() {
  if (!fs.existsSync(CONFIG_DIR)) {
    console.log('No configurations found. Run: gitissuer config create (or npm run setup)');
    return [];
  }

  const files = fs.readdirSync(CONFIG_DIR).filter(f => f.endsWith('.json'));
  if (!files.length) {
    console.log('No repositories configured yet. Run: gitissuer config create (or npm run setup)');
    return [];
  }

  console.log('\n=== Configured Repositories ===\n');
  
  const configs = [];
  files.forEach((file, idx) => {
    const configPath = path.join(CONFIG_DIR, file);
    try {
      const cfg = JSON.parse(fs.readFileSync(configPath, 'utf8'));
      const name = path.basename(file, '.json');
      configs.push({ name, file, path: configPath, config: cfg });
      
      console.log(`${idx + 1}. ${name}`);
      console.log(`   Repo: ${cfg.repo}`);
      console.log(`   Local: ${cfg.localPath}`);
      console.log(`   Project Sync: ${cfg.enableProjectSync ? 'enabled' : 'disabled'}`);
      console.log(`   Config: ${configPath}`);
      console.log('');
    } catch (e) {
      console.error(`   Error reading ${file}:`, e.message);
    }
  });

  return configs;
}

function showCommands(configName) {
  const configPath = path.join(CONFIG_DIR, `${configName}.json`);
  if (!fs.existsSync(configPath)) {
    console.error(`Config not found: ${configPath}`);
    console.error('Hint: run `gitissuer config list` to see available names, or create one with `gitissuer config create`.');
    process.exitCode = 2;
    return;
  }

  const cfg = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  const repo = cfg.repo || '<owner/name>';
  
  console.log(`\n=== Commands for ${configName} ===\n`);
  console.log('Doctor (what binary/config is being used):');
  console.log('  gitissuer doctor');
  console.log('');
  console.log('Prepare (scan Markdown and generate engine-input.json):');
  console.log(`  gitissuer prepare --repo "${repo}" --config ${configPath}`);
  console.log('');
  console.log('Deploy (dry-run):');
  console.log(`  gitissuer deploy --repo "${repo}" --config ${configPath} --dry-run`);
  console.log('');
  console.log('Deploy (write to GitHub):');
  console.log(`  GITHUB_TOKEN=<token> gitissuer deploy --repo "${repo}" --config ${configPath} --confirm`);
  console.log('');
  console.log('Sync (prepare + deploy + registry:update):');
  console.log(`  gitissuer sync --repo "${repo}" --config ${configPath} --dry-run`);
  console.log(`  GITHUB_TOKEN=<token> gitissuer sync --repo "${repo}" --config ${configPath} --confirm`);
  console.log('');
  console.log('Edit configuration:');
  console.log(`  ${process.env.EDITOR || 'nano'} ${configPath}`);
  console.log('');
}

function main() {
  const args = process.argv.slice(2);
  
  if (args.includes('--help') || args.includes('-h')) {
    console.log('Usage: npm run repos [options]\n');
    console.log('Options:');
    console.log('  --help, -h           Show this help');
    console.log('  --commands <name>    Show commands for a specific repo config');
    console.log('  (no options)         List all configured repositories');
    return;
  }

  if (args.includes('--commands')) {
    const idx = args.indexOf('--commands');
    const name = args[idx + 1];
    if (!name) {
      console.error('Error: --commands requires a config name');
      process.exit(1);
    }
    showCommands(name);
    return;
  }

  // Default: list all configs
  const configs = listConfigs();
  
  if (configs.length > 0) {
    console.log('To see commands for a specific repo:');
    console.log('  npm run repos -- --commands <name>');
    console.log('');
    console.log('To configure a new repository:');
    console.log('  npm run setup');
  }
}

main();
