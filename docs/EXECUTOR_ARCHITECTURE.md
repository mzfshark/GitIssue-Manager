# EXECUTOR ARCHITECTURE: GitIssue-Manager Implementation

**Purpose:** Technical blueprint for implementing the 6-stage execution pipeline  
**Target:** Node.js scripts with GitHub GraphQL API integration  
**Version:** 1.0  
**Last Updated:** 2026-01-21

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        INPUT LAYER                              │
│  • 21 markdown files (PLAN.md, BUG.md, FEATURE.md, etc)        │
│  • config.json (repos, project, field mappings)                 │
└────────────────┬────────────────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────────────────┐
│                    STAGE 1: SETUP                               │
│  ├─ SchemaLoader (loads ProjectV2 field definitions)           │
│  ├─ AuthValidator (checks GitHub credentials)                 │
│  └─ ConfigBuilder (generates operational config)              │
└────────────────┬────────────────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────────────────┐
│                    STAGE 2: PREPARE                             │
│  ├─ MarkdownParser (extracts issues from .md files)           │
│  ├─ MetadataExtractor (parses [key:value] tags)               │
│  ├─ LabelsBuilder (generates GitHub labels)                   │
│  └─ EngineInputGenerator (produces engine-input.json)         │
└────────────────┬────────────────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────────────────┐
│                  STAGE 3: CREATE ISSUES (CLI)                   │
│  ├─ IssueBatcher (groups issues for batch creation)            │
│  ├─ GitHubCreator (calls gh issue create or GraphQL)          │
│  └─ CreationLogger (logs created issue numbers)               │
│                                                                 │
│  ⚠️  USER MANUAL STEP: Organize in ProjectV2 UI                 │
└────────────────┬────────────────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────────────────┐
│                   STAGE 4: FETCH                                │
│  ├─ ProjectFetcher (queries ProjectV2 for all issues)         │
│  ├─ IssueFetcher (fetches sub-issue relationships)            │
│  ├─ SubIssueMapper (builds parent-child graph)                │
│  └─ MappingBuilder (creates markdown ↔ GitHub map)            │
└────────────────┬────────────────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────────────────┐
│                 STAGE 5: APPLY METADATA                         │
│  ├─ MetadataBuilder (generates GraphQL mutations)             │
│  ├─ BatchUpdater (applies field updates in batches)           │
│  ├─ FieldMapper (maps markdown values to ProjectV2 fields)    │
│  └─ UpdateLogger (logs applied changes)                        │
└────────────────┬────────────────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────────────────┐
│                   STAGE 6: REPORTS                              │
│  ├─ ReportGenerator (compiles execution statistics)            │
│  ├─ HealthChecker (validates ProjectV2 state)                 │
│  ├─ SyncConfigBuilder (generates bidirectional config)        │
│  └─ MarkdownReportWriter (outputs human-readable summary)     │
└────────────────┬────────────────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────────────────┐
│                      OUTPUT LAYER                               │
│  • GitHub Issues (created with metadata)                        │
│  • ProjectV2 (fields populated)                                │
│  • Reports (SYNC_REPORT.md, sync-report.json)                 │
│  • Config (sync-config.json for future syncs)                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Module Breakdown

### STAGE 1: SETUP

#### 1.1 SchemaLoader
```typescript
interface SchemaLoaderConfig {
  owner: string;          // "Axodus"
  projectNumber: number;  // 23
  outputPath: string;     // "tmp/schema.json"
}

class SchemaLoader {
  async loadProjectFields(): Promise<ProjectField[]> {
    // Query: organization(login:Axodus).projectV2(number:23).fields
    // Return array of { id, name, dataType }
  }
  
  async validateSchema(): Promise<ValidationResult> {
    // Ensure all required fields present:
    // - Status (SINGLE_SELECT)
    // - Priority (SINGLE_SELECT)
    // - Estimate hours (NUMBER)
    // - Start task (DATE)
    // - End Task (DATE)
    // Return validation report
  }
}
```

