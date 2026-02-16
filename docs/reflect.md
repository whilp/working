# reflect loop

a daily retrospective analysis of workflow runs. `make reflect` drives the cycle:

```
fetch → analyze → publish
```

runs daily via the `reflect.yml` workflow. outputs go to `o/reflect/`. all runs come from `whilp/working` (this repo).

## phases

**fetch** — downloads workflow run logs and artifacts for a date range using `get_workflow_runs` tool. writes manifest and run data to `o/reflect/fetch/`. has network access (needs `gh` CLI).

**analyze** — sandboxed (no network, limited unveil). reads fetched data and produces `o/reflect/analyze/reflection.md`. analyzes success rates, failure patterns, work loop outcomes, and agent friction.

**publish** — commits `reflection.md` to `note/YYYY-MM-DD/reflection.md` in this repo, pushes, and opens a PR.

## configuration

- `DATE` — date to reflect on (default: yesterday).
- `SINCE`/`UNTIL` — date range (default: both equal DATE).

## tools

**reflect tools** (`skills/reflect/tools/`):
- `get-workflow-runs.tl` — get workflow runs in a date range, download logs and artifacts via `gh run list`/`gh run view`/`gh run download`
