# Reflection: 2026-03-06

## Summary

One workflow run was analyzed for 2026-03-06. The work loop ran once (scheduled), covering three repos. Two repos (whilp/working, whilp/cosmic) had no open todo issues and skipped. whilp/ah picked and planned issue #317 but timed out in the `do` phase twice before producing a result.

## Runs

| workflow | total | pass | fail | cancel |
|---|---|---|---|---|
| work | 1 | 0 | 1 | 0 |

## Failure Analysis

### `do` phase timeout (whilp/ah #317)

Both `do` attempts exhausted the 300s limit. The issue ("Investigate consolidating in a single db file") required merging queue schema into the main database across multiple files — a substantial refactor. Running `make ci` mid-session likely consumed most of the budget.

```
[run-ah] 2026-03-06T08:09:04Z starting (timeout=300s)
[run-ah] 2026-03-06T08:14:04Z timed out after 300s
make[1]: *** [work.mk:193: o/do/done] Error 124
[run-ah] 2026-03-06T08:14:04Z starting (timeout=300s)
[run-ah] 2026-03-06T08:19:04Z timed out after 300s
make[1]: *** [work.mk:193: o/do/done] Error 124
```

Two session databases (`do/session-1.db`, `do/session-2.db`) confirm both attempts ran to the wall. No `check/actions.json` or `act.json` were produced; the issue was never triaged out of `doing`.

## Work Loop Outcomes

| repo | issue | verdict | PR |
|---|---|---|---|
| whilp/ah | #317 — Investigate consolidating in a single db file | timeout (no verdict) | none |
| whilp/working | — | no_issues | — |
| whilp/cosmic | — | no_issues | — |

## Patterns

- **Single repo with work**: only whilp/ah had a todo issue. The other two repos have been consistently empty of issues recently.
- **Timeout on large refactor**: issue #317 has a `needs-info` label and an empty body, yet the plan produced was substantial. Large schema-migration tasks repeatedly exceed the 300s do-phase budget.
- **Build overhead eats budget**: the build step took ~2m37s before the do phase even started, leaving less headroom for the actual implementation.
- **No unstick**: after two timeouts, the issue likely remains in `doing` state until the unstick cron runs.

## Recommendations

1. **Skip or defer `needs-info` issues in the pick phase**: issue #317 had an empty body and `needs-info` label. The pick skill should deprioritize or skip such issues rather than attempting them, since the plan must guess intent.
2. **Add a complexity pre-check before do**: after planning, estimate scope (file count, cross-file changes). If the plan touches more than N files or includes schema changes, label it `too-large` and skip to avoid guaranteed timeouts.
3. **Reduce build time or cache artifacts**: the ~2m37s build before `do` consumes nearly half the 300s do-phase budget. Caching build outputs between phases would free meaningful execution time.
4. **Auto-unstick after double timeout**: two consecutive do-timeouts on the same issue should trigger an automatic label reset (remove `doing`, add `todo` + a comment) without waiting for the daily unstick cron.
