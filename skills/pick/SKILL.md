---
name: pick
description: Fetch open todo issues from a repo, analyze them, and pick the best one to work on next.
---

# Pick Issue

You are selecting the next issue to work on from a GitHub repository.

## Environment

- The target `owner/repo` is provided after the `---` separator below as `REPO=<value>`.

## Instructions

1. Run `ensure_labels` with `repo` set to REPO.
2. Run `count_open_prs` with `repo` set to REPO. If more than 4, write `o/pick/issue.json` with `{"error": "pr limit"}` and stop.
3. Run `list_issues` with `repo` set to REPO to get open todo issues.
4. Analyze the issues. For each, assess:
   - **priority**: p0 > p1 > p2 > unlabeled (check labels array)
   - **age**: older issues first (createdAt)
   - **clarity**: is the issue specific enough to plan and execute?
   - **size**: can it be done in a short session (~50 tool calls)?
5. Pick the single best issue: highest priority, then oldest, then clearest.
6. Transition the issue: run `set_issue_labels` with `issue_url` set to the issue URL, `add` set to `["doing"]`, `remove` set to `["todo"]`.
7. Write your output.

## Output

Write `o/pick/issue.json`:

```json
{
  "number": 123,
  "title": "...",
  "body": "...",
  "url": "https://github.com/owner/repo/issues/123",
  "branch": "work/123-<8char-hash>"
}
```

The branch name must be `work/<number>-<8 random hex chars>`.

Write `o/pick/reasoning.md`: brief explanation of why this issue was picked over others.

If there are no open todo issues, write `o/pick/issue.json` containing `{"error": "no issues"}` and explain in reasoning.md.
