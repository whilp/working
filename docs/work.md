# work loop

the system implements a PDCA (plan-do-check-act) loop for github issues and PR feedback. `make work` drives the full cycle:

```
pick → clone → plan → do → push → check → act
```

pick prefers PRs with review feedback over new issues. when a PR has `CHANGES_REQUESTED` status, the pipeline addresses that feedback. otherwise, it picks a new issue.

each phase is a make target with file-based dependencies. outputs go to `o/`.

## phases

**pick** — selects the next work item. first checks for open PRs with `CHANGES_REQUESTED` review status (excluding PRs labeled `needs-review`, which are waiting for the reviewer). if found, picks the oldest one. otherwise, selects one open `todo`-labeled issue. ensures labels exist, checks PR limits, picks by priority/age/clarity. transitions issues to `doing`. writes `o/pick/issue.json` with a `type` field (`"pr"` or `"issue"`).

**clone** — clones (or fetches) the target repo into `o/repo/`. for PRs, checks out the existing branch. for issues, creates a fresh feature branch from the default branch.

**plan** — reads the repo and work item, writes a step-by-step plan to `o/plan/plan.md`. for PRs, the plan addresses each piece of review feedback. for issues, the plan covers the implementation. research only, no source changes.

**do** — executes the plan in `o/repo/`. makes changes, runs validation, commits. writes `o/do/do.md`.

**push** — pushes the feature branch to origin.

**check** — reviews the diff against the plan. for PRs, verifies each piece of feedback was addressed. writes verdict (`pass`, `needs-fixes`, `fail`) and actions to `o/check/actions.json`.

**act** — executes actions: comments on the issue/PR, creates a PR (on pass, for issues only), transitions labels to `done` or `failed` (for issues) or `needs-review` (for PRs). writes `o/act.json`.

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

**pick tools** (`skills/pick/tools/`):
- `get-prs-with-feedback.tl` — list open PRs with `CHANGES_REQUESTED` review status (excluding `needs-review` labeled PRs) and their review comments via GraphQL
- `list-issues.tl` — fetch open `todo` issues via `gh issue list`
- `count-open-prs.tl` — count open PRs via `gh pr list`
- `ensure-labels.tl` — create `todo`/`doing`/`done`/`failed`/`needs-review` labels via `gh label create`
- `set-issue-labels.tl` — add/remove labels via `gh issue edit`

**act tools** (`skills/act/tools/`):
- `comment-issue.tl` — post a comment via `gh issue comment`
- `create-pr.tl` — create a PR via `gh pr create`
- `set-issue-labels.tl` — add/remove labels via `gh issue edit`

**triage tools** (`skills/triage/tools/`):
- `close-issue.tl` — close an issue via `gh issue close` with reason (completed/not_planned)
- `create-issue.tl` — create a new issue via `gh issue create`
- `grep-repo.tl` — search the target repo for patterns via grep

triage also reuses `list-issues` from pick and `comment-issue`/`set-issue-labels` from act.

## triage

the triage skill reviews open issues in a target repo and closes stale ones. it runs standalone via `REPO=owner/repo make triage`, separate from the main work loop.

triage categorizes each open issue as:

- **obsolete** — referenced code/feature was removed. closed with reason `not_planned`.
- **already resolved** — problem was fixed but issue left open. closed with reason `completed`.
- **duplicate** — overlaps another open issue. closed with reason `not_planned`.
- **underspecified** — too vague to act on. labeled `needs-info` with a comment asking for clarification.
- **oversized** — too large for a single work session. split into sub-issues, parent closed.
- **healthy** — left alone.

outputs to `o/triage/triage.json`.

## tests

the tests skill audits and improves tests for a target repo. it runs standalone via `REPO=owner/repo make tests`, separate from the main work loop.

the skill reads `AGENTS.md` to discover the repo's test conventions, runs the full suite, then reads through the codebase and tests to find gaps and quality issues. it fixes the most impactful problems — broken tests first, then missing tests, then weak assertions.

adapts to whatever testing patterns the repo uses. no fixed rubric.

runs in a sandbox with `--tool "bash="` for executing test commands. no custom tool modules.

outputs to `o/tests/tests.json`.
