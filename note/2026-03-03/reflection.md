# Reflection: 2026-03-03

## Summary

6 work runs executed across the day. 3 succeeded, 3 failed. All failures share the same root cause: issue #442 (`db.with_transaction`) repeatedly exhausted the 5-minute `do` phase timeout. Successful runs resolved other issues (#326, #363, #344) for whilp/ah. whilp/cosmic was blocked all day by a PR backlog (5 open PRs, limit 4). whilp/working had no open issues.

## Runs

| workflow | total | pass | fail | cancel |
|---|---|---|---|---|
| work | 6 | 3 | 3 | 0 |

## Failure Analysis

### do phase timeout — issue #442 (3 occurrences)

Runs 22608362982, 22626869728, 22646794792 all failed identically: whilp/ah picked issue #442 ("add db.with_transaction helper and use rollback on error"), completed pick/plan, then the `do` phase timed out twice at 300s each attempt (exit 124).

```
[run-ah] starting (timeout=300s, model=unknown)
[run-ah] timed out after 300s (limit=300s)
make[1]: *** [work.mk:193: o/do/done] Error 124
```

The task requires ~10 `begin_transaction`/`commit` replacements across `loop.tl` (9 sites), `looptool.tl` (1 site), a new helper in `db.tl`, and new tests. This volume consistently exceeds the 5-minute window before the agent can commit. Both session DBs are always present (~192–221 KB), confirming sessions ran to timeout rather than crashing. No `feedback.md` content was written in any attempt.

The issue keeps being picked because it stays in `todo` state (never moves to `doing`, never gets a PR). The agent resets and retries the same issue on subsequent runs.

## Work Loop Outcomes

| run | repo | issue | verdict | PR |
|---|---|---|---|---|
| 22601656533 | whilp/ah | #326 symlink agents stuff | pass | `work/326-a3f7c2d1` |
| 22608362982 | whilp/ah | #442 db.with_transaction | timeout | none |
| 22616040963 | whilp/ah | #363 bash tool linebreaking | pass | `work/363-a3f7c2b1` |
| 22626869728 | whilp/ah | #442 db.with_transaction | timeout | none |
| 22640396833 | whilp/ah | #344 update cosmic/child spawning | pass | `work/344-a3f8c2d1` |
| 22646794792 | whilp/ah | #442 db.with_transaction | timeout | none |

- whilp/cosmic: skipped (`pr_limit`) in all 6 runs — 5 open PRs exceeds threshold of 4.
- whilp/working: skipped (`no_issues`) in all 6 runs — queue is empty.

## Patterns

- **Issue #442 is a repeat failure magnet.** It was picked in 3 of the 6 runs (at 04:30, 14:12, 23:02 UTC) and failed identically each time. The `do` timeout is structurally too short for tasks requiring ~10 coordinated edits across multiple files plus `make ci` validation.
- **cosmic PR backlog is a persistent blocker.** 5 open PRs (threshold 4) blocked cosmic in every run. This has persisted across multiple days based on analysis notes.
- **Successful runs are fast (~8–19 min end-to-end).** Issues that fit within the do budget complete cleanly with no retries needed.
- **Two-session do executions are common even in successes.** Runs #22616040963 and #22640396833 both show two `==> do` entries but still passed — these appear to be normal continuation sessions rather than needs-fixes retries.

## Recommendations

1. **Split issue #442 into smaller tasks.** The `db.with_transaction` refactor spans ~10 call sites across 4 files. Split into: (a) add the helper to `db.tl` with tests, (b) migrate `loop.tl` call sites, (c) migrate `looptool.tl` call site. Each fits within the do budget.

2. **Add a mechanism to label issues as `too-large` or `needs-split` after repeated do timeouts.** Currently, #442 stays in `todo` and gets picked repeatedly. After 2 consecutive do timeouts, the issue should be flagged so the `pick` phase skips it.

3. **Review and merge or close the 5 open PRs in whilp/cosmic.** cosmic has been blocked by `pr_limit` across multiple days. The backlog is preventing any new work from landing.

4. **Increase the `do` timeout for issues tagged `complex` or `multi-file`.** The current 300s limit is appropriate for small focused changes but insufficient for refactors requiring many coordinated edits plus CI. A 600s limit for labeled issues would allow the agent to complete.

5. **Open issues for whilp/working.** The working repo queue has been empty for multiple consecutive days. Review the backlog/roadmap for actionable items to queue up.
