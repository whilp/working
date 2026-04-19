# Reflection: 2026-04-18

## Summary

22 scheduled work runs executed across three repos (whilp/working, whilp/ah, whilp/cosmic). The day was dominated by a persistent PR backlog blocker on whilp/working (22–23 open PRs vs a 4-PR cap) and empty issue queues on whilp/ah and whilp/cosmic — leaving the work loop idle for all but one run. Two runs failed due to a transient GitHub Releases CDN outage (HTTP 504). One productive run resolved a merge conflict on whilp/cosmic PR #403.

## Runs

| workflow | total | pass | fail | cancel |
|---|---|---|---|---|
| work | 22 | 20 | 2 | 0 |

## Failure Analysis

### GitHub Releases CDN 504 (runs 24608556017, 24609674099)

Both failures occurred in a ~2-hour window (16:07–17:09 UTC) and affected all three matrix jobs simultaneously. curl returned HTTP 504 when downloading `cosmic-lua` and `ah` binaries from GitHub Releases. This is a transient infrastructure issue, not a code defect.

```
curl: (22) The requested URL returned error: 504
make: *** [Makefile:28: o/bin/cosmic] Error 22
```

No retry logic exists in the Makefile fetch step — a single 504 aborts the whole run.

## Work Loop Outcomes

- **Issues attempted**: 1 (whilp/cosmic PR #403 — httpapi framework, merge conflict resolved)
- **Verdicts**: 1 pass
- **PRs created/updated**: PR #403 pushed (whilp/cosmic)
- **Skipped (pr_limit)**: 21 runs × whilp/working — 22–23 open PRs exceed the 4-PR cap
- **Skipped (no_issues)**: 21 runs × whilp/ah, 21 runs × whilp/cosmic

The only productive work was in run 24615958792 (23:07 UTC): whilp/cosmic's pick found PR #403 had a merge conflict, the do phase resolved it in two attempts (~283s combined), and the run earned a pass verdict.

## Patterns

- **PR backlog blocker is dominant**: whilp/working had 22 open PRs at start of day, growing to 23 by mid-day, blocking every pick for that repo. This is not transient — it has persisted across multiple days.
- **Empty queues on ah and cosmic**: no todo-labeled issues exist for these repos, so pick always exits with `no_issues`. The work loop has nothing to pick until issues are triaged and labeled.
- **Runs are fast but idle**: most runs completed in 15–37s (pick-only), consuming CI minutes without producing work.
- **One transient API retry observed**: run 24605645390 logged an `UNKNOWN ERROR CODE 004C` retry during pick (604ms delay) but recovered — pick API is somewhat flaky but self-healing.
- **Merge conflict recovery worked**: the do phase's rebase/reset logic handled a pre-existing conflict correctly in run 24615958792.
- **CI in cosmic has a pre-existing failure** (`fs_dir_test.tl`) unrelated to the httpapi work — worth tracking separately.

## Recommendations

1. **Add curl retry logic to Makefile dependency fetch**: the 504 failures would have been avoided with `curl --retry 3 --retry-delay 5`. Two runs were lost to a transient CDN hiccup.

2. **Automate PR triage for whilp/working**: 23 open PRs blocking the work loop is unsustainable. Add a workflow or scheduled job that flags stale PRs (no activity > N days) for auto-close or prompts human review.

3. **Raise the pr_limit threshold or implement partial work**: the current 4-PR cap is conservative — consider raising to 8–10 to allow new work to proceed in parallel with existing PRs, or implement a mode that works on existing PRs (review feedback) even above the cap.

4. **Triage issues for whilp/ah and whilp/cosmic**: both repos have empty todo queues. Run a triage pass to label or create actionable issues so the work loop has something to pick.

5. **Track the pre-existing `fs_dir_test.tl` failure in whilp/cosmic**: it was ignored in run 24615958792 but will mask future CI regressions. File an issue and fix or skip it.
