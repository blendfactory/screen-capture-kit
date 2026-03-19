---
name: github-release-create
description: Create a GitHub Release from the latest `main` commit using `gh`, generating release notes from a previous tag. Use when the user asks to create a GitHub release (e.g. `v0.x.y`) and wants automatic changelog notes.
---

# GitHub Release Create

## Purpose

Create a GitHub Release for a given version tag using the GitHub CLI (`gh`).

Release notes are automatically generated using:

- `--generate-notes`
- `--notes-start-tag <previousTag>`

## Inputs

The agent should ask (or infer) at least:

- `tagName` (example: `v0.0.3`) — Git tag / release tag name to create

Optional:

- `notesStartTag` — tag to start note generation from (example: `v0.0.2`)
  - If omitted, compute it from `tagName` or fall back to the nearest previous semver tag.

## Behavior / Rules

1. Target commit:
   - Fetch `origin/main` and use the latest commit SHA as `--target`.
   - Do not use the local HEAD unless it matches `origin/main` (prefer determinism via `origin/main`).

2. Release notes:
   - Default rule is `--notes-start-tag <previousTag>`.
   - Determine `<previousTag>` as follows when `notesStartTag` is not provided:
     - If `tagName` looks like `vMAJOR.MINOR.PATCH`, choose `vMAJOR.MINOR.(PATCH-1)` if that tag exists.
     - Otherwise, pick the closest lower version tag by sorting existing `v*` tags with semver order.
     - If no suitable previous tag exists, ask the user for `notesStartTag`.

3. Idempotency:
   - If `gh release view <tagName>` succeeds, do not create a duplicate.
   - Ask the user whether to update/overwrite notes; otherwise skip creation.

4. Repository selection:
   - Use `gh` default repo unless the user has multiple remotes.
   - If the agent can infer `OWNER/REPO` from `origin`, it may pass `-R OWNER/REPO` explicitly.

## Workflow (step-by-step)

1. Verify prerequisites:
   - Ensure `gh` is available and authenticated (`gh auth status`).
   - Ensure the git remote `origin` exists.

2. Sync refs:
   - Run: `git fetch --tags origin main`
   - Compute latest target SHA:
     - `targetSha = git rev-parse origin/main`

3. Compute `notesStartTag`:
   - If provided by the user, use it.
   - Else compute the previous semver tag (see rules above).

4. Check whether the release already exists:
   - If `gh release view <tagName>` returns successfully, ask to update or skip.

5. Create the release:
   - Run:

     `gh release create <tagName> --target <targetSha> --generate-notes --notes-start-tag <notesStartTag>`

## Example

Create `v0.0.3` release notes from `v0.0.2`, targeting latest `origin/main`:

```bash
gh release create v0.0.3 \
  --target $(git rev-parse origin/main) \
  --generate-notes \
  --notes-start-tag v0.0.2
```
