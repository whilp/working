# architecture

## work loop

the system implements a PDCA (plan-do-check-act) loop for github issues. `make work` drives the full cycle:

```
pick → clone → plan → do → push → check → act
```

each phase is a make target with file-based dependencies. outputs go to `o/`.

### phases

**pick** — selects one open `todo`-labeled issue from the target repo. ensures labels exist, checks PR limits, picks by priority/age/clarity. transitions the issue to `doing`. writes `o/pick/issue.json`.

**clone** — clones (or fetches) the target repo into `o/repo/`. checks out a fresh feature branch from the default branch.

**plan** — reads the repo and issue, writes a step-by-step plan to `o/plan/plan.md`. research only, no source changes.

**do** — executes the plan in `o/repo/`. makes changes, runs validation, commits. writes `o/do/do.md`.

**push** — pushes the feature branch to origin.

**check** — reviews the diff against the plan. writes verdict (`pass`, `needs-fixes`, `fail`) and actions to `o/check/actions.json`.

**act** — executes actions: comments on the issue, creates a PR (on pass), transitions labels to `done` or `failed`. writes `o/act.json`.

### convergence

when check writes `needs-fixes`, it also writes `o/do/feedback.md`. since do depends on feedback.md, the next make run re-executes do → push → check. `make work` retries up to 3 times.

### agent invocation

each phase runs `ah` (the agent harness) with:
- a skill (`--skill pick`, `--skill plan`, etc.)
- a model (`-m sonnet` or `-m opus`)
- tool overrides (`--tool name=path.tl`)
- sandbox constraints (`--sandbox`, `--unveil`)
- a required output file (`--must-produce`)

## tool modules

tool modules are teal (.tl) files in `skills/*/tools/`. each file returns a table:

```
{
  name: string,
  description: string,
  input_schema: { type: "object", properties: {...}, required: {...} },
  execute: function(input: {string: any}): string
}
```

tools are loaded by `ah` via `--tool name=path.tl`. the agent calls them by name during a session.

### tool inventory

**pick tools** (`skills/pick/tools/`):
- `list-issues.tl` — fetch open `todo` issues via `gh issue list`
- `count-open-prs.tl` — count open PRs via `gh pr list`
- `ensure-labels.tl` — create `todo`/`doing`/`done`/`failed` labels via `gh label create`
- `set-issue-labels.tl` — add/remove labels via `gh issue edit`

**act tools** (`skills/act/tools/`):
- `comment-issue.tl` — post a comment via `gh issue comment`
- `create-pr.tl` — create a PR via `gh pr create`
- `set-issue-labels.tl` — add/remove labels via `gh issue edit`

**reflect tools** (`skills/reflect/tools/`):
- `list-workflow-runs.tl` — list workflow runs in a date range, download logs and artifacts via `gh run list`/`gh run view`/`gh run download`

all tools shell out to `gh` CLI. input validation happens before any subprocess is spawned.

## reflect loop

a separate loop for retrospective analysis. `make reflect` drives the cycle:

```
fetch → analyze → publish
```

runs daily via the `reflect.yml` workflow. outputs go to `o/reflect/`.

### phases

**fetch** — downloads workflow run logs and artifacts for a date range using `list_workflow_runs` tool. writes manifest and run data to `o/reflect/fetch/`. has network access (needs `gh` CLI).

**analyze** — sandboxed (no network, limited unveil). reads fetched data and produces `o/reflect/analyze/reflection.md`. analyzes success rates, failure patterns, work loop outcomes, and agent friction.

**publish** — commits `reflection.md` to `note/YYYY-MM-DD/reflection.md` in the target repo, pushes, and opens a PR.

### configuration

- `REPO` — target repository (required).
- `DATE` — date to reflect on (default: yesterday).
- `SINCE`/`UNTIL` — date range (default: both equal DATE).

## dependencies

**cosmic** — teal/lua runtime. fetched as a binary in the Makefile. used for: running .tl files, type checking (`--check-types`), formatting (`--format`), test execution (`--test`), test reporting (`--report`).

**ah** — agent harness. fetched as a binary in the Makefile. runs agent sessions with skills, tools, and sandbox constraints.

both are pinned by version, URL, and sha256 hash in the Makefile.

## ci

`make ci` runs three checks in the github actions workflow:
1. `check-types` — teal type checking on all non-test .tl files
2. `check-format` — formatting check on all non-test .tl files
3. `test` — runs all test_*.tl files via `cosmic --test`, reports via `cosmic --report`
