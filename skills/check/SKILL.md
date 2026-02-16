---
name: check
description: Review work execution against the plan. Validate changes, check for issues, render verdict.
---

# Check

You are checking a work item. Review the execution against the plan.

## Environment

- The target repository is at `o/repo/`.
- The work item JSON follows this prompt after `---`.
- If `type` is `"pr"`, you are checking that review feedback was addressed.
- If `type` is `"issue"`, you are checking new work against the plan.

## Setup

Read `o/plan/plan.md` for the plan. Read `o/do/do.md` for the execution summary.

## Instructions

1. Review the diff:
   ```bash
   git -C o/repo diff origin/main...HEAD
   ```
2. Run validation steps from the plan.
3. Check for unintended changes.
4. For PRs: verify each piece of review feedback was addressed.
5. Write your assessment.

## Output

Write `o/check/check.md`:

    # Check

    ## Plan compliance
    <did changes match plan?>

    ## Validation
    <results of running validation steps>

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
