---
name: check
description: Review work execution against the plan. Validate changes, check for issues, render verdict.
---

# Check

You are checking a work item. Review the execution against the plan.

## Environment

- The target repository is at `o/repo/`.
- The work item JSON follows this prompt after `---`.
- If `type` is `"pr"`, you are checking that review feedback and/or CI failures were addressed (check the `reason` field).
- If `type` is `"issue"`, you are checking new work against the plan.

## Setup

Read `o/repo/AGENTS.md` if it exists. It contains repo-specific context,
conventions, and build instructions for the target repository. Follow its guidance.

Read `o/plan/plan.md` for the plan. Read `o/do/do.md` for the execution summary.

## Instructions

1. Review the diff:
   ```bash
   git -C o/repo diff origin/main...HEAD
   ```
2. Run validation steps from the plan.
3. Enforce scope limits:
   a. Extract the planned file list from `o/plan/plan.md`'s `## Files` section.
   b. List actual changed files:
      ```bash
      git -C o/repo diff --name-only origin/main...HEAD
      ```
   c. Identify out-of-scope files — files in the diff but NOT in the plan's file list.
   d. Test files that correspond to a planned source file are acceptable (e.g.
      `test_foo.tl` for a planned `foo.tl`).
   e. If any out-of-scope files remain without explicit justification, the verdict
      MUST be `needs-fixes`. List each out-of-scope file and require it to be
      removed or justified.
4. For PRs: verify each piece of review feedback was addressed and/or CI checks now pass (based on `reason` field).
5. Check for security issues and code smells:
   - Hardcoded secrets or credentials
   - Injection vulnerabilities (SQL, command, path traversal)
   - Unsafe error handling (swallowed errors, missing validation)
   - Obvious code smells (dead code, duplicated logic, magic numbers)
6. Write your assessment.

## Output

Write `o/check/check.md`:

    # Check

    ## Plan compliance
    <did changes match plan?>

    ## Scope
    - Planned files: <list from plan>
    - Actual files: <list from diff>
    - Out-of-scope files: <list, or "none">
    - Justified: <yes/no for each out-of-scope file, with reason>

    ## Validation
    <results of running validation steps>

    ## Security & Quality
    <security issues or code smells found, or "none">

    ## Issues

    ### Critical
    <blocks merge, must fix. include file path and line number.>

    ### Warnings
    <should fix, not blocking.>

    ### Suggestions
    <optional improvements>

    (write "none" for empty sections)

    ## Verdict
    <pass|needs-fixes|fail>

Write `o/check/actions.json`:

    {
      "verdict": "pass|needs-fixes|fail",
      "actions": [
        {"action": "comment_issue", "body": "..."},
        {"action": "create_pr", "branch": "...", "title": "...", "body": "..."}
      ]
    }

Action rules:
- Always include `comment_issue` with verdict and summary.
- For issues: include `create_pr` only when verdict is "pass" and changes were committed.
  Use the branch from the work item JSON.
- For PRs: do NOT include `create_pr` (the PR already exists). The push phase
  already updated the branch.

If verdict is "needs-fixes", write the critical and warning issues to
`o/do/feedback.md` so the do phase can address them on re-run.
If verdict is "pass" or "fail", do NOT write `o/do/feedback.md`.

Do NOT modify any source files.
