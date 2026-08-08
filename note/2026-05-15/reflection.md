# Reflection: 2026-05-15

## Summary

20 work workflow runs executed throughout the day across three repos (whilp/working, whilp/ah, whilp/cosmic). Zero issues were worked. Every run stalled at the pick phase — whilp/working was blocked all day by a massive PR backlog (49–50 open PRs vs. the 4-PR limit), while whilp/ah and whilp/cosmic had no open todo issues. One run (02:59 UTC) failed entirely due to a transient GitHub Releases CDN outage affecting dependency downloads.

## Runs

| workflow | total | pass | fail | cancel |
|---|---|---|---|---|
| work | 20 | 19 | 1 | 0 |

## Failure Analysis

### GitHub Releases CDN 504 (run 25897799734)

All three matrix jobs failed at dependency download — curl returned HTTP 504 for both `ah` and `cosmic` binary fetches. No retry logic exists in the Makefile fetch targets, so a single transient 504 causes the entire run to abort.

```
curl: (22) The requested URL returned error: 504
make: *** [Makefile:39: o/bin/.ah-raw] Error 22
```

This is a known fragility. Adding `--retry 3 --retry-delay 5` to curl invocations in the Makefile would eliminate this class of failure.

## Work Loop Outcomes

No issues were worked on any day. All runs exited at pick with one of two skip codes:

- **`pr_limit`** — whilp/working fired this on every successful run. The open PR count was 49 at midnight, rising to 50 by mid-morning and holding there for the rest of the day.
- **`no_issues`** — whilp/ah and whilp/cosmic consistently returned this. No open todo-labeled issues exist in either repo.

No PRs were created. No plans were written. No verdicts were rendered.

## Patterns

- **PR backlog dominates**: whilp/working's 50 open PRs (vs. a limit of 4) blocks 100% of work loop execution for that repo. This pattern has persisted for multiple days.
- **ah/cosmic are idle**: Both repos have no open todo issues. The work loop has nothing to pick even if it could — issues need to be created or labeled.
- **Runs are very fast (~30s)**: All pick-only runs complete in 30–35s, almost all of which is setup and pick invocation. No compute is wasted on planning or execution.
- **Transient API/SSL retries**: Two runs logged transient errors (network retry in 25895375676, SSL retry in 25939556397) but both recovered automatically. These are noise.
- **CDN failures not retried**: The single hard failure (25897799734) was caused by GitHub CDN unavailability and had no retry path.

## Recommendations

1. **Add curl retry to dependency downloads**: Update Makefile fetch targets to use `curl --retry 3 --retry-delay 5` for `ah` and `cosmic` binary downloads. This eliminates transient CDN failures causing full run aborts.

2. **Triage whilp/working's 50 open PRs**: The work loop is completely blocked on this repo. Run the triage skill or manually close stale/superseded PRs to bring the count below 4. Until then, the work loop produces no value for whilp/working.

3. **Create todo issues for whilp/ah and whilp/cosmic**: Both repos have no open todo issues — the work loop has nothing to pick. Identify pending work items and open issues with the `todo` label so the pick phase has candidates.

4. **Raise or make pr_limit configurable per repo**: A single global limit of 4 PRs may be too low for whilp/working given its activity level. Consider making the threshold per-repo or raising it to allow work to proceed even with a moderate backlog.
