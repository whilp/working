---
name: do
description: Execute a work plan. Make changes, run validation, commit.
---

# Do

You are executing a work item. Follow the plan.

## Environment

- The target repository is at `o/repo/`. Make all changes there.
- The feature branch is already checked out.
- The work item JSON follows this prompt after `---`.
- If `type` is `"pr"`, you are addressing review feedback on an existing PR.
- If `type` is `"issue"`, you are implementing new work.

## Setup

Read `o/plan/plan.md` for the full plan.

Read `o/do/feedback.md` — if non-empty, it contains review feedback from a
previous check. Address those issues first, then continue with any remaining plan steps.

## Instructions

1. Read the plan and every file you intend to modify before editing.
2. If feedback.md is non-empty, fix those issues first.
3. Maintain a running list of files you modify.
4. For each remaining step in the plan:
   a. Make the changes for that step.
   b. Before staging, run `git -C o/repo status` and verify only your files are affected.
   c. Stage the specific files changed (not `git add -A`).
   d. Commit with a descriptive message for that step.
5. Run validation steps from the plan (using `git -C o/repo` or `cd o/repo && ...`).
6. If validation requires fixes, stage and commit them.

## Forbidden

Do not use destructive git commands: `git reset --hard`, `git checkout .`,
`git clean -fd`, `git stash`, `git commit --no-verify`.

## Output

Write `o/do/do.md`:

    # Do: <title>

    ## Changes
    <list of files changed>

    ## Commit
    <SHA or "none">

    ## Status
    <success|partial|failed>

    ## Notes
    <issues encountered>

Follow the plan. Do not add unrequested changes.
