# Reflection: 2026-02-23

## Summary

Two scheduled work runs executed. Three repos were checked each time (whilp/ah, whilp/cosmic, whilp/working). Four of six jobs exited early (`no_issues`). Two jobs completed full work loops — cosmic (verdict: needs-fixes) and ah (verdict: pass). Both act phases failed due to a recurring `/tmp` file error in the gh CLI wrapper, leaving a branch pushed but no PR or comment created.

## Runs

| workflow | total | pass | fail | cancel |
|---|---|---|---|---|
| work | 2 | 2 | 0 | 0 |

Both workflow runs have conclusion `success` — the matrix jobs themselves succeeded. However both act phases failed internally (`actions_failed > 0`).

## Failure Analysis

### 1. gh CLI `/tmp` file error (act phase) — both runs

Both runs hit the same error pattern in the act phase:

```
comment_issue failed: gh failed (exit 1): open /tmp/lua_<id>: no such file or directory
create_pr failed: gh failed (exit 1): open /tmp/lua_<id>: no such file or directory
```

Root cause: the lua gh wrapper creates a temp file and fails when it can't be opened. This is a transient sandbox/filesystem issue. It has now occurred in multiple consecutive runs (noted as recurring in run 22309901915 analysis). Work is not lost (branches are pushed), but PRs and issue comments are never created automatically.

### 2. Implementation missed plan detail (cosmic, run 22309901915)

Check phase for cosmic #312 (`--write-if-changed` flag) found two bugs:
- `opts.output` not pre-scanned — `write_if_changed_write` always returns error, feature non-functional.
- `sys/help.md` not updated — caused `args_test` and `help_test` failures.

CI: 59/65 tests pass, 4 new regressions. Verdict: `needs-fixes`. The plan correctly identified the early-return risk in its own risk section, but the do phase missed extending the pre-scan to cover `-o`/`--output`.

## Work Loop Outcomes

| run | repo | issue | verdict | PR |
|---|---|---|---|---|
| 22309901915 | whilp/cosmic | #312 — add --write-if-changed flag | needs-fixes | branch pushed, no PR (needs-fixes) |
| 22325047712 | whilp/ah | #258 — fix inconsistent tool call display | pass | branch pushed, act failed (no PR created) |

- whilp/ah and whilp/working had `no_issues` in both runs.
- For ah #258: fix was clean — 4-line normalization in `lib/ah/cli.tl`, 3 new tests, all 23 tests passed. Branch `work/258-a3f7c12e` is ready but no PR was filed.

## Patterns

- **act phase failure is now a consistent blocker**: at least 2 consecutive daily runs have hit the `/tmp/lua_*` error. PRs are never being created automatically. This defeats the purpose of the pass verdict.
- **no_issues across ah and working**: both repos have had no todo issues for multiple consecutive runs. Either open issues exist but aren't labeled `todo`, or the backlog is genuinely empty.
- **do phase misses plan details**: the cosmic do phase had a well-written plan (including a risk section) but still missed one specified step. Suggests the do phase does not re-read the risk section before committing.
- **phase timings stable**: ah full loop ~10 min, cosmic full loop ~17 min (including 3.5 min build). No duration anomalies.

## Recommendations

1. **Fix gh CLI temp file error in act phase.** The `/tmp/lua_*` error blocks all PR creation and issue commenting. Investigate why gh creates temp files and whether the wrapper can use a different mechanism (e.g., pass data via stdin or use a named pipe). File as a bug in the lua gh wrapper. This is the highest-priority fix — the entire act phase is broken.

2. **Create PR manually for ah #258.** Branch `work/258-a3f7c12e` is ready with a passing check. The PR should be created for whilp/ah to avoid losing the work.

3. **Add a post-act health check.** The workflow run concludes `success` even when `act.json` records `actions_failed > 0`. Add a step that reads `act.json` and fails the job if `actions_failed > 0`, so act failures are visible in the workflow conclusion.

4. **Audit issue labels in ah and working.** Two consecutive runs found `no_issues` for both repos. Check whether open issues exist without the `todo` label — if so, either triage them or adjust the pick skill to surface them.

5. **Do phase: re-read plan risk section before finalizing.** For cosmic #312, the plan's own risk section described the pre-scan gap but do missed it. Add an explicit step in the do skill to revisit the plan's risks/notes before marking work complete.
