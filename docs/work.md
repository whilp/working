# work loop

the system implements a PDCA (plan-do-check-act) loop for github issues. `make work` drives the full cycle:

```
iterate → pick → clone → plan → do → push → check → act
```

iterate runs first to prioritize addressing PR review feedback over starting new work. if iterate finds and addresses a PR, work completes early. otherwise, the normal pick flow runs.

each phase is a make target with file-based dependencies. outputs go to `o/`.

## phases

**iterate** — checks for open PRs with `CHANGES_REQUESTED` review status. if found, reads review feedback, checks out the PR branch, addresses comments, commits, and pushes. writes `o/iterate/iterate.json` with status `done` or `skip`.

**pick** — selects one open `todo`-labeled issue from the target repo. ensures labels exist, checks PR limits, picks by priority/age/clarity. transitions the issue to `doing`. writes `o/pick/issue.json`.

**clone** — clones (or fetches) the target repo into `o/repo/`. checks out a fresh feature branch from the default branch.

**plan** — reads the repo and issue, writes a step-by-step plan to `o/plan/plan.md`. research only, no source changes.

**do** — executes the plan in `o/repo/`. makes changes, runs validation, commits. writes `o/do/do.md`.

**push** — pushes the feature branch to origin.

**check** — reviews the diff against the plan. writes verdict (`pass`, `needs-fixes`, `fail`) and actions to `o/check/actions.json`.

**act** — executes actions: comments on the issue, creates a PR (on pass), transitions labels to `done` or `failed`. writes `o/act.json`.

## convergence

when check writes `needs-fixes`, it also writes `o/do/feedback.md`. since do depends on feedback.md, the next make run re-executes do → push → check. `make work` retries up to 3 times.

## agent invocation

each phase runs `ah` (the agent harness) with:
- a skill (`--skill pick`, `--skill plan`, etc.)
- a model (`-m sonnet` or `-m opus`)
- tool overrides (`--tool name=path.tl`)
- sandbox constraints (`--sandbox`, `--unveil`)
- a required output file (`--must-produce`)

## tools

**iterate tools** (`skills/iterate/tools/`):
- `list-reviewed-prs.tl` — list open PRs with `CHANGES_REQUESTED` review status via `gh pr list`
- `get-pr-feedback.tl` — get review comments and details for a PR via `gh pr view`

**pick tools** (`skills/pick/tools/`):
- `list-issues.tl` — fetch open `todo` issues via `gh issue list`
- `count-open-prs.tl` — count open PRs via `gh pr list`
- `ensure-labels.tl` — create `todo`/`doing`/`done`/`failed` labels via `gh label create`
- `set-issue-labels.tl` — add/remove labels via `gh issue edit`

**act tools** (`skills/act/tools/`):
- `comment-issue.tl` — post a comment via `gh issue comment`
- `create-pr.tl` — create a PR via `gh pr create`
- `set-issue-labels.tl` — add/remove labels via `gh issue edit`
