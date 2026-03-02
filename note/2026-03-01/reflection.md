# Reflection: 2026-03-01

## Summary

5 work runs executed across the day. 3 succeeded, 2 failed. whilp/working had no actionable issues all day (no_issues). whilp/cosmic hit pr_limit (5 open PRs vs limit of 4) in the first two runs, then cleared and started delivering PRs. The dominant failure mode was `do` phase timeouts on multi-function refactor tasks — this occurred twice across two repos.

## Runs

| workflow | total | pass | fail | cancel |
|---|---|---|---|---|
| work | 5 | 3 | 2 | 0 |

Per-run breakdown:

| run | started | conclusion | notes |
|---|---|---|---|
| 22541049294 | 10:02Z | success | ah #327 pass, PR created; cosmic pr_limit; working no_issues |
| 22542022796 | 11:01Z | success | ah #230 pass but PR failed (no commits); cosmic pr_limit; working no_issues |
| 22551430900 | 20:01Z | failure | ah #441 pass+PR; cosmic #338 do timeout ×2 |
| 22552578650 | 21:01Z | failure | cosmic #334 pass+PR; ah #447 do timeout ×2; working no_issues |
| 22554911572 | 23:01Z | success | cosmic #357 pass+PR; ah PR #463 feedback loop pass; working no_issues |

## Failure Analysis

### 1. `do` phase timeout (×2 occurrences, 4 total timeout events)

The 300s budget was exceeded on multi-function refactor tasks:

- **whilp/cosmic #338** (sqlite throw-on-failure): required changing function signatures, updating a `Database` record type, and adding 4+ new tests. Session queue WALs reached 300–432 KB before cutoff.
- **whilp/ah #447** (replace `io.popen` with `child.spawn`): required refactoring pager/difftool functions that use shell expansion, plus test updates. Both timed out without producing any committed output or `do.md`.

Both cases: plan was completed correctly, but execution scope exceeded the time budget. Each tried twice (retry is expected behavior) and failed both times.

### 2. PR creation on no-commit branch (run 22542022796)

ah #230: `do` phase only added a comment to `work.mk` — no functional diff vs main. `check` issued a pass verdict, `act` attempted `create_pr`, got `GraphQL: No commits between main and work/230-a3f7c1e2`. Issue was labeled `failed`. Comment was posted successfully. This is a known edge case — the verdict should gate PR creation on whether commits exist.

### 3. `whilp/cosmic` PR backlog (runs 22541049294, 22542022796)

Cosmic had 5 open PRs vs a limit of 4, causing pick to skip with `pr_limit`. Two consecutive hourly runs were wasted for cosmic. The backlog cleared by 20:01Z when cosmic resumed work.

## Work Loop Outcomes

| repo | issue | verdict | PR |
|---|---|---|---|
| whilp/ah | #327 — add --no-tools flag | pass | created |
| whilp/ah | #230 — convergence fix loop (already impl'd) | pass* | failed (no commits) |
| whilp/ah | #441 — rename cumulative_input_tokens | pass | created |
| whilp/ah | #447 — replace io.popen with child.spawn | — | timeout |
| whilp/ah | PR #463 — remove duplicate colorize_diff_line | pass | updated |
| whilp/cosmic | #338 — sqlite throw on failure | — | timeout |
| whilp/cosmic | #334 — child.spawn TOCTOU race fix | pass | created |
| whilp/cosmic | #357 — docs workflow git checkout fix | pass | created |
| whilp/working | — | no_issues | — |

5 PRs delivered (or updated), 2 timeouts, 1 no-commit edge case.

## Patterns

- **do timeout is the primary failure mode**: affects tasks with multi-function changes + new tests. 300s is insufficient for this scope. The pattern is consistent: plan completes fine, do starts work but hits limit before committing.
- **whilp/working perpetually empty**: no actionable issues all 5 runs. Either all issues are in-flight (`doing` label) or the backlog is genuinely empty.
- **whilp/cosmic PR backlog accumulation**: 5 open PRs blocking new work for two hours. PRs need review/merge attention.
- **pre-existing cosmic test failures** (`fs_dir_test`, `fetch_example`) appear repeatedly in build output — likely sandbox/network-related, flagged as unrelated to code changes each time.
- **pick reasoning is sound**: correct issue selection each run; deferred ill-specified issues appropriately.
- **normal run duration**: successful runs complete in 6–8 minutes total. Timeout failures add 10 minutes of wasted compute (2 × 300s) before the job fails.

## Recommendations

1. **Increase `do` phase timeout or add scope-based routing**: issues requiring multi-function refactors + test additions consistently exceed 300s. Consider a larger timeout (600s) or a pre-do scope check that declines oversized tasks and leaves them labeled `todo` for manual work.

2. **Gate `create_pr` on commit count**: before calling `create_pr` in the act phase, check that the branch has commits vs main. If not, skip PR creation and label the issue `done` or `needs-review` rather than `failed` — a comment-only outcome is not a failure.

3. **Alert on cosmic PR backlog**: when `pr_limit` is hit on consecutive runs, post a comment or notification prompting review/merge of open PRs. Two wasted hourly slots per blocker adds up.

4. **Add a `no_issues` grace period or issue auto-creation for whilp/working**: the repo picks nothing every run. If the queue is empty for N consecutive runs, auto-file a maintenance or triage issue to keep the loop productive.

5. **Track and surface pre-existing build failures separately**: cosmic's `fs_dir_test` and `fetch_example` failures appear in every run's build output. Adding an explicit skip/xfail or noting them in a known-failures file would reduce noise in analysis.