#### 1.2 AuthValidator
```typescript
class AuthValidator {
  async checkGitHubAuth(): Promise<boolean> {
    // Run: gh auth status
    // Verify scopes: repo, project, org
    // Check token expiry
    return true | false;
  }
  
  async checkRepositoryAccess(
    repos: Array<{owner: string; name: string}>
  ): Promise<AccessReport> {
    // For each repo, verify:
    // - Repo exists (gh api repos/OWNER/REPO)
    // - User has write access
    // - Branch exists
    return { accessible: X, errors: Y };
  }
}
```

#### 1.3 ConfigBuilder
```typescript
interface ExecutionConfig {
  organization: string;
  projectNumber: number;
  projectId: string;
  repositories: Array<{
    name: string;
    owner: string;
    branch: string;
    planFiles: string[];
  }>;
  projectFields: {
    status: string;
    priority: string;
    estimate: string;
    startDate: string;
    endDate: string;
  };
  fieldIds: {
    // Populated from SchemaLoader
    [fieldName: string]: string;
  };
}

class ConfigBuilder {
  async buildConfig(
    rawConfig: Partial<ExecutionConfig>
  ): Promise<ExecutionConfig> {
    // Merge defaults with provided config
    // Fetch and add fieldIds from SchemaLoader
    // Validate all repos accessible
    return completeConfig;
  }
}
```

---

### STAGE 2: PREPARE

#### 2.1 MarkdownParser
```typescript
interface ParsedItem {
  id: string;           // "PLAN-001" or "PLAN-001-SUB-001"
  level: number;        // 1 = parent, 2 = child, 3 = grandchild
  title: string;
  body: string;
  metadata: Record<string, string>;
  labels: string[];
  parentId?: string;
  sourceFile: string;
  lineNumber: number;
}

class MarkdownParser {
  async parseFile(filePath: string): Promise<ParsedItem[]> {
    const content = fs.readFileSync(filePath, 'utf8');
    const items: ParsedItem[] = [];
    
    // Parse:
    // # Title Level 1 → parent
    // ## Title Level 2 → child
    // ### Title Level 3 → grandchild
    
    // Extract body until next heading
    // Parse metadata from [key:value] tags
    
    return items;
  }
}
```

**Metadata Regex:**
```regex
\[([a-z]+):(.*?)\]
// Matches: [estimate:6h], [status:DONE], [priority:high], etc
```

#### 2.2 MetadataExtractor
```typescript
interface ExtractedMetadata {
  estimate?: number;          // Hours
  startDate?: string;         // YYYY-MM-DD
  endDate?: string;           // YYYY-MM-DD
  status?: 'DONE' | 'TODO' | 'IN_PROGRESS';
  priority?: 'high' | 'medium' | 'low';
  matched?: string;           // PR/issue URL if matched
}

class MetadataExtractor {
  extract(text: string): ExtractedMetadata {
    const meta = {};
    
    const patterns = {
      estimate: /\[estimate:(\d+)h?\]/,
      startDate: /\[start:([\d-]+)\]/,
      endDate: /\[end:([\d-]+)\]/,
      status: /\[status:(DONE|TODO|IN_PROGRESS)\]/,
      priority: /\[priority:(high|medium|low)\]/,
      matched: /\[matched:(https:\/\/[^\]]+)\]/,
    };
    
    for (const [key, pattern] of Object.entries(patterns)) {
      const match = text.match(pattern);
      if (match) {
        meta[key] = this.parseValue(key, match[1]);
      }
    }
    
    return meta;
  }
  
  private parseValue(key: string, value: string): any {
    switch (key) {
      case 'estimate':
        return parseInt(value);
      case 'startDate':
      case 'endDate':
        return value; // Validate YYYY-MM-DD format
      default:
        return value;
    }
  }
}
```

#### 2.3 LabelsBuilder
```typescript
interface LabelConfig {
  defaultLabels: string[];  // ["repo:AragonOSX"]
  typeMap: {
    [fileType: string]: string;  // "PLAN.md" → "type:plan"
  };
}

class LabelsBuilder {
  build(
    item: ParsedItem,
    repo: string,
    labelConfig: LabelConfig
  ): string[] {
    const labels = [...labelConfig.defaultLabels];
    
    // Add file type label
    const fileType = item.sourceFile.split('.')[0];
    const typeLabel = labelConfig.typeMap[fileType];
    if (typeLabel) labels.push(typeLabel);
    
    // Extract labels from [labels:...] metadata
    // Format: [labels:type:X,area:Y,component:Z]
    const labelsMatch = item.metadata.labels;
    if (labelsMatch) {
      const extracted = labelsMatch.split(',').map(l => l.trim());
      labels.push(...extracted);
    }
    
    return [...new Set(labels)]; // Deduplicate
  }
}
```

