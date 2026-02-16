---
name: pick
description: Fetch open todo issues from a repo, analyze them, and pick the best one to work on next. Prefers PRs with review feedback over new issues.
---

# Pick Work Item

You are selecting the next work item from a GitHub repository. PRs with review feedback take priority over new issues.

## Environment

- The target `owner/repo` is provided after the `---` separator below as `REPO=<value>`.

## Instructions

1. Run `ensure_labels` with `repo` set to REPO.
2. Run `get_prs_with_feedback` with `repo` set to REPO.
3. If there are PRs with `CHANGES_REQUESTED`:
   a. Pick the PR with the oldest `updatedAt` (longest waiting for attention).
   b. Write your output with `type` set to `"pr"` and the PR details.
   c. Skip the remaining steps.
4. Run `count_open_prs` with `repo` set to REPO. If more than 4, write `o/pick/issue.json` with `{"error": "pr limit"}` and stop.
5. Run `list_issues` with `repo` set to REPO to get open issues (returns issues labeled `todo` plus issues filed by repo collaborators).
6. Analyze the issues. Prefer issues labeled `todo` — collaborator-filed issues without `todo` are lower priority candidates. For each, assess:
   - **priority**: p0 > p1 > p2 > unlabeled (check labels array)
   - **age**: older issues first (createdAt)
   - **clarity**: is the issue specific enough to plan and execute?
   - **size**: can it be done in a short session (~50 tool calls)?
7. Pick the single best issue: highest priority, then oldest, then clearest.
8. Transition the issue: run `set_issue_labels` with `issue_url` set to the issue URL, `add` set to `["doing"]`, `remove` set to `["todo"]`.
9. Write your output.

## Output

Write `o/pick/issue.json`:

For a PR with feedback:

```json
{
  "type": "pr",
  "number": 123,
  "title": "...",
  "body": "...",
  "url": "https://github.com/owner/repo/pull/123",
  "branch": "<headRefName from PR>",
  "reviews": [...],
  "comments": [...]
}
```

For an issue:

```json
{
  "type": "issue",
  "number": 123,
  "title": "...",
  "body": "...",
  "url": "https://github.com/owner/repo/issues/123",
  "branch": "work/<number>-<8 random hex chars>"
}
```

The branch name for issues must be `work/<number>-<8 random hex chars>`.

Write `o/pick/reasoning.md`: brief explanation of why this work item was picked over others.

If there are no PRs with feedback and no open todo issues, write `o/pick/issue.json` containing `{"error": "no issues"}` and explain in reasoning.md.
