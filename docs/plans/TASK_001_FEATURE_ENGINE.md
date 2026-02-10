# [EPIC-LogicConvergence | SPRINT-001 | FEATURE-001] ULID-based Deduplication Engine

**Repository:** GitIssue-Manager  
**Parent:** [EPIC-LogicConvergence | SPRINT-001](../plans/SPRINT_001_CORE_UNIFICATION.md)  
**Type:** FEATURE  
**Key:** 01JPUIE642GMDT90NT83ZMR46L  
**Status:** TODO  
**Priority:** URGENT  
**Estimate:** 8h

---

## Technical Summary

Refactors the `executor.js` core to prioritize searching for issues by their ULID key embedded in the issue body. Currently, the tool relies heavily on local registry indexes which can become stale or misaligned when issues are manually manipulated or in multi-repo environments.

The new engine will:
1. Parse the Markdown line to extract the `[key:<ULID>]` tag.
2. Search the local registry for a match.
3. If no registry match is found, query GitHub issues (using Search API or listing) to find an issue whose body contains the ULID.
4. Auto-heal the local registry if a match is found on GitHub.

## Acceptance Criteria

- [ ] Successful matching of a moved/renamed task if the body contains the identical ULID.
- [ ] No duplicate GitHub issues are created when the local `.gitissuer-registry.json` is deleted but the issues exist on GitHub.
- [ ] Clean fallback to title-based matching only if no ULID is provided.

## Implementation Notes

- Update `findIssueByStableId` in [server/executor.js](server/executor.js) to include body search fallback.
- Integrate `gh issue list --search "[key:<ULID>]"` into the search pipeline.
- Ensure the ULID is persisted in the GitHub issue body inside a Managed Section (comment block).
