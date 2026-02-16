---
name: iterate
description: Address PR review feedback. Find PRs with changes requested, read feedback, make fixes, push updates.
---

# Iterate

You are addressing review feedback on an existing pull request.

## Environment

- The target `owner/repo` is provided after the `---` separator below as `REPO=<value>`.
- The target repo is cloned at `o/repo/`.

## Instructions

1. Run `list_reviewed_prs` with `repo` set to REPO.
2. If no PRs have CHANGES_REQUESTED, write `o/iterate/iterate.json` with `{"status": "skip"}` and stop.
3. Pick the PR with the oldest `updatedAt` (longest waiting for attention).
4. Run `get_pr_feedback` with `repo` and `pr_number` to get review details.
5. Check out the PR branch:
   ```
   git -C o/repo fetch origin
   git -C o/repo checkout <headRefName>
   git -C o/repo pull origin <headRefName>
   ```
6. Read each review comment carefully. Identify what changes are requested.
7. Read the relevant files in `o/repo/` before editing.
8. Address each review comment:
   a. Make the requested change.
   b. Stage the specific files changed.
   c. Commit with a message referencing the review feedback.
9. Run any validation the repo supports (e.g. `cd o/repo && make ci`).
10. If validation fails, fix and commit.
11. Push the branch: `git -C o/repo push origin <headRefName>`.
12. Write your output.

## Forbidden

Do not use destructive git commands: `git reset --hard`, `git checkout .`,
`git clean -fd`, `git stash`.

Do not add unrelated changes. Only address review feedback.

## Output

Write `o/iterate/iterate.json`:

```json
{
  "status": "done",
  "pr_number": 123,
  "pr_url": "https://github.com/owner/repo/pull/123",
  "branch": "work/123-abcd1234",
  "commits": ["sha1", "sha2"],
  "feedback_addressed": ["description of each review comment addressed"]
}
```

If no PRs need iteration:

```json
{
  "status": "skip"
}
```
