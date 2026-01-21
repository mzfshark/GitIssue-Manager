# Task: Repository Maintenance & Technical Debt

Template for TASK.md files across repositories.

**Purpose:** Track maintenance tasks, refactoring, tech debt, and non-feature work.

**Rules:**
- Every checkbox line MUST include metadata tags: [labels:...] [status:...] [priority:...] [estimate:..h] [start:YYYY-MM-DD] [end:YYYY-MM-DD]
- Subtasks are indented by 2 spaces under their parent
- Prefer short, action-oriented titles and brief descriptions
- Use TASK-NNN ID format (unique within repository)

---

## Milestone: Code Quality & Refactoring

- [ ] Refactor event handler architecture for reusability [labels:type:refactor, area:backend] [status:TODO] [priority:MEDIUM] [estimate:16h] [start:TBD] [end:TBD]
  - [ ] Extract common handler patterns into base class [labels:type:refactor] [status:TODO] [priority:MEDIUM] [estimate:6h] [start:TBD] [end:TBD]
  - [ ] Add comprehensive handler tests [labels:type:test] [status:TODO] [priority:MEDIUM] [estimate:8h] [start:TBD] [end:TBD]
  - [ ] Document handler interface and best practices [labels:type:docs] [status:TODO] [priority:LOW] [estimate:2h] [start:TBD] [end:TBD]

- [ ] Improve type safety across codebase [labels:type:refactor, area:frontend] [status:TODO] [priority:MEDIUM] [estimate:12h] [start:TBD] [end:TBD]
  - [ ] Remove any/unknown type annotations [labels:type:refactor] [status:TODO] [priority:MEDIUM] [estimate:6h] [start:TBD] [end:TBD]
  - [ ] Add strict TypeScript config checks [labels:type:chore] [status:TODO] [priority:MEDIUM] [estimate:2h] [start:TBD] [end:TBD]
  - [ ] Update type tests [labels:type:test] [status:TODO] [priority:MEDIUM] [estimate:4h] [start:TBD] [end:TBD]

---

## Milestone: Dependency Management

- [ ] Audit and update dependencies for security [labels:type:task, area:security] [status:TODO] [priority:HIGH] [estimate:8h] [start:TBD] [end:TBD]
  - [ ] Run security audit (npm audit) [labels:type:task] [status:TODO] [priority:HIGH] [estimate:1h] [start:TBD] [end:TBD]
  - [ ] Fix critical vulnerabilities [labels:type:task] [status:TODO] [priority:HIGH] [estimate:4h] [start:TBD] [end:TBD]
  - [ ] Update lockfiles and document changes [labels:type:chore] [status:TODO] [priority:MEDIUM] [estimate:2h] [start:TBD] [end:TBD]

- [ ] Consolidate duplicate dependencies [labels:type:refactor, area:infra] [status:TODO] [priority:MEDIUM] [estimate:4h] [start:TBD] [end:TBD]
  - [ ] Identify duplicate packages [labels:type:task] [status:TODO] [priority:MEDIUM] [estimate:1h] [start:TBD] [end:TBD]
  - [ ] Align versions across monorepo [labels:type:refactor] [status:TODO] [priority:MEDIUM] [estimate:2h] [start:TBD] [end:TBD]
  - [ ] Test compatibility [labels:type:test] [status:TODO] [priority:MEDIUM] [estimate:1h] [start:TBD] [end:TBD]

---

## Milestone: Performance & Optimization

- [ ] Optimize database queries for hot paths [labels:type:optimization, area:backend] [status:TODO] [priority:MEDIUM] [estimate:12h] [start:TBD] [end:TBD]
  - [ ] Profile slow queries [labels:type:investigation] [status:TODO] [priority:MEDIUM] [estimate:3h] [start:TBD] [end:TBD]
  - [ ] Add missing indexes [labels:type:optimization] [status:TODO] [priority:HIGH] [estimate:2h] [start:TBD] [end:TBD]
  - [ ] Implement caching strategy [labels:type:feature] [status:TODO] [priority:MEDIUM] [estimate:5h] [start:TBD] [end:TBD]
  - [ ] Measure improvement [labels:type:test] [status:TODO] [priority:MEDIUM] [estimate:2h] [start:TBD] [end:TBD]

- [ ] Reduce bundle size (frontend) [labels:type:optimization, area:frontend] [status:TODO] [priority:LOW] [estimate:8h] [start:TBD] [end:TBD]
  - [ ] Analyze bundle composition [labels:type:investigation] [status:TODO] [priority:LOW] [estimate:2h] [start:TBD] [end:TBD]
  - [ ] Code-split large modules [labels:type:optimization] [status:TODO] [priority:LOW] [estimate:4h] [start:TBD] [end:TBD]
  - [ ] Remove unused dependencies [labels:type:optimization] [status:TODO] [priority:LOW] [estimate:2h] [start:TBD] [end:TBD]

---

## Milestone: Technical Documentation

- [ ] Document API endpoints [labels:type:docs, area:backend] [status:TODO] [priority:MEDIUM] [estimate:8h] [start:TBD] [end:TBD]
  - [ ] Create OpenAPI/Swagger spec [labels:type:docs] [status:TODO] [priority:MEDIUM] [estimate:5h] [start:TBD] [end:TBD]
  - [ ] Document request/response schemas [labels:type:docs] [status:TODO] [priority:MEDIUM] [estimate:3h] [start:TBD] [end:TBD]