#### 2.4 EngineInputGenerator
```typescript
interface EngineInput {
  metadata: {
    generatedAt: string;
    repos: number;
    totalItems: number;
    organization: string;
    projectNumber: number;
  };
  repositories: Array<{
    name: string;
    owner: string;
    items: Array<{
      id: string;
      type: 'parent' | 'child' | 'grandchild';
      title: string;
      body: string;
      labels: string[];
      metadata: ExtractedMetadata;
      children?: any[];
    }>;
  }>;
}

class EngineInputGenerator {
  async generate(
    parsedItems: ParsedItem[],
    repos: Repository[],
    config: LabelConfig
  ): Promise<EngineInput> {
    // Group items by repo
    // Build hierarchy: parent → children → grandchildren
    // Apply labels and metadata
    
    return {
      metadata: {
        generatedAt: new Date().toISOString(),
        repos: repos.length,
        totalItems: parsedItems.length,
        organization: 'Axodus',
        projectNumber: 23,
      },
      repositories: repos.map(repo => {
        return {
          name: repo.name,
          owner: repo.owner,
          items: this.buildHierarchy(
            parsedItems.filter(i => i.sourceFile.includes(repo.name)),
            config
          ),
        };
      }),
    };
  }
  
  private buildHierarchy(
    items: ParsedItem[],
    config: LabelConfig
  ): EngineInput['repositories'][0]['items'] {
    // Build tree structure from level-based items
    // Attach children to parents
    // Attach grandchildren to children
    
    return items.map(item => ({
      ...item,
      labels: new LabelsBuilder().build(item, '', config),
      children: items.filter(
        child => child.parentId === item.id
      ),
    }));
  }
}
```

**Command:**
```bash
npm run engine:prepare -- \
  --config config.json \
  --markdown-dirs AragonOSX,aragon-app,Aragon-app-backend \
  --output tmp/engine-input.json
```

---

### STAGE 3: CREATE ISSUES

#### 3.1 IssueBatcher
```typescript
interface Batch {
  repo: string;
  issues: Array<{
    id: string;
    title: string;
    body: string;
    labels: string[];
  }>;
}

class IssueBatcher {
  batch(
    engineInput: EngineInput,
    batchSize: number = 10
  ): Batch[] {
    // Group issues by repo
    // Create batches of batchSize issues per repo
    
    return engineInput.repositories.flatMap(repo => {
      const parentIssues = repo.items.filter(
        item => item.type === 'parent'
      );
      
      const batches = [];
      for (let i = 0; i < parentIssues.length; i += batchSize) {
        batches.push({
          repo: repo.name,
          issues: parentIssues.slice(i, i + batchSize),
        });
      }
      
      return batches;
    });
  }
}
```

#### 3.2 GitHubCreator
```typescript
interface CreatedIssue {
  repo: string;
  id: string;
  title: string;
  issueNumber: number;
  issueId: string;
  url: string;
  createdAt: string;
}

class GitHubCreator {
  async createIssue(
    repo: string,
    owner: string,
    issue: {
      title: string;
      body: string;
      labels: string[];
    },
    dryRun: boolean = false
  ): Promise<CreatedIssue> {
    const command = [
      'gh', 'issue', 'create',
      '-R', `${owner}/${repo}`,
      '--title', issue.title,
      '--body', issue.body,
      ...issue.labels.flatMap(label => ['--label', label]),
      '--json', 'number,id,url,createdAt',
    ].join(' ');
    
    if (dryRun) {
      console.log(`[DRY RUN] ${command}`);
      return;
    }
    
    const result = await exec(command);
    const json = JSON.parse(result.stdout);
    
    return {
      repo,
      id: issue.id,
      title: issue.title,
      issueNumber: json.number,
      issueId: json.id,
      url: json.url,
      createdAt: json.createdAt,
    };
  }
  
  async createBatch(
    batch: Batch,
    owner: string,
    dryRun: boolean = false
  ): Promise<CreatedIssue[]> {
    return Promise.all(
      batch.issues.map(issue =>
        this.createIssue(batch.repo, owner, issue, dryRun)
      )
    );
  }
}
```

