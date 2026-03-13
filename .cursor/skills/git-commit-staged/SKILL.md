---
name: git-commit-staged
description: >-
  Helps the agent create Conventional Commits from already staged changes. Use when
  the user wants to review and commit staged changes, generate proper commit messages,
  or split staged changes into multiple commits based on logical groups.
---

# Git Commit (Staged Changes)

## Purpose

Use this skill when **there are changes already staged in git** (after `git add`) and you
need to:

- Inspect what is staged
- Split staged changes into logical commits when needed
- Generate **Conventional Commits** messages
- Execute `git commit`

This skill assumes **changes are already staged**. For unstaged changes, use the `git-commit-unstaged` skill instead.

## Commit message rules

Commit messages created with this skill must follow the project-wide standards
defined in `commit-message-standards.mdc` (Conventional Commits in English).

- Use the `type`, `scope`, summary, and body style described in that rule file.
- Do not redefine or override those standards here; keep this skill focused on
  the workflow for staged changes.

## Workflow (staged changes)

1. **Get staged files and diff**

   - Run `git status --short` to see current state
   - Run `git diff --cached` to get the staged diff

2. **Split changes into logical groups**

   Read the staged diff and decide "one commit per unit" based on:

   - Feature scope (e.g. license setup, API addition, bug fix)
   - Impact area (per file, directory, or module)
   - Change type (separate `feat` from `fix`, `docs` from others, etc.)

   If multiple logical changes are mixed in one staging set:

   - Use `git reset -p` or `git restore --staged -p` to unstage interactively
   - Re-stage each logical group with `git add -p`

3. **Create commit message for each group**

   For each logical group, decide:

   - `type` (required)
   - `scope` (optional; e.g. `core`, `docs`, `ci`, `pkg`, `native`)
   - `summary` (one-line)
   - `body` (optional)

   **Message guidelines**

   - Prefer explaining **why** the change was made, not just what
   - Keep summary concise; use body for details

4. **Final check before commit**

   For each commit:

   - Re-check the diff with `git diff --cached`
   - Confirm the generated commit message matches the diff

5. **Execute commit**

   For each logical group:

   - Ensure only the intended diff is staged
   - Commit with the generated Conventional Commits message:

     ```bash
     git commit -m "type(scope): summary"
     ```

   - If there is a body, use multiple `-m` flags or a here-doc:

     ```bash
     git commit -m "type(scope): summary" -m "Detailed description..."
     ```

   Or:

   ```bash
   git commit -m "$(cat <<'EOF'
   type(scope): summary

   Detailed description...
   EOF
   )"
   ```

6. **Verify state after commit**

   - Run `git status` to see if the working tree is clean
   - If more changes remain, repeat steps 1–5 as needed

## Usage notes

- Handle only already-staged changes
- If multiple logical changes are mixed, reorganize staging before splitting commits
- Use existing project history (`git log --oneline`) to align type/scope terminology

## Example

### Example: License file and README license section update

- Changes:
  - Replace `LICENSE` from MIT to BSD 3-Clause
  - Update `README.md` license section from `MIT` to `BSD 3-Clause License`
- type: `chore`
- scope: `license`
- summary: `update license to BSD 3-Clause`

Commit message:

```text
chore(license): update license to BSD 3-Clause

Replace MIT license text with BSD 3-Clause and align README license section.
```