- [ ] Write architectural decision records (ADRs) [labels:type:docs] [status:TODO] [priority:MEDIUM] [estimate:6h] [start:TBD] [end:TBD]
  - [ ] Document reorg-safe indexing decision [labels:type:docs] [status:TODO] [priority:MEDIUM] [estimate:2h] [start:TBD] [end:TBD]
  - [ ] Document metadata fallback strategy [labels:type:docs] [status:TODO] [priority:MEDIUM] [estimate:2h] [start:TBD] [end:TBD]
  - [ ] Document native-token execution flow [labels:type:docs] [status:TODO] [priority:MEDIUM] [estimate:2h] [start:TBD] [end:TBD]

---

## Milestone: Testing Infrastructure

- [ ] Improve test coverage for critical paths [labels:type:test] [status:TODO] [priority:HIGH] [estimate:16h] [start:TBD] [end:TBD]
  - [ ] Add integration tests for indexing [labels:type:test, area:backend] [status:TODO] [priority:HIGH] [estimate:8h] [start:TBD] [end:TBD]
  - [ ] Add E2E tests for governance flows [labels:type:test, area:frontend] [status:TODO] [priority:HIGH] [estimate:8h] [start:TBD] [end:TBD]

- [ ] Set up continuous benchmarking [labels:type:task, area:infra] [status:TODO] [priority:LOW] [estimate:8h] [start:TBD] [end:TBD]
  - [ ] Configure performance testing baseline [labels:type:task] [status:TODO] [priority:LOW] [estimate:3h] [start:TBD] [end:TBD]
  - [ ] Add regression detection [labels:type:task] [status:TODO] [priority:LOW] [estimate:3h] [start:TBD] [end:TBD]
  - [ ] Document performance standards [labels:type:docs] [status:TODO] [priority:LOW] [estimate:2h] [start:TBD] [end:TBD]

---

## Milestone: DevOps & Infrastructure

- [ ] Update CI/CD pipeline [labels:type:task, area:infra] [status:TODO] [priority:MEDIUM] [estimate:12h] [start:TBD] [end:TBD]
  - [ ] Optimize build times [labels:type:optimization] [status:TODO] [priority:MEDIUM] [estimate:4h] [start:TBD] [end:TBD]
  - [ ] Add security scanning step [labels:type:task] [status:TODO] [priority:HIGH] [estimate:3h] [start:TBD] [end:TBD]
  - [ ] Configure automated deployments [labels:type:task] [status:TODO] [priority:MEDIUM] [estimate:5h] [start:TBD] [end:TBD]

- [ ] Improve monitoring and alerting [labels:type:task, area:ops] [status:TODO] [priority:MEDIUM] [estimate:10h] [start:TBD] [end:TBD]
  - [ ] Add custom metrics [labels:type:task] [status:TODO] [priority:MEDIUM] [estimate:4h] [start:TBD] [end:TBD]
  - [ ] Configure alert thresholds [labels:type:task] [status:TODO] [priority:MEDIUM] [estimate:3h] [start:TBD] [end:TBD]
  - [ ] Create incident runbooks [labels:type:docs] [status:TODO] [priority:MEDIUM] [estimate:3h] [start:TBD] [end:TBD]

---

## Template Instructions

### How to Use This Template

1. **Copy this file** to `<repo-root>/TASK.md`
2. **Replace milestone titles** with your own (e.g., "Authentication Refactoring")
3. **Add/remove subtasks** as needed
4. **Fill in metadata tags** with real values:
   - Replace `[start:TBD]` with `[start:2026-01-21]`
   - Replace `[end:TBD]` with `[end:2026-01-22]`
   - Choose appropriate labels, priority, estimate
5. **Mark completed items** as `[x]` when done
6. **Sync to GitHub** via GitIssue-Manager (optional, see SYNC_COMMANDS.md)

### Metadata Tag Reference

```markdown
[labels:type:task, area:backend]     ← Categories
[status:TODO|IN_PROGRESS|DONE]       ← Current state
[priority:HIGH|MEDIUM|LOW]           ← Urgency
[estimate:8h]                        ← Hours needed
[start:2026-01-21]                   ← Start date (ISO 8601)
[end:2026-01-22]                     ← End date (ISO 8601)
```

### Common Task Types

| Type | Purpose | Example |
|------|---------|---------|
| **refactor** | Code restructuring | Extract common patterns |
| **optimization** | Performance improvement | Reduce bundle size |
| **chore** | Maintenance | Update dependencies |
| **test** | Testing infrastructure | Add integration tests |
| **docs** | Documentation | Write ADR |
| **task** | General work | Code review process |

### Common Areas

| Area | Applies To |
|------|-----------|
| **frontend** | UI/UX, React components |
| **backend** | APIs, services, handlers |
| **contracts** | Smart contracts, ABIs |
| **indexing** | Event handlers, sync |
| **infra** | DevOps, CI/CD, monitoring |
| **security** | Vulnerabilities, auth |
| **ops** | Operations, runbooks |

---

## Example: Filled-in Task

```markdown
- [x] Refactor event handler for reorg safety [labels:type:refactor, area:backend] [status:DONE] [priority:HIGH] [estimate:16h] [start:2026-01-15] [end:2026-01-20]
  - [x] Extract common patterns [labels:type:refactor] [status:DONE] [priority:HIGH] [estimate:6h] [start:2026-01-15] [end:2026-01-16]
  - [x] Add unit tests [labels:type:test] [status:DONE] [priority:HIGH] [estimate:8h] [start:2026-01-17] [end:2026-01-19]
  - [x] Update documentation [labels:type:docs] [status:DONE] [priority:MEDIUM] [estimate:2h] [start:2026-01-20] [end:2026-01-20]
```

---

**Version:** 1.0  
**Last Updated:** 2026-01-21  
**Status:** Ready to use  
