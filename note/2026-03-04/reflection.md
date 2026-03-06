# Reflection: 2026-03-04

## Summary

5 workflow runs analyzed (all work loop, scheduled). 4 succeeded, 1 failed. whilp/ah was the only active repo — whilp/cosmic and whilp/working consistently had no todo issues. ah completed 3 successful work items and 1 double-timeout failure on an over-ambitious refactor.

## Runs

| workflow | total | pass | fail | cancel |
|---|---|---|---|---|
| work | 5 | 4 | 1 | 0 |

## Failure Analysis

**Double do-phase timeout (run 22668535957)**

- Issue #317 ("Investigate consolidating in a single db file") had an empty body and a `needs-info` label.
- The plan phase produced a large multi-file schema migration spanning `db.tl`, `queue.tl`, `sessions.tl`, and `init.tl`.
- Both do sessions timed out at exactly 300s. No PR created, no verdict recorded.
- Root cause: empty issue body with vague title led to an over-scoped plan that exceeded two 5-minute do windows.

## Work Loop Outcomes

| run | issue | verdict | pr |
|---|---|---|---|
| 22654053002 | #350 "make ah learnable" | pass ✅ | `docs: add \`ah docs <query>\` subcommand` |
| 22659039299 | #452 "session state machine is implicit and crash-unsafe" | pass ✅ | `session: reset processing state on crash recovery` |
| 22660498694 | #314 "sandbox: support read-only workspace mode" | pass ✅ | `sandbox: add --sandbox-ro flag` |
| 22668535957 | #317 "Investigate consolidating in a single db file" | none ❌ | none (double timeout) |
| 22685052808 | (none) | — | all repos idle, no todo issues |

whilp/cosmic and whilp/working had no todo issues in any run.

## Patterns

- **Do-phase retries are common**: 3 of 4 work runs required 2 do sessions. In 2 cases (runs 22654053002, 22659039299) this was a productive retry (changes made but not committed, or first session timed out early). In run 22660498694, first session hit 300s timeout but second succeeded. Only run 22668535957 saw both sessions fail.
- **Empty issue bodies lead to bad plans**: Issue #317 had an empty body. The plan phase filled the gap with an ambitious interpretation, producing work too large for the do timeout.
- **All-idle state reached**: By the evening run (22685052808), all three repos had zero todo issues simultaneously — the backlog was fully cleared.
- **Phase timing (whilp/ah typical)**: pick ~44s, build ~2m20s, plan ~1–1.5m, do 4–10m (with retries), check ~1.5–2m, act <10s.

## Recommendations

1. **Skip or reject issues with empty bodies**: The pick skill should deprioritize or refuse issues labeled `needs-info` with empty bodies. These reliably produce over-scoped plans and do-phase timeouts. Add a check in `list-issues` or the pick reasoning to filter `needs-info`-labeled issues.
2. **Plan scope guard**: After plan generation, estimate scope (e.g. number of files, lines changed) and abort or flag if it exceeds a threshold (e.g. >4 files, >200 lines). Write a warning to `plan/plan.md` and exit with a `plan_too_large` error so the issue can be split.
3. **Distinguish do retry causes**: When a do session ends, record whether it timed out (exit 124) vs. completed with no commit. The retry logic could then apply different strategies: on timeout, try a reduced scope; on no-commit, prompt explicitly to commit.
4. **Triage issue #317**: The db consolidation issue is underspecified and has caused one failure. It should be triaged — either closed as `needs-info`, or split into concrete sub-tasks with clear acceptance criteria before being picked again.
