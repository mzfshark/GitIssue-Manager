#!/usr/bin/env node

/**
 * process-hierarchy.js
 * Process markdown hierarchy and create/update GitHub issues with proper linkage
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// Color output
const colors = {
  reset: '\x1b[0m',
  blue: '\x1b[34m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  red: '\x1b[31m',
};

const log = {
  info: (msg) => console.log(`${colors.blue}ℹ️  ${msg}${colors.reset}`),
  success: (msg) => console.log(`${colors.green}✅ ${msg}${colors.reset}`),
  warn: (msg) => console.log(`${colors.yellow}⚠️  ${msg}${colors.reset}`),
  error: (msg) => console.error(`${colors.red}❌ ${msg}${colors.reset}`),
};

/**
 * Parse markdown file and extract checklist items with hierarchy
 */
function parseMarkdownHierarchy(filePath) {
  if (!fs.existsSync(filePath)) {
    log.error(`File not found: ${filePath}`);
    return [];
  }

  const content = fs.readFileSync(filePath, 'utf-8');
  // Handle both Unix (LF) and Windows (CRLF) line endings
  const lines = content.replace(/\r\n/g, '\n').split('\n');
  const items = [];

  for (const line of lines) {
    // Match checklist items: - [ ] or - [x] (with or without leading spaces)
    const match = line.match(/^(\s*)-\s*\[([x ])\]\s+(.+)$/);
    if (!match) continue;

    const indent = match[1].length;
    const isCompleted = match[2] === 'x';
    const title = match[3];

    // Determine level based on indentation
    const level = Math.floor(indent / 2);

    items.push({
      level,
      title,
      isCompleted,
      indent,
      lineContent: line,
    });
  }

  return items;
}

/**
 * Extract issue number from title if present
 */
