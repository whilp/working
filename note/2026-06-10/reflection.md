# Reflection: 2026-06-10

## Summary

16 work runs executed throughout the day. 15 succeeded, 1 failed. No actual work was performed in any run — every repo hit an early-exit condition at the pick phase. `whilp/working` was blocked by `pr_limit` (74–75 open PRs vs. a limit of 4) on every run. `whilp/ah` and `whilp/cosmic` had no open todo issues all day. One run (16:14 UTC) failed due to GitHub App auth errors (HTTP 401) for two of three repos.

## Runs

| workflow | total | pass | fail | cancel |
|---|---|---|---|---|
| work | 16 | 15 | 1 | 0 |

## Failure Analysis

### Auth failure (1 run — 27289571083, 16:14 UTC)

Two of three matrix jobs (`whilp/working`, `whilp/ah`) returned HTTP 401 when calling the GitHub API during pick. `whilp/cosmic` succeeded, suggesting a partial token issue rather than total outage. Self-resolved by the next run.

```
errors: todo: HTTP 401: Requires authentication
all tools returned 401. wrote {"error": "auth_failure"} to o/pick/issue.json
```

Root cause: transient GitHub App installation token failure — token was generated but lacked access to the `working` and `ah` repos at that point. No action taken; next run succeeded.

### Transient Anthropic API retries (3 runs — 27281941268, 27295630566, 27299484973)

`UNKNOWN ERROR CODE 004C` errors observed on `whilp/ah` and `whilp/cosmic` pick phases in multiple runs. All retried successfully. No impact on outcome.

## Work Loop Outcomes

No issues were picked or worked in any run. All 16 runs exited at pick with one of two outcomes:

| repo | outcome | reason |
|---|---|---|
| whilp/working | `pr_limit` (every run) | 74–75 open PRs; limit is 4 |
| whilp/ah | `no_issues` (every run) | no open todo issues |
| whilp/cosmic | `no_issues` (every run) | no open todo issues |

No plans, no do phases, no PRs created, no check verdicts.

## Patterns

- **pr_limit blocker is total**: `whilp/working` was blocked on every single run (16/16). The 74–75 open PR backlog is ~18–19× the 4-PR limit. The work loop cannot make progress on this repo without external intervention.
- **ah and cosmic are fully triaged**: Both repos reported `no_issues` across all 16 runs. No new todo issues appeared all day.
- **pick-only runs are fast**: All successful runs completed in 15–80 seconds (pick phase only, no agent sessions). The 80s outlier was due to API retries inflating `whilp/ah` pick to 63s.
- **auth failures are transient**: The single failure run (27289571083) self-healed; the next run succeeded. No follow-up needed.
- **PR count crept up**: 74 open PRs at start of day → 75 by later runs, suggesting no PRs were merged or closed during the day.

## Recommendations

1. **Triage the whilp/working PR backlog**: 75 open PRs completely blocks the work loop. Audit open PRs — close stale ones, merge ready ones, or raise the `pr_limit` threshold if the current limit is too conservative. This is the single highest-impact unblock.

2. **Add alerting for persistent pr_limit blocks**: If a repo hits `pr_limit` for N consecutive runs (e.g. 5+), file an issue or send a notification. Silent skipping makes the backlog invisible until a human reads the logs.

3. **Investigate auth_failure retry logic**: The 16:14 UTC run failed rather than retrying. The work loop could retry the pick phase once on `auth_failure` before marking the run as failed, since these errors are consistently transient.

4. **Create issues for ah and cosmic**: Both repos have been issue-free all day. If there is intended future work, seed todo issues so the work loop has something to pick.
