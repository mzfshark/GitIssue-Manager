#  #PLAN-001 - Fix ProjectV2 GraphQL Variable Handling (GitIssue-Manager)

Repository: GitIssue-Manager (mzfshark/GitIssue-Manager)
End Date Goal: 2026-01-24
Priority: [ MEDIUM ]
Estimative Hours: 4h
Status: [ Ready ]

## Executive Summary

Intent: Fix the root cause behind ProjectV2 and field-resolution failures when running `server/executor.js` against GitHub Projects (v2).

Process: Update the GraphQL invocation strategy in the executor to pass variables in a `gh api graphql`-compatible way, then validate the sync flow with minimal, reproducible commands (dry-run and a single real repo run).

Expected outcomes:
- ProjectV2 node/field lookups work reliably (no `invalid value` variable errors).
- `ensureProjectItem()` can attach issues to ProjectV2 when enabled.
- E2E flow can reach Stage 6 without failing due to variable serialization.

### Key Metrics

• Total Planned Work: 4h
• Completion: 0%
• Active Features: 1
• Open Bugs: 1
• Timeline: 2026-01-22 → 2026-01-24

## Subtasks (Linked)

### PLAN-001:

- [ ] Normalize GraphQL variable passing in executor [labels:type:task, area:gitissue-manager] [status:TODO] [priority:HIGH] [estimate:2h] [start:2026-01-22] [end:2026-01-23]
- [ ] Fix fallback GraphQL input formatting for field updates [labels:type:task, area:gitissue-manager] [status:TODO] [priority:MEDIUM] [estimate:1h] [start:2026-01-22] [end:2026-01-23]
- [ ] Validate against Axodus ProjectV2 (DEV Dashboard #23) in dry-run mode [labels:type:task, area:gitissue-manager] [status:TODO] [priority:HIGH] [estimate:1h] [start:2026-01-23] [end:2026-01-24]

## Milestones

• Milestone 1: Executor GraphQL fixed → 2026-01-23
• Milestone 2: End-to-end validation completed → 2026-01-24
