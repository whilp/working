# Reflection: 2026-04-28

## Summary

21 scheduled work runs fired across the day (all for the `work` workflow). No actual work was performed in any run. Every run terminated at the pick phase — whilp/working was blocked by a massive PR backlog (32–33 open PRs far exceeding the 4-PR limit), while whilp/ah and whilp/cosmic had no open todo issues. One run failed due to a Claude API 400 error during the pick phase for whilp/cosmic.

## Runs

| workflow | total | pass | fail | cancel |
|---|---|---|---|---|
| work | 21 | 20 | 1 | 0 |

## Failure Analysis

### API 400: malformed messages payload (run 25078300630)

During the whilp/cosmic pick phase, the Claude API returned a 400 error:

```
API error 400: messages.5.content: Input should be a valid list
must_produce: o/pick/issue.json not created
Process completed with exit code 2
```

Root cause: message content was not structured as a list as the API requires. This is a bug in how ah or cosmic constructs tool results/content blocks for certain conversation states. The error is non-deterministic — whilp/cosmic completed normally in all other runs.

### Transient API retry (run 25055826188)

whilp/cosmic hit a transient API retry (attempt 1, delay 546ms, `UNKNOWN ERROR CODE 004C`) before completing successfully. Isolated event, no follow-up needed.

## Work Loop Outcomes

- **Issues picked**: 0 (all runs skipped at pick phase)
- **Plans written**: 0
- **PRs created**: 0
- **Verdicts**: none

All three repos were idle all day:
- **whilp/working**: blocked every run by `pr_limit` — 32–33 open PRs against a cap of 4.
- **whilp/ah**: `no_issues` all day — no open todo issues, no PRs with feedback.
- **whilp/cosmic**: `no_issues` all day (plus one API failure).

## Patterns

- **Complete stasis**: the work loop ran 21 times and did nothing. This has likely been ongoing for multiple days given the 32–33 PR count on whilp/working.
- **Pick-only runs are very fast**: each run completed in 26–43 seconds total, consistent with pick-only paths (15–20s per repo).
- **PR backlog grew**: whilp/working went from 32 to 33 open PRs during the day, indicating PRs are still being opened but not merged or closed.
- **ah and cosmic are quiescent**: no issue queue activity, no PRs needing review. The agent has nothing to do on those repos.
- **API 400 on cosmic pick is sporadic**: it has appeared before and is likely triggered by a specific conversation state or tool response format.

## Recommendations

1. **Triage and close stale PRs on whilp/working**: with 33 open PRs against a cap of 4, the work loop is permanently blocked. Audit PRs — close ones that are stale, superseded, or no longer relevant. Target getting below 4 open PRs so work can resume.

2. **Add a triage workflow for PRs**: the work loop has no mechanism to automatically close or batch-review old PRs. A dedicated `triage-prs` phase or scheduled job that closes PRs older than N days (or with no activity) would prevent this kind of stasis.

3. **Raise an issue for the API 400 message format bug**: `messages.5.content: Input should be a valid list` indicates ah is sending a non-list content block at a specific conversation turn. Reproduce and fix the message construction to ensure content is always a list.

4. **Add todo issues to ah and cosmic**: the work loop has had nothing to do on those repos all day. If there is planned work, open issues with the `todo` label so the agent can pick them up.

5. **Add a pr_limit health check**: emit a warning or create an issue when the open PR count exceeds 2× the limit (i.e., >8). This would surface the growing backlog earlier rather than letting it reach 33.