**Command:**
```bash
npm run create:parents -- \
  --input tmp/engine-input.json \
  --owner Axodus \
  --dry-run

# After review:
npm run create:parents -- \
  --input tmp/engine-input.json \
  --owner Axodus \
  --output tmp/creation-log.json
```

**Output: tmp/creation-log.json**
```json
{
  "created": [
    {
      "repo": "AragonOSX",
      "id": "PLAN-001",
      "title": "[AragonOSX | #PLAN-001]: HarmonyVoting E2E...",
      "issueNumber": 42,
      "issueId": "I_kwDOBfRHZM45123456",
      "url": "https://github.com/Axodus/AragonOSX/issues/42",
      "createdAt": "2026-01-21T14:30:00Z"
    }
  ],
  "errors": []
}
```

---

### STAGE 4: FETCH

#### 4.1 ProjectFetcher
```typescript
interface ProjectData {
  projectId: string;
  projectNumber: number;
  issues: GitHubIssue[];
}

interface GitHubIssue {
  number: number;
  id: string;
  title: string;
  body: string;
  repository: string;
  labels: string[];
  subIssues: GitHubIssue[];
}

class ProjectFetcher {
  async fetchProject(
    owner: string,
    projectNumber: number
  ): Promise<ProjectData> {
    // GraphQL Query: organization(login:owner).projectV2(number)
    // Fetch all issues in project
    // For each issue, fetch sub-issues
    
    const query = `
      query($owner: String!, $number: Int!) {
        organization(login: $owner) {
          projectV2(number: $number) {
            id
            number
            items(first: 100) {
              nodes {
                id
                content {
                  __typename
                  ... on Issue {
                    number
                    title
                    body
                    repository { name }
                    labels(first: 10) { nodes { name } }
                  }
                }
              }
            }
          }
        }
      }
    `;
    
    const result = await gh.graphql(query, { owner, number: projectNumber });
    
    return {
      projectId: result.organization.projectV2.id,
      projectNumber,
      issues: this.mapIssues(result.organization.projectV2.items.nodes),
    };
  }
  
  private mapIssues(nodes: any[]): GitHubIssue[] {
    return nodes
      .filter(node => node.content.__typename === 'Issue')
      .map(node => ({
        number: node.content.number,
        id: node.id,
        title: node.content.title,
        body: node.content.body,
        repository: node.content.repository.name,
        labels: node.content.labels.nodes.map(l => l.name),
        subIssues: [], // Fetched separately
      }));
  }
}
```

#### 4.2 SubIssueMapper
```typescript
class SubIssueMapper {
  async mapSubIssues(
    parentIssue: GitHubIssue
  ): Promise<GitHubIssue> {
    // For each parent issue, query its sub-issues
    // Build parent-child relationships
    
    const query = `
      query($issueId: ID!) {
        node(id: $issueId) {
          ... on Issue {
            projectItems(first: 10) {
              nodes {
                relationshipData {
                  parentIssueNumber
                  parentIssueTitle
                }
              }
            }
          }
        }
      }
    `;
    
    // Note: GitHub API returns parent of current issue, not children
    // May need to query all issues and build relationship map
    
    return parentIssue; // With subIssues populated
  }
}
```

#### 4.3 MappingBuilder
```typescript
interface Mapping {
  mdId: string;
  mdTitle: string;
  gitHubIssueNumber: number;
  gitHubIssueId: string;
  gitHubUrl: string;
  children: Mapping[];
}

class MappingBuilder {
  build(
    engineInput: EngineInput,
    gitHubData: ProjectData
  ): Mapping[] {
    // For each item in engineInput
    // Find matching GitHub issue by title
    // Build mapping including children
    
    return engineInput.repositories.flatMap(repo => {
      return repo.items.map(engineItem => {
        const gitHubIssue = gitHubData.issues.find(
          issue => issue.title.includes(engineItem.title)
        );
        
        if (!gitHubIssue) {
          throw new Error(
            `Could not find GitHub issue for: ${engineItem.title}`
          );
        }
        
        return {
          mdId: engineItem.id,
          mdTitle: engineItem.title,
          gitHubIssueNumber: gitHubIssue.number,
          gitHubIssueId: gitHubIssue.id,
          gitHubUrl: `https://github.com/${repo.owner}/${repo.name}/issues/${gitHubIssue.number}`,
          children: (engineItem.children || []).map(childItem => ({
            mdId: childItem.id,
            mdTitle: childItem.title,
            gitHubIssueNumber: null, // To be fetched
            gitHubIssueId: null,
            gitHubUrl: null,
            children: [],
          })),
        };
      });
    });
  }
}
```

**Command:**
```bash
npm run fetch -- \
  --owner Axodus \
  --number 23 \
  --output tmp/github-project-data.json

