---
name: pick
description: Fetch open todo issues from a repo, analyze them, and pick the best one to work on next.
---

# Pick Issue

You are selecting the next issue to work on from a GitHub repository.

## Environment

- The target `owner/repo` is provided after the `---` separator below as `REPO=<value>`.
- You have tools: `list_issues` to fetch open issues, and `bash` for shell commands.

## Instructions

1. Run preflight checks:
   a. Run `bash` with: `gh label create todo --repo $REPO --force 2>/dev/null; gh label create doing --repo $REPO --force 2>/dev/null; gh label create done --repo $REPO --force 2>/dev/null; gh label create failed --repo $REPO --force 2>/dev/null; echo ok`
   b. Run `bash` with: `gh pr list --repo $REPO --state open --json number | jq length` — if more than 4, write `o/pick/issue.json` with `{"error": "pr limit"}` and stop.
2. Run `list_issues` with `repo` set to the REPO value to get open todo issues.
3. Analyze the issues. For each, assess:
   - **priority**: p0 > p1 > p2 > unlabeled (check labels array)
   - **age**: older issues first (createdAt)
   - **clarity**: is the issue specific enough to plan and execute?
   - **size**: can it be done in a short session (~50 tool calls)?
4. Pick the single best issue: highest priority, then oldest, then clearest.
5. Transition the issue: run `bash` with `gh issue edit '<issue_url>' --remove-label todo --add-label doing`
6. Write your output.

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
