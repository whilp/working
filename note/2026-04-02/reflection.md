# Reflection: 2026-04-02

## Summary

24 scheduled work runs executed across the day. All three repos (whilp/working, whilp/ah, whilp/cosmic) participated in each run. No substantive work was performed — every run exited at the pick phase. whilp/working was consistently blocked by a pr_limit (7–8 open PRs vs. limit of 4). whilp/ah and whilp/cosmic consistently had no open todo issues. One run failed due to an Anthropic API 400 error during cosmic's pick phase.

## Runs

| workflow | total | pass | fail | cancel |
|---|---|---|---|---|
| work | 24 | 23 | 1 | 0 |

## Failure Analysis

### API 400: malformed message body (run 23897703100, 2026-04-02T11:14:36Z)

During whilp/cosmic's pick phase, the Anthropic API returned HTTP 400:

```
error::API error 400: messages.5.content: Input should be a valid list
error: must_produce: o/pick/issue.json not created
```

Root cause: the ah harness sent a messages array where `messages[5].content` was not a valid list. This is a message construction bug — the API rejected the request before any model processing. The error is deterministic (not transient) and will recur if the same message shape is sent again. The other two jobs in the same run (ah, working) completed normally.

## Work Loop Outcomes

No issues were picked, planned, executed, or reviewed across all 24 runs.

**Per-repo pick outcomes (all 24 runs):**

| repo | outcome | detail |
|---|---|---|
| whilp/working | `pr_limit` (all 24) | 7 open PRs early in day, grew to 8 by ~07:26 UTC; limit is 4 |
| whilp/ah | `no_issues` (all 24) | no todo-labeled issues, no PRs with feedback |
| whilp/cosmic | `no_issues` (23 runs), `api_error` (1 run) | no todo issues; one pick crashed with API 400 |

No PRs were created. No issues were transitioned. Work loop produced no artifacts (no issue.json, plan.md, do.md, check/actions.json).

## Patterns

- **PR backlog blocking work**: whilp/working had 7–8 open PRs all day, well above the 4-PR limit. The work loop is fully blocked on this repo until PRs are reviewed and merged or closed. This has been a persistent multi-day pattern.
- **Empty queues on ah and cosmic**: Neither whilp/ah nor whilp/cosmic had any todo-labeled issues. The work loop cannot self-generate work — issues must be created and labeled `todo` externally.
- **Run duration**: Each run completed in ~25–38s total (3 parallel pick phases only). No expensive plan/do/check cycles ran.
- **API 400 error is isolated**: Only one run hit the message construction error. It did not recur in subsequent runs, suggesting either a transient bad message shape or an environmental factor that resolved itself. Worth monitoring.
- **PR count grew during the day**: whilp/working went from 7 open PRs (early runs) to 8 (by ~07:26 UTC), suggesting a new PR was opened during the day but none were merged or closed.

## Recommendations

1. **Triage and merge/close open PRs on whilp/working**: 8 open PRs is 2× the pr_limit. Review each open PR — merge ready ones, close stale or superseded ones. Until the count drops below 4, the work loop is fully blocked on this repo.

2. **Create and label todo issues for whilp/ah and whilp/cosmic**: Both repos have empty issue queues. If there is work to do, issues need to be created and labeled `todo`. Consider running a triage pass to identify and label actionable work.

3. **Investigate the API 400 message construction bug**: The error `messages.5.content: Input should be a valid list` indicates ah is sending a malformed messages array to the Anthropic API. Reproduce by checking what message shape is produced during pick for whilp/cosmic and fix the content field to always be a list.

4. **Add alerting for persistent pr_limit blocks**: If a repo hits pr_limit for N consecutive runs, emit a warning or notification. Currently the condition is silent — it only appears in reflect logs. A GitHub issue or comment would surface it to maintainers sooner.