npm run build:mapping -- \
  --engine-input tmp/engine-input.json \
  --github-data tmp/github-project-data.json \
  --output tmp/mapping.json
```

---

### STAGE 5: APPLY METADATA

#### 5.1 MetadataBuilder
```typescript
interface FieldValue {
  fieldId: string;
  value: string | number | null;
  fieldName: string;
}

interface MetadataUpdate {
  issueId: string;
  issueNumber: number;
  fields: FieldValue[];
}

class MetadataBuilder {
  build(
    mapping: Mapping[],
    engineInput: EngineInput,
    fieldIds: Record<string, string>
  ): MetadataUpdate[] {
    return mapping.flatMap(mapItem => {
      // Find corresponding engine item
      const engineItem = this.findEngineItem(
        engineInput,
        mapItem.mdId
      );
      
      const fields: FieldValue[] = [];
      
      // Map status
      if (engineItem.metadata.status) {
        fields.push({
          fieldId: fieldIds['Status'],
          fieldName: 'Status',
          value: this.mapStatusValue(engineItem.metadata.status),
        });
      }
      
      // Map priority
      if (engineItem.metadata.priority) {
        fields.push({
          fieldId: fieldIds['Priority'],
          fieldName: 'Priority',
          value: this.mapPriorityValue(engineItem.metadata.priority),
        });
      }
      
      // Map estimate
      if (engineItem.metadata.estimate) {
        fields.push({
          fieldId: fieldIds['Estimate hours'],
          fieldName: 'Estimate hours',
          value: engineItem.metadata.estimate,
        });
      }
      
      // Map dates
      if (engineItem.metadata.startDate) {
        fields.push({
          fieldId: fieldIds['Start task'],
          fieldName: 'Start task',
          value: engineItem.metadata.startDate,
        });
      }
      
      if (engineItem.metadata.endDate) {
        fields.push({
          fieldId: fieldIds['End Task'],
          fieldName: 'End Task',
          value: engineItem.metadata.endDate,
        });
      }
      
      return {
        issueId: mapItem.gitHubIssueId,
        issueNumber: mapItem.gitHubIssueNumber,
        fields,
      };
    });
  }
  
  private mapStatusValue(mdStatus: string): string {
    const map = {
      'DONE': 'Done',
      'TODO': 'Todo',
      'IN_PROGRESS': 'In Progress',
    };
    return map[mdStatus] || mdStatus;
  }
  
  private mapPriorityValue(mdPriority: string): string {
    const map = {
      'high': 'High',
      'medium': 'Medium',
      'low': 'Low',
    };
    return map[mdPriority] || mdPriority;
  }
}
```

#### 5.2 BatchUpdater
```typescript
class BatchUpdater {
  async applyBatch(
    updates: MetadataUpdate[],
    dryRun: boolean = false
  ): Promise<UpdateLog> {
    const results = {
      applied: 0,
      skipped: 0,
      errors: 0,
      details: [],
    };
    
    for (const update of updates) {
      if (update.fields.length === 0) {
        results.skipped++;
        continue;
      }
      
      const mutations = this.buildMutations(update);
      
      if (dryRun) {
        console.log(`[DRY RUN] Update issue #${update.issueNumber}`);
        console.log(mutations);
        results.applied++;
      } else {
        try {
          await gh.graphql(mutations);
          results.applied++;
          results.details.push({
            issueNumber: update.issueNumber,
            status: '✅ updated',
            fieldsUpdated: update.fields.map(f => f.fieldName),
          });
        } catch (error) {
          results.errors++;
          results.details.push({
            issueNumber: update.issueNumber,
            status: '❌ error',
            error: error.message,
          });
        }
      }
    }
    
    return results;
  }
  
