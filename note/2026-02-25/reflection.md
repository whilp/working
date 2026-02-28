# Reflection: 2026-02-25

## Summary

Four work loop runs executed on 2026-02-25. Two failed (early morning runs) and two succeeded (afternoon runs). The dominant issue was a recurring `/tmp` lua temp-file error in the gh CLI wrapper that caused act-phase failures across all four runs, preventing any PR from being created despite clean code changes. The whilp/cosmic do-phase timeout (issue #312) also caused two failures early in the day.

## Runs

| workflow | total | pass | fail | cancel |
|---|---|---|---|---|
| work | 4 | 2 | 2 | 0 |

## Failure Analysis

### 1. Act-phase `/tmp` temp-file error (all 4 runs, whilp/ah)

Every run that reached the act phase for `whilp/ah` failed with:

```
comment_issue failed: gh failed (exit 1): open /tmp/lua_XXXXXX: no such file or directory
create_pr failed: gh failed (exit 1): open /tmp/lua_XXXXXX: no such file or directory
```

The Lua gh CLI wrapper generates a temp file path but does not create the file before passing it to `gh`, which then fails to open it. This caused `act.json` to record `"actions_failed":2` even when the work itself was fully successful (verdict: pass, branch pushed). No PR was ever filed for issue #258 despite four attempts with passing verdicts.

### 2. whilp/cosmic do-phase timeout (runs 22375710330 and 22405676802)

Issue #312 (`--write-if-changed` flag) caused the `do` agent to time out twice (300s each) in both early runs. The cosmic build phase itself takes ~3.5 minutes, leaving minimal budget for the do agent. In the second run, the build also exited with code 2, suggesting the repo's own CI may have been failing. The afternoon runs did not attempt cosmic #312 (no `todo` issues found).

### 3. whilp/ah do-phase timeout (run 22409929625, first attempt only)

One do-phase timeout on the first attempt, auto-retried and succeeded. The ah CI takes ~2 minutes, leaving ~3 minutes for the do agent — tight for any non-trivial change.

## Work Loop Outcomes

| repo | issue | verdict | PR |
|---|---|---|---|
| whilp/ah | #258 — fix inconsistent tool call display | pass (×4) | none created (act failed every time) |
| whilp/cosmic | #312 — add `--write-if-changed` flag | no verdict (×2 timeout) | none |
| whilp/working | — | no_issues (×4) | — |

Issue #258 on whilp/ah was picked and completed successfully four times across the day. The work is done and committed — only the PR posting step failed each time.

## Patterns

- **Act phase is broken for gh CLI actions**: every act execution failed. This is systemic, not transient — the same temp-file error appeared 8+ times across all runs. The Lua gh wrapper has a bug in temp file creation.
- **whilp/working and whilp/cosmic deplete their issue queues**: by afternoon, both repos reported `no_issues`. The `todo` label backlog is empty.
- **Do-phase timeout pressure**: both ah (~2 min build) and cosmic (~3.5 min build) leave tight margins in a 300s do budget. Complex issues like cosmic #312 are structurally incompatible with the current timeout.
- **Retry on timeout works**: the ah do retry succeeded on the second attempt, showing the retry logic is useful but adds latency.

## Recommendations

1. **Fix the Lua gh CLI temp-file bug**: the act phase `comment_issue` and `create_pr` tools fail because the temp file path is generated but not created before being passed to `gh`. The fix is to use `io.tmpfile()` or write content to the file before opening it in gh. This is a P0 fix — PRs are not being created.

2. **Post-act recovery for whilp/ah #258**: issue #258 has a passing branch (`work/258-*`) already pushed. Manually create a PR or fix the act harness and re-run to pick it up.

3. **Increase do-phase timeout or split complex issues**: the 300s do timeout is too short for repos with slow CI builds. Consider: (a) raising the timeout to 600s, (b) excluding build time from the do budget, or (c) labeling complex issues as `large` and skipping them until the timeout is tunable.

4. **Triage cosmic #312**: the `--write-if-changed` flag is too complex for a single do session given cosmic's build time. Split into smaller issues or increase the timeout.

5. **Add a `todo`-issue backlog replenishment mechanism**: whilp/working and whilp/cosmic run out of `todo` issues, causing wasted work-loop cycles. A triage or issue-creation step could refill the queue.
