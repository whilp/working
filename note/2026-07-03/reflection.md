# Reflection: 2026-07-03

## Summary

21 work runs executed throughout the day. Nearly all skipped without doing any work — whilp/working is completely blocked by a massive open PR backlog (97–98 PRs, threshold is 4), and whilp/ah and whilp/cosmic have no open todo issues. Exceptions: two runs did real work on cosmic PRs (pass verdicts), one run failed due to a Claude API rate limit hit, and one run failed because sandbox network blocks git push.

## Runs

| workflow | total | pass | fail | cancel |
|---|---|---|---|---|
| work | 21 | 19 | 2 | 0 |

Failures:
- `28681814315` — Claude API 429 rate limit hit across all three parallel jobs simultaneously
- `28685719542` — cosmic PR #422 rebased successfully but `git push` blocked by sandbox proxy

## Failure Analysis

### Claude API 429 rate limit (1 run)

Run `28681814315` (20:22Z): three parallel jobs hit the API rate limit simultaneously at the pick phase. The API returned a 3454s retry delay; the 60s max caused immediate abort.

```
error: server requested 3454s retry delay (max: 60s). API error 429
error: must_produce: o/pick/issue.json not created
```

Root cause: concurrent job fan-out exhausted the rate limit budget in a single burst. No work was done; run duration was ~14 seconds.

### Sandbox network blocks git push (1 run)

Run `28685719542` (22:18Z): cosmic PR #422 was picked for merge_conflict resolution. The do phase correctly rebased the branch on main locally, but `git push --force-with-lease` failed because the sandbox only allows `api.anthropic.com:443`.

```
error: failed to push some refs to 'https://github.com/whilp/cosmic.git'
make[1]: *** [work.mk:226: o/push/done] Error 1
```

Root cause: the push step runs inside the sandbox where HTTPS to GitHub is blocked. The harness appears to handle push in some cases but not this one (the do phase had already run, leaving nothing to do).

## Work Loop Outcomes

| run | repo | issue/pr | verdict | pr |
|---|---|---|---|---|
| 28642078325 | whilp/cosmic | PR #418 (retire cosmo.sandbox) | pass | https://github.com/whilp/cosmic/pull/418 |
| 28672625461 | whilp/cosmic | PR #403 (httpapi framework) | pass | https://github.com/whilp/cosmic/pull/403 |
| 28685719542 | whilp/cosmic | PR #422 (Errno/union types) | partial (push blocked) | — |

All other runs: skip (no_issues or pr_limit).

Two cosmic PRs advanced successfully with pass verdicts and were labeled `needs-review`. One cosmic PR was worked but could not be pushed due to sandbox limitations. whilp/working produced zero work all day due to pr_limit. whilp/ah produced zero work all day due to no_issues.

## Patterns

**whilp/working pr_limit is a total blocker.** All 21 runs reported `pr_limit` for working (97–98 open PRs vs. threshold 4). The work loop cannot make progress on this repo at all. The PR count has been at this level for multiple days.

**whilp/ah and whilp/cosmic have no issues.** Both repos consistently returned `no_issues` all day. Cosmic picked up work from PRs with merge_conflict or feedback reasons, not new issues.

**Parallel job rate limiting.** When three jobs run simultaneously and all hit the API at the same moment, a single rate limit burst kills all three. The 60s retry cap means there is no recovery — the run simply fails.

**Transient API retries are common but usually recover.** Runs `28675105823` and `28677333099` each logged a `004C` error that retried once and succeeded. The rate limit failure is different in kind — the delay requested was 57+ minutes.

**Pick-only runs are very fast (~15–35s).** All skip runs completed in under 40 seconds, consistent with the API call for pick being the only significant work.

## Recommendations

1. **Triage whilp/working open PRs.** With 97–98 open PRs against a threshold of 4, the work loop is permanently blocked. A bulk triage pass to close stale, superseded, or draft PRs is needed. Consider running the triage skill against whilp/working's PR list specifically.

2. **Stagger parallel job API calls to avoid rate limit bursts.** The three parallel work jobs all call the Claude API at nearly the same second. Adding a small per-job jitter (e.g., `sleep $((RANDOM % 30))` before the first API call) would spread the budget consumption and prevent simultaneous 429s.

3. **Raise or configure the pr_limit per-repo.** The current threshold of 4 was probably set for whilp/working when it had a smaller backlog. Either raise the limit for that repo, or create a separate threshold config, so the limit doesn't permanently block the loop.

4. **Investigate and create issues for whilp/ah.** The repo has had `no_issues` all day. Either work is complete and needs documentation, or new issues need to be filed. Running a triage/audit to surface latent work items would unblock the ah loop.

5. **Fix or document the sandbox push failure mode.** PR #422 on cosmic was rebased correctly but could not be pushed because the sandbox blocks HTTPS to GitHub. If this is expected behavior (harness handles push externally), the do phase should not attempt `git push` at all — or the failure should not cause a run-level failure.