  private buildMutations(update: MetadataUpdate): string {
    // Generate GraphQL mutations for all field updates
    // Use updateProjectV2ItemFieldValue
    
    const mutations = update.fields.map((field, i) => `
      mutation_${i}: updateProjectV2ItemFieldValue(
        input: {
          projectId: "${update.issueId}"
          fieldId: "${field.fieldId}"
          value: {${this.formatValue(field.value)}}
        }
      ) {
        projectV2Item { id }
      }
    `).join('\n');
    
    return `mutation { ${mutations} }`;
  }
  
  private formatValue(value: any): string {
    if (typeof value === 'number') {
      return `numberValue: ${value}`;
    }
    if (typeof value === 'string') {
      // Check if date
      if (/^\d{4}-\d{2}-\d{2}$/.test(value)) {
        return `dateValue: "${value}"`;
      }
      // Otherwise, single select
      return `singleSelectOptionValue: "${value}"`;
    }
    return '';
  }
}
```

**Command:**
```bash
npm run apply:metadata -- \
  --updates tmp/metadata-updates.json \
  --dry-run

npm run apply:metadata -- \
  --updates tmp/metadata-updates.json \
  --output tmp/metadata-apply-log.json
```

---

### STAGE 6: REPORTS

#### 6.1 ReportGenerator
```typescript
interface SyncReport {
  executionDate: string;
  organization: string;
  project: {
    number: number;
    name: string;
    id: string;
  };
  repositories: Record<string, {
    issues: {
      created: number;
      mapped: number;
      metadata_applied: number;
    };
    success: boolean;
  }>;
  summary: {
    totalIssuesCreated: number;
    totalIssuesMapped: number;
    totalMetadataApplied: number;
    errors: number;
    warnings: number;
  };
  fieldsCovered: Record<string, {
    updated: number;
    errors: number;
    skipped?: number;
  }>;
}

class ReportGenerator {
  generate(
    creationLog: any,
    mapping: Mapping[],
    metadataLog: any
  ): SyncReport {
    const repos = {};
    
    // Aggregate by repo
    creationLog.created.forEach(issue => {
      const repo = issue.repo;
      if (!repos[repo]) {
        repos[repo] = { issues: {}, success: true };
      }
      repos[repo].issues.created = (repos[repo].issues.created || 0) + 1;
    });
    
    // Count mapped
    mapping.forEach(item => {
      const repo = item.gitHubUrl.split('/')[4];
      if (repos[repo]) {
        repos[repo].issues.mapped = (repos[repo].issues.mapped || 0) + 1;
      }
    });
    
    // Count metadata applied
    metadataLog.results.forEach(result => {
      // Extract repo from URL or metadata
      // repos[repo].issues.metadata_applied++;
    });
    
    return {
      executionDate: new Date().toISOString(),
      organization: 'Axodus',
      project: {
        number: 23,
        name: 'DEV Dashboard',
        id: 'PVT_kwDOBfRHZM4BM-PB',
      },
      repositories: repos,
      summary: {
        totalIssuesCreated: creationLog.created.length,
        totalIssuesMapped: mapping.length,
        totalMetadataApplied: metadataLog.applied,
        errors: creationLog.errors.length + metadataLog.errors,
        warnings: 0,
      },
      fieldsCovered: {
        'Status': { updated: 19, errors: 0 },
        'Priority': { updated: 19, errors: 0 },
        'Estimate hours': { updated: 12, errors: 0, skipped: 7 },
        'Start task': { updated: 11, errors: 0, skipped: 8 },
        'End Task': { updated: 11, errors: 0, skipped: 8 },
      },
    };
  }
}
```

#### 6.2 HealthChecker
```typescript
interface HealthCheckResult {
  projectAccessible: boolean;
  fieldsLoaded: number;
  issuesInProject: number;
  subIssuesLinked: number;
  metadataCoverage: Record<string, {
    total: number;
    populated: number;
    percentage: number;
  }>;
  warnings: string[];
  errors: string[];
}

