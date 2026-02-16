---
name: act
description: Execute actions from the check phase. Comment on issues, open PRs, update labels.
---

# Act

You are executing the actions produced by the check phase of a work pipeline.

## Environment

- `REPO` — the target `owner/repo`, provided after `---` below.
- `ACTIONS_FILE` — path to `actions.json`, provided after `---` below.
- `ISSUE_FILE` — path to `issue.json`, provided after `---` below.

## Instructions

1. Read ISSUE_FILE. Parse the result as JSON. Extract `url` (the issue URL) and `branch`.
2. Read ACTIONS_FILE. Parse the result as JSON. Extract `verdict` and `actions` array.
3. Execute each action in order:
   - `comment_issue`: run `comment_issue` with `issue_url` and `body`.
   - `create_pr`: run `create_pr` with `repo`, `branch`, `title`, and `body`. Append `\n\nCloses #<number>` to the body if not already present (extract number from the issue URL).
   - Skip unknown action types and note them.
4. Transition labels based on verdict and execution success:
   - If verdict is "pass" AND all actions succeeded: run `set_issue_labels` to remove `doing`, add `done`.
   - Otherwise: run `set_issue_labels` to remove `doing`, add `failed`.

## Output

Write `o/act.json`:

```json
{
  "verdict": "<pass|needs-fixes|fail>",
  "actions_executed": <count>,
  "actions_failed": <count>,
  "label": "<done|failed>"
}
```
