# reflect loop

a daily retrospective analysis of workflow runs. `make reflect` drives the cycle:

```
fetch → analyze (per-run) → summarize → publish
```

runs daily via the `reflect.yml` workflow. outputs go to `o/reflect/`. all runs come from `whilp/working` (this repo).

## phases

**fetch** — downloads workflow run logs and artifacts for a date range using `get_workflow_runs` tool. writes manifest and run data to `o/reflect/fetch/`. has network access (needs `gh` CLI).

**analyze** — one sandboxed agent per workflow run. each reads that run's log and artifacts, produces a concise analysis in `o/reflect/analyze/<run-id>.md`. keeps context small by isolating each run.

**summarize** — one sandboxed agent reads all per-run analyses and produces `o/reflect/summarize/reflection.md`. synthesizes success rates, failure patterns, work loop outcomes, and recommendations.

**publish** — plain make recipe (no agent). copies `reflection.md` to `note/YYYY-MM-DD/reflection.md`, commits, pushes a branch, and opens a PR.

## configuration

- `DATE` — date to reflect on (default: yesterday).
- `SINCE`/`UNTIL` — date range (default: both equal DATE).

## tools

**reflect tools** (`skills/reflect/tools/`):
- `get-workflow-runs.tl` — get workflow runs in a date range, download logs and artifacts via `gh run list`/`gh run view`/`gh run download`
