# Reflection: 2026-05-22

## Summary

20 work loop runs executed across the day for three repos (whilp/working, whilp/ah, whilp/cosmic). No actual work was performed in any run. whilp/working was blocked by a massive PR backlog (56–57 open PRs vs. a 4-PR limit) on every run. whilp/ah and whilp/cosmic had no open issues throughout the day. Two runs failed (one due to a transient API outage, one due to an API 400 error from an empty tool result).

## Runs

| workflow | total | pass | fail | cancel |
|---|---|---|---|---|
| work | 20 | 18 | 2 | 0 |

## Failure Analysis

### Run 26269808661 — API outage (05:15 UTC)

All three matrix jobs failed simultaneously with `error: no response` after 3–7 seconds. No API calls were made. Root cause: transient Claude API unavailability. Self-resolved; subsequent runs succeeded.

```
##[error]no response
##[error]must_produce: o/pick/issue.json not created
[run-ah] exited 1 after 3s
```

### Run 26298028987 — Empty tool result → API 400 (15:55 UTC)

whilp/cosmic pick failed after `list_issues` returned `{}` (empty/malformed result). ah forwarded this empty result back to the API, which rejected it:

```
> list_issues
  {}
< 0.4s, 1 line

error: API error 400: messages.5.content: Input should be a valid array
error: must_produce: o/pick/issue.json not created
```

Root cause: `list_issues` returning empty/null and ah not handling it gracefully before constructing the next API message.

## Work Loop Outcomes

No issues were picked, no PRs were created, and no plan/do/check phases ran on any of the 20 runs.

- **whilp/working**: `pr_limit` on every run — 56 open PRs at start of day, 57 by end.
- **whilp/ah**: `no_issues` on every run (0 open PRs, no todo issues).
- **whilp/cosmic**: `no_issues` on most runs (2 open PRs but no todo issues); one failure due to empty tool result.

## Patterns

- **pr_limit dominates**: whilp/working is completely blocked. 57 open PRs vs. a cap of 4 means this repo cannot do any work until the backlog is dramatically reduced. The count is not decreasing day-over-day, suggesting PRs are not being merged or closed.
- **Idle satellites**: whilp/ah and whilp/cosmic have no open issues and no feedback PRs. These repos are fully idle with nothing to pick.
- **Recurring transient API retries**: Multiple runs logged `UNKNOWN ERROR CODE 004C` retries (delay ~650–750ms) before succeeding — a minor but consistent network-layer flakiness.
- **Fast runs**: All successful runs completed in 13–38 seconds (pick-only paths). No expensive plan/do/check work was done.
- **Empty tool result bug**: The `list_issues {} → API 400` failure pattern is a known fragility — ah does not guard against empty tool responses before building the next message.

## Recommendations

1. **Triage whilp/working PR backlog**: 57 open PRs is far above the 4-PR limit and blocks all automation. Audit open PRs: merge, close stale ones, or raise the pr_limit threshold after cleanup. This is the single biggest blocker.

2. **Fix empty tool result handling**: When a tool returns `{}` or null, ah should treat it as an error or skip rather than forwarding an invalid payload to the Anthropic API. The API 400 `messages.N.content: Input should be a valid array` pattern is preventable in ah or cosmic's tool dispatch layer.

3. **Create issues for whilp/ah and whilp/cosmic**: Both repos are idle due to `no_issues`, not `pr_limit`. If there is no work to pick, new issues need to be created (via triage or manually) to keep the work loop productive.

4. **Add alerting for sustained pr_limit**: If a repo hits pr_limit for N consecutive runs (e.g., 10+), emit a warning or create an issue in the repo to flag the backlog. Currently the loop silently skips without escalating.
