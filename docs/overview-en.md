# GitIssue-Manager — Client Overview (English)

## Title
GitIssue-Manager — Automated Issue & Project Sync for Multi-Repo Planning

## Elevator pitch
Convert human-friendly planning documents into tracked GitHub issues and ProjectV2 items with minimal manual work, full dry-run previews, and immutable audit logs.

## Key benefits
- Faster & consistent sprint onboarding across repositories.
- Reduced manual errors when creating/updating many issues.
- Auditability and governance: every change logged and reviewable.
- Safe rollout: dry-run first, then per-repo execute to limit risk.

## How it works (3 steps)
1. Parse: read canonical `SPRINT.md` and artifact files.
2. Preview: simulate issue creation and ProjectV2 updates (dry-run JSON).
3. Apply: apply approved changes and append audit records.

## Architecture (one line)
Lightweight parser → executor (GitHub API + ProjectV2) → audit logs.

## Deployment & next steps
- Demo: run a dry-run for a sample repo and review `logs/dryrun_summary_*.json`.
- Pilot: execute per-repo on a small set of sprint items.
- Full rollout: adopt `TYPE-NNN` convention and integrate into team planning cadence.
