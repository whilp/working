# working

automated work loop for github repositories. picks issues, plans, executes, reviews, and acts — all via `make work`.

## build

```bash
make ci          # type checks + format checks + tests
make test        # tests only
make check-types # type checks only
make check-format # format checks only
make clean       # remove build artifacts
```

run a single test:

```bash
TL_PATH='?.tl;?/init.tl;/zip/.lua/?.tl;/zip/.lua/?/init.tl;/zip/.lua/types/?.d.tl;/zip/.lua/types/?/init.d.tl' o/bin/cosmic skills/pick/tools/test_list_issues.tl
```

## usage

```bash
# run full loop for a repo
REPO=whilp/ah make work

# run individual phases
REPO=whilp/ah make pick
REPO=whilp/ah make clone
REPO=whilp/ah make plan
REPO=whilp/ah make do
REPO=whilp/ah make check

# run reflect loop
REPO=whilp/ah make reflect

# run individual reflect phases
REPO=whilp/ah make fetch
REPO=whilp/ah make analyze
REPO=whilp/ah make publish

# reflect on a specific date
REPO=whilp/ah DATE=2025-01-15 make reflect
```

the github workflow runs on a schedule (hourly) or via manual dispatch. it matrices over configured repos.

the reflect workflow runs daily at 06:00 UTC or via manual dispatch. it analyzes the previous day's workflow runs.

## setup

the workflow requires two secrets:

- `CLAUDE_CODE_OAUTH_TOKEN` — oauth token for claude API access.
- `GH_TOKEN` — fine-grained github PAT with access to target repositories.

`GH_TOKEN` needs a [fine-grained personal access token](https://github.com/settings/personal-access-tokens/new) with repository access to target repos and these permissions:

| permission | level | used for |
|---|---|---|
| contents | read and write | clone, push branches |
| issues | read and write | list issues, transition labels, comment |
| pull requests | read and write | create PRs |
| actions | read-only | list workflow runs, download logs and artifacts |
| metadata | read-only | required by github for all fine-grained PATs |

## structure

```
Makefile              build, test, ci targets; cosmic/ah dependency fetching
work.mk               work loop targets (pick → clone → plan → do → push → check → act)
reflect.mk            reflect loop targets (fetch → analyze → publish)
skills/               agent skills and their tools
  pick/               select next issue from github
    SKILL.md          pick skill prompt
    tools/            tl tool modules for pick (list-issues, count-open-prs, ensure-labels, set-issue-labels)
  plan/               research codebase and write a plan
    SKILL.md          plan skill prompt
  do/                 execute the plan
    SKILL.md          do skill prompt
  check/              review execution against plan
    SKILL.md          check skill prompt
  act/                execute actions (comment, create PR, update labels)
    SKILL.md          act skill prompt
    tools/            tl tool modules for act (comment-issue, create-pr, set-issue-labels)
  reflect/            retrospective analysis of workflow runs
    SKILL-fetch.md    fetch skill prompt
    SKILL-analyze.md  analyze skill prompt (sandboxed)
    SKILL-publish.md  publish skill prompt
    tools/            tl tool modules for reflect (list-workflow-runs)
.github/workflows/
  test.yml            CI: runs `make -j ci` on push/PR
  work.yml            scheduled work loop: runs `make work` hourly
  reflect.yml         daily reflect loop: runs `make reflect`
```

## docs

- `docs/architecture.md` — work loop design, convergence, tool module structure
- `docs/conventions.md` — teal patterns, testing, naming, commit format

## making changes

1. read the relevant skill SKILL.md and tool .tl files before editing.
2. every tool .tl file must have a corresponding test_*.tl file.
3. run `make ci` before committing. all checks must pass.
4. tool modules return a table with `name`, `description`, `input_schema`, `execute`.
5. tests validate tool record structure and input validation (no external calls).