function extractIssueNumber(title) {
  const match = title.match(/#(\d+)/);
  return match ? parseInt(match[1]) : null;
}

/**
 * Build hierarchy tree from flat list
 */
function buildHierarchyTree(items) {
  const tree = [];
  const stack = [];

  for (const item of items) {
    // Find parent based on level
    while (stack.length > 0 && stack[stack.length - 1].level >= item.level) {
      stack.pop();
    }

    item.children = [];

    if (stack.length > 0) {
      stack[stack.length - 1].children.push(item);
    } else {
      tree.push(item);
    }

    stack.push(item);
  }

  return tree;
}

/**
 * Generate Progress Tracking markdown from hierarchy
 */
function generateProgressTracking(tree, repo) {
  log.info('Generating Progress Tracking section...');

  let markdown = '## Progress Tracking\n\n';
  markdown += `**Repository:** ${repo}\n`;
  markdown += `**Last Updated:** ${new Date().toISOString().split('T')[0]}\n\n`;

  // Calculate completion percentage
  const allItems = flattenTree(tree);
  const completed = allItems.filter((item) => item.isCompleted).length;
  const percentage = allItems.length > 0 ? Math.round((completed / allItems.length) * 100) : 0;

  markdown += `**Overall Completion:** ${completed}/${allItems.length} (${percentage}%)\n\n`;

  // Build tree structure
  function renderTree(items, depth = 0) {
    let result = '';
    for (const item of items) {
      const indent = '  '.repeat(depth);
      const checkbox = item.isCompleted ? '[x]' : '[ ]';
      const issueNum = extractIssueNumber(item.title);
      const issueLink = issueNum ? `[#${issueNum}](https://github.com/${repo}/issues/${issueNum})` : item.title;

      result += `${indent}- ${checkbox} ${issueLink}\n`;

      if (item.children && item.children.length > 0) {
        result += renderTree(item.children, depth + 1);
      }
    }
    return result;
  }

  markdown += renderTree(tree);
  return markdown;
}

/**
 * Flatten tree for easy traversal
 */
function flattenTree(tree) {
  let items = [];
  for (const item of tree) {
    items.push(item);
    if (item.children && item.children.length > 0) {
      items = items.concat(flattenTree(item.children));
    }
  }
  return items;
}

/**
 * Create or update GitHub issue via gh CLI
 */
function createOrUpdateIssue(repo, issueTitle, issueBody, labels) {
  try {
    // Check if issue exists by searching for similar title
    const searchResult = execSync(
      `gh issue list --repo ${repo} --search "${issueTitle}" --json number`,
      { encoding: 'utf-8' }
    );
    const existing = JSON.parse(searchResult);

    if (existing.length > 0) {
      log.warn(`Issue already exists: #${existing[0].number}`);
      return existing[0].number;
    }

    // Create new issue
    const labelFlags = labels.length > 0 ? `--label "${labels.join(',')}"` : '';
    const createCmd = `gh issue create --repo ${repo} --title "${issueTitle}" --body "${issueBody}" ${labelFlags}`;

    const result = execSync(createCmd, { encoding: 'utf-8' });
    const issueNum = result.match(/#(\d+)/)[1];

    log.success(`Created issue #${issueNum}`);
    return parseInt(issueNum);
  } catch (error) {
    log.error(`Failed to create/update issue: ${error.message}`);
    return null;
  }
}

/**
 * Link parent and child issues
 */
function linkIssues(repo, parentIssueNum, childIssueNum) {
  try {
    execSync(`gh issue link ${parentIssueNum} --repo ${repo} ${childIssueNum}`, {
      stdio: 'ignore',
    });
    log.success(`Linked #${childIssueNum} to #${parentIssueNum}`);
  } catch (error) {
    log.warn(`Failed to link issues: ${error.message}`);
  }
}

/**
 * Update parent issue with progress tracking
 */
function updateParentIssueBody(repo, parentIssueNum, originalBody, progressTracking) {
  try {
    const updatedBody = originalBody + '\n\n---\n\n' + progressTracking;
    const escapedBody = updatedBody.replace(/"/g, '\\"').replace(/\n/g, '\\n');

    execSync(
      `gh issue edit ${parentIssueNum} --repo ${repo} --body "${escapedBody}"`,
      { stdio: 'ignore' }
    );

    log.success(`Updated issue #${parentIssueNum} with Progress Tracking`);
  } catch (error) {
    log.warn(`Failed to update parent issue body: ${error.message}`);
  }
}

/**
 * Main process
 */
function main() {
  const repoPath = process.argv[2] || '.';
  const repoName = process.argv[3] || 'Axodus/AragonOSX';

  log.info(`Processing hierarchy for: ${repoName}`);

  // Find and parse .md files
  const planFile = path.join(repoPath, 'PLAN.md');
  const sprintFile = path.join(repoPath, 'SPRINT.md');

  if (!fs.existsSync(planFile)) {
    log.error('PLAN.md not found');
    process.exit(1);
  }

  // Parse PLAN.md
  const planItems = parseMarkdownHierarchy(planFile);
  log.success(`Parsed ${planItems.length} items from PLAN.md`);

  // Parse SPRINT.md if exists
  let allItems = [...planItems];
  if (fs.existsSync(sprintFile)) {
    const sprintItems = parseMarkdownHierarchy(sprintFile);
    allItems = [...allItems, ...sprintItems];
    log.success(`Parsed ${sprintItems.length} items from SPRINT.md`);
  }

  // Build hierarchy tree
  const tree = buildHierarchyTree(allItems);

  // Generate progress tracking
  const progressTracking = generateProgressTracking(tree, repoName);

  // Read original PLAN.md for parent issue body
  const originalPlanContent = fs.readFileSync(planFile, 'utf-8');

  log.info('Progress Tracking generated:');
  console.log(progressTracking);

  log.info('Hierarchy processing complete!');
  log.info('Next: Create/update issues and link them in GitHub');
}

main();
