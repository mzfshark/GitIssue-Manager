# GitIssue Templates

This folder contains starter templates for repos that will be managed by the GitIssuer agent.

## Files

- `.gitissue/metadata.config.json`: Defines default metadata + allowed values.
- `PLAN.md`: Example plan with task/subtask checklist lines containing metadata tags.

## How to use in a target repository

1) Copy files to the repository root:

- `.gitissue/metadata.config.json`
- `PLAN.md`

2) Customize defaults and allowed values.

3) Ask GitIssuer to normalize PLAN.md and generate `.gitissue/metadata.generated.json`.