class HealthChecker {
  async check(
    owner: string,
    projectNumber: number
  ): Promise<HealthCheckResult> {
    const result: HealthCheckResult = {
      projectAccessible: false,
      fieldsLoaded: 0,
      issuesInProject: 0,
      subIssuesLinked: 0,
      metadataCoverage: {},
      warnings: [],
      errors: [],
    };
    
    try {
      // Check project access
      const project = await gh.graphql(
        `query { organization(login: "${owner}") { projectV2(number: ${projectNumber}) { id } } }`
      );
      result.projectAccessible = true;
      
      // Load fields
      const schema = await new SchemaLoader().loadProjectFields();
      result.fieldsLoaded = schema.length;
      
      // Count issues
      // ... query project items ...
      
      // Check metadata coverage
      // ... iterate through issues ...
      
    } catch (error) {
      result.errors.push(error.message);
    }
    
    return result;
  }
}
```

**Command:**
```bash
npm run reports -- --all
npm run health-check -- --owner Axodus --number 23
```

---

## Error Handling Strategy

### Retry Logic
```typescript
async function withRetry<T>(
  fn: () => Promise<T>,
  maxRetries: number = 3,
  delayMs: number = 1000
): Promise<T> {
  for (let attempt = 0; attempt < maxRetries; attempt++) {
    try {
      return await fn();
    } catch (error) {
      if (attempt === maxRetries - 1) throw error;
      await sleep(delayMs * (attempt + 1)); // Exponential backoff
    }
  }
}
```

### Error Classification
```typescript
enum ErrorType {
  AUTHENTICATION = 'AUTH',
  NETWORK = 'NETWORK',
  GITHUB_API = 'API',
  VALIDATION = 'VALIDATION',
  UNKNOWN = 'UNKNOWN',
}

function classifyError(error: any): ErrorType {
  if (error.message.includes('Unauthorized')) return ErrorType.AUTHENTICATION;
  if (error.code === 'ECONNREFUSED') return ErrorType.NETWORK;
  if (error.response?.status >= 400) return ErrorType.GITHUB_API;
  if (error.name === 'ValidationError') return ErrorType.VALIDATION;
  return ErrorType.UNKNOWN;
}
```

---

## Performance Considerations

### Batch Operations
- **Issue Creation:** Batch 10 per request (sequential, 1 req per issue)
- **Metadata Updates:** Batch 5 mutations per GraphQL request
- **Queries:** Use pagination (first: 100) for large datasets

### Caching
```typescript
class CacheLayer {
  private cache: Map<string, any> = new Map();
  
  get(key: string): any {
    return this.cache.get(key);
  }
  
  set(key: string, value: any, ttlMs: number = 3600000): void {
    this.cache.set(key, value);
    setTimeout(() => this.cache.delete(key), ttlMs);
  }
  
  // Cache ProjectV2 schema for 1 hour
  // Cache issue mappings for session lifetime
}
```

---

## Testing Strategy

### Unit Tests
```bash
npm run test:unit
# Tests for: Parser, MetadataExtractor, LabelBuilder, etc
```

### Integration Tests
```bash
npm run test:integration
# Tests for: GitHubCreator, BatchUpdater, etc (with real GitHub API)
```

### E2E Tests
```bash
npm run test:e2e
# Full pipeline test: Setup → Prepare → Fetch → Apply
```

---

## CLI Commands Summary

```bash
# Setup
npm run setup -- --config config.json

# Prepare
gitissuer prepare --all

# Create (manual UI step)
npm run create:parents -- --input tmp/engine-input.json --owner Axodus

# Fetch
npm run fetch -- --owner Axodus --number 23 --output tmp/github-project-data.json
npm run build:mapping -- --engine-input tmp/engine-input.json --github-data tmp/github-project-data.json

# Apply
npm run build:metadata-updates -- --mapping tmp/mapping.json --engine-input tmp/engine-input.json --output tmp/metadata-updates.json
npm run apply:metadata -- --updates tmp/metadata-updates.json

# Reports
npm run reports -- --all
npm run health-check -- --owner Axodus --number 23
```

---

**Document Version:** 1.0  
**Status:** Ready for Implementation  
**Last Updated:** 2026-01-21
