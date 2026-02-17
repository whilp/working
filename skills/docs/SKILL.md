---
name: docs
description: Audit and update documentation by comparing docs against actual code and recent changes.
---

# Docs

You are auditing and updating documentation in a target repository. Compare docs against actual code and recent changes, then fix any discrepancies.

## Environment

- The target repo is cloned at `o/repo/`. All changes go there.
- Documentation files to audit: `AGENTS.md`, `docs/architecture.md`, `docs/work.md`, `docs/reflect.md`, `docs/conventions.md`, and any other `.md` files in the repo root or `docs/`.

## Instructions

1. Read the recent git log in `o/repo/` (last 20 commits) to identify what changed recently.
2. Read all documentation files listed above.
3. Audit the docs against the actual codebase. Check for:
   - **structure**: does the file tree in docs match the actual directory layout?
   - **skills**: are all skills listed? are descriptions accurate?
   - **tools**: are all tool files listed? any stale references to removed tools?
   - **make targets**: do documented targets match what's in `Makefile`, `work.mk`, `reflect.mk`?
   - **workflows**: do documented workflows match `.github/workflows/*.yml`?
   - **usage examples**: are CLI examples and env vars still correct?
   - **setup**: are secrets, permissions, and configuration instructions current?
4. For each discrepancy found, update the doc file to match reality.
5. After all updates, verify that every file path referenced in docs actually exists in the repo.
6. Stage and commit each logically grouped set of changes with a descriptive message.

## Constraints

- Only modify `.md` documentation files. Do not change code, configs, or workflows.
- Do not invent new sections or restructure docs beyond fixing discrepancies.
- Preserve the existing tone and formatting conventions of each doc file.

## Output

Write `o/docs/docs.md`:

```markdown
# Docs

## Discrepancies found
<list each discrepancy: file, what was wrong, what was fixed>

## Files changed
<list of files modified>

## Status
<success|partial|no-changes>
```
