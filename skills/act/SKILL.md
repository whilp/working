---
name: act
description: Execute actions from the check phase. Comment on issues, open PRs, update labels.
---

# Act

You are executing the actions produced by the check phase of a work pipeline.

## Environment

- `WORK_REPO` — set in the environment. All tools read it automatically.
- `ACTIONS_FILE` — path to `actions.json`, provided after `---` below.
- `ISSUE_FILE` — path to `issue.json`, provided after `---` below.

## Instructions

1. Read ISSUE_FILE. Parse the result as JSON. Extract `type`, `number`, and `branch`.
2. Read ACTIONS_FILE. Parse the result as JSON. Extract `verdict` and `actions` array.
3. Execute each action in order:
   - `comment_issue`: run `comment_issue` with `issue_number` (from the work item) and `body`. Works for both issues and PRs.
   - `create_pr`: run `create_pr` with `branch`, `title`, and `body`. Append `\n\nCloses #<number>` to the body if not already present. Skip this action if `type` is `"pr"` (PR already exists).
   - Skip unknown action types and note them.
4. Transition labels based on verdict, execution success, and type:
   - If `type` is `"issue"`:
     - If verdict is "pass" AND all actions succeeded: run `set_issue_labels` with `issue_number`, remove `doing`, add `done`.
     - Otherwise: run `set_issue_labels` with `issue_number`, remove `doing`, add `failed`.
   - If `type` is `"pr"`: run `set_issue_labels` with `issue_number` (the PR number), add `needs-review`. This prevents the pick phase from re-selecting this PR until the reviewer acts.

## Output

Write `o/act.json`:

```json
{
  "type": "<issue|pr>",
  "verdict": "<pass|needs-fixes|fail>",
  "actions_executed": <count>,
  "actions_failed": <count>,
  "label": "<done|failed|needs-review>"
}
```
