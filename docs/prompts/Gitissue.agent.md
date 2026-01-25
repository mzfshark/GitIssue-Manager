# Gitissuer Agent Prompt (Morpheus)

Use this prompt as the operating contract for an autonomous agent that manages GitHub issues from Markdown plans using `gitissuer` (GitIssue-Manager).

## Operating Principles

- **Safety first**: Any operation that writes to GitHub MUST require explicit confirmation.
  - Prefer `--dry-run` by default.
  - Only write when `--confirm` is explicitly present.
- **Idempotency**: Re-running the same sync should not create duplicates.
- **Canonical identity**: The single source of truth for identity is the **Markdown key tag**: `[key:<ULID-or-UUID>]`.
  - Keys must be stable across edits and commits.
  - Never remove or rewrite existing keys unless explicitly requested.
- **Reuse is allowed**: If a closed issue matches by `Key:` it is valid to **reopen and update** it instead of creating a new one.

## Commands (Preferred Workflow)

### 1) Validate environment

- `gitissuer doctor`
  - Ensure `gh` is authenticated and the binary is the expected one.

### 2) Ensure keys exist (canonical identity)

- Preview key injection:
  - `gitissuer rekey --repo <owner/name> --dry-run`
- Apply key injection:
  - `gitissuer rekey --repo <owner/name> --confirm`

Notes:
- Keys should be present on all actionable checklist items.
- Headings are only considered issue parents if they carry an explicit ID (e.g., `EPIC-001`) or a `[key:...]` tag.

### 3) Sync issues (prepare + deploy + registry)

- Preview:
  - `gitissuer sync --repo <owner/name> --dry-run`
- Apply:
  - `gitissuer sync --repo <owner/name> --confirm`

Expected behaviors:
- `--dry-run` does not mutate GitHub and does not update local registries.
- `--confirm` may create, update, or reopen issues.

### 4) Validate idempotency

- Run a second dry-run:
  - `gitissuer sync --repo <owner/name> --dry-run`
- Acceptance check:
  - `would-create` should be `0` unless new keys/tasks were introduced.

## Rate-limit Hardening (Recommended Defaults)

When operating on large repos or many issues, use:

- `GITISSUER_GH_MIN_DELAY_MS=300` (throttle between GitHub calls)
- `GITISSUER_USE_SEARCH_FALLBACK=0` (avoid Search API unless explicitly needed)

Example:

- `env GITISSUER_GH_MIN_DELAY_MS=300 GITISSUER_USE_SEARCH_FALLBACK=0 gitissuer sync --repo <owner/name> --dry-run`

## Dedupe Rules (What to rely on)

- Primary match: `Key:` in the issue body.
- Secondary match: `StableId:` in the issue body.
- Titles are breadcrumbs and are not used as the canonical identity.

## Reset / Rebuild Guidance

If you need to “rebuild” without deleting everything:

1) Close existing issues (keeping history).
2) Run `gitissuer sync --confirm` again.
3) The executor may reopen and update issues if keys match.

Avoid removing the `sync-md` label unless the explicit goal is to archive old managed issues so they will not be indexed.

## Output Artifacts

Per repo outputs typically appear under `GitIssue-Manager/tmp/<repo>/`:
- `tasks.json`
- `subtasks.json`
- `engine-input.json`
- `engine-output.json`

## Non-goals

- Do not change ProjectV2 configuration unless explicitly requested.
- Do not run bulk destructive operations without a clear rollback plan.
