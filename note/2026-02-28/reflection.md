# Reflection: 2026-02-28

## Summary

Three scheduled work runs fired across the day (runs 22511664374, 22513261191, 22515860367), each processing whilp/ah, whilp/cosmic, and whilp/working in parallel. whilp/working consistently had no open issues (at PR limit or empty todo queue) and skipped cleanly every run. Both ah and cosmic repos made progress through plan→do→check, but every single act phase failed due to a `os.tmpname()` / gh tmp file error — meaning no PRs were created and no issue comments were posted despite passing verdicts. One cosmic run (22513261191) also timed out twice in the do phase on a large feature issue.

## Runs

| workflow | total | pass | fail | cancel |
|---|---|---|---|---|
| work | 3 | 2 | 1 | 0 |

(run 22513261191 marked failure due to cosmic do-phase timeout; runs 22511664374 and 22515860367 marked success despite act failures not propagating to workflow conclusion)

## Failure Analysis

### 1. act-phase tmp file error (critical, 100% recurrence)

Every act phase in every run failed with identical errors:

```
comment_issue failed: gh failed (exit 1): open /tmp/lua_XXXXXX: no such file or directory
create_pr failed: gh failed (exit 1): open /tmp/lua_XXXXXX: no such file or directory
```

Root cause: `os.tmpname()` generates a path but does not create the file. The gh tool wrapper then fails to open that path. This blocked all act-phase actions across 6 job-runs (ah + cosmic × 3 workflow runs). No PRs were created and no issue comments were posted despite valid passing verdicts and committed code.

Affected issues: ah #258 (×2 runs), ah #186, cosmic #299 (×2 runs), cosmic #290.

### 2. cosmic do-phase timeout (run 22513261191)

cosmic issue #299 ("add --check-style") caused the do phase to time out twice (Error 124, ~5 min each). work.mk retries do once on timeout; both attempts exhausted the time budget. The issue is a substantial feature addition that exceeds the agent's single-session time limit.

```
make[1]: *** [work.mk:193: o/do/done] Error 124
make[1]: *** [work.mk:193: o/do/done] Error 124
make: *** [work.mk:256: work] Error 2
```

### 3. cosmic pre-existing CI failure (run 22513261191)

The cosmic build phase returned exit=2 before do ran, indicating pre-existing CI failures on the branch. The agent proceeded into do anyway.

## Work Loop Outcomes

| repo | issue | verdict | PR |
|---|---|---|---|
| whilp/ah | #258 fix tool call display truncation | pass | not created (act failed) |
| whilp/ah | #258 (retry) | pass | not created (act failed) |
| whilp/ah | #186 walk ancestor dirs for context files | pass | not created (act failed) |
| whilp/cosmic | #299 add --check-style | needs-fixes / timeout | not created |
| whilp/cosmic | #299 (retry) | timeout | not created |
| whilp/cosmic | #290 generalize doc depth | pass | not created (act failed) |
| whilp/working | — | no_issues (skipped) | — |

## Patterns

- **act phase is completely broken**: 0 of 6 act-phase job-runs succeeded. All failed on the same tmp file error. This is the single highest-priority issue.
- **working no_issues**: whilp/working consistently hits the PR limit (4 open PRs) and finds no todo issues. The pick phase correctly handles this.
- **cosmic issue #299 is oversized**: Two separate runs timed out attempting this feature. It should be split into smaller sub-issues.
- **success/failure label discrepancy**: Runs with act failures are reported as `success` by GitHub Actions because act failures don't fail the job. This masks real failure.
- **issue #258 picked twice**: ah picked the same issue (#258) in two consecutive runs (02:43Z and 04:23Z), both completing with pass verdict, both unable to create a PR. The doing label should prevent re-pick, but wasn't preventing it (or was cleared between runs).

## Recommendations

1. **Fix `os.tmpname()` / gh tmp file bug in act phase.** `os.tmpname()` returns a path without creating it. The gh wrapper must either pre-create the file (`io.open(path, "w"):close()`) or use a different temp file strategy. This is blocking 100% of act-phase tool calls.

2. **Split cosmic issue #299 ("add --check-style") into smaller pieces.** It has timed out twice. Break it into: (a) wire up the flag, (b) implement file-level style check, (c) integrate with existing lint. Each should be completable in a single do session.

3. **Propagate act-phase failures to job exit code.** Currently act failures are silently swallowed and the run is marked success. Act should exit non-zero if any action fails, so failures are visible in the workflow run conclusion.

4. **Investigate doing-label clearing between consecutive runs.** Issue #258 was picked in two consecutive hourly runs. If the doing label is set at pick time and cleared at act time, a failed act would leave the label set — investigate why it was picked again.

5. **Guard do phase on build exit code.** If the build phase returns non-zero (pre-existing CI failure), skip do and emit a clear error rather than proceeding into a broken state.
