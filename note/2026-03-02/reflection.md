# Reflection: 2026-03-02

## Summary

Seven work runs executed across three repos (whilp/ah, whilp/cosmic, whilp/working). whilp/ah drove all meaningful work — five issues resolved, four PRs created. whilp/cosmic was blocked by pr_limit in most runs (5 open PRs > threshold of 4); it contributed one PR early in the day. whilp/working had no open issues all day. Two runs failed due to do-phase timeouts on complex/blocked issues.

## Runs

| workflow | total | pass | fail | cancel |
|---|---|---|---|---|
| work | 7 | 5 | 2 | 0 |

## Failure Analysis

### do-phase timeout (×2 runs)

Both failures share the same root cause: the `do` phase exceeded the 300s wall-clock limit twice in a row, exhausting all retries.

**Run 22565515317** — whilp/ah issue #308 "add interactive REPL mode"
- Complex feature; plan flagged a blocking cosmic dependency (`cosmo.repl.readline` not available)
- Plan proceeded to `do` despite its own bail warning; both attempts timed out
- Session DBs minimal size — sessions terminated very early

**Run 22589199226** — whilp/ah issue #228 "native --timeout via SIGALRM"
- Issue explicitly blocked on whilp/cosmic#229 (setitimer not firing in runtime)
- Both do-phase sessions ran 5 minutes and produced near-empty session DBs (4KB each)
- Ironic: the timeout implementation was itself killed by timeout

**Pattern**: both failed issues were flagged as blocked on external dependencies, yet were still picked and attempted. The plan skill's bail logic is not preventing `do` from running on clearly-blocked issues.

## Work Loop Outcomes

| run | repo | item | verdict | PR |
|---|---|---|---|---|
| 22563803351 | whilp/ah | #369 pptx image downsampling | pass | created |
| 22563803351 | whilp/cosmic | #142 rand64/lemur64/rdrand/rdseed | pass | created |
| 22565515317 | whilp/cosmic | #266 ;; in TL_PATH | pass | created |
| 22565515317 | whilp/ah | #308 interactive REPL | timeout | none |
| 22571305903 | whilp/ah | #449 mkdtemp for temp files | pass | created |
| 22573368731 | whilp/ah | #432 refactor diff/read tools | pass | created |
| 22589199226 | whilp/ah | #228 native --timeout via SIGALRM | timeout | none |
| 22593511489 | whilp/ah | PR #474 CI fix (write/edit protect dirs) | pass | updated |
| 22595711602 | whilp/ah | #447 replace io.popen with child.spawn | pass | created |

**whilp/ah**: 7 items attempted, 5 pass, 2 timeout failures  
**whilp/cosmic**: 3 items attempted, 2 pass, 1 skipped (pr_limit)  
**whilp/working**: 7 runs, all no_issues

## Patterns

**whilp/cosmic pr_limit is a persistent blocker.** All seven runs showed cosmic at or above 5 open PRs (threshold 4). After the first two runs where cosmic worked, it was blocked for the remaining five. Unmerged PRs are preventing new work from starting.

**whilp/working has no open issues.** Zero work happened in this repo all day. Triage may be needed to generate new issues, or the issue queue is genuinely empty.

**do-phase retries work when the issue is tractable.** Runs 22573368731 and 22593511489 both had do-phase retries that succeeded on the second attempt. The retry mechanism is functioning.

**Timing is consistent.** Successful ah runs: pick ~30-60s, build ~2m, plan ~1-5m, do ~3-4m, check ~1-2m. Total ~10-14m per run. No duration outliers on successful runs.

**Self-correction in do phase** (run 22573368731): agent caught a formatter error mid-do and corrected it before committing — healthy behavior.

## Recommendations

1. **Bail on blocked issues before do.** The plan skill's bail logic should hard-stop the pipeline when a plan concludes "blocked on external dependency." Issues #308 and #228 both had explicit blocking notes in the plan; the do phase ran anyway. Add a check: if `plan.md` contains a bail section, skip `do` and label the issue `blocked`.

2. **Track and skip previously-timed-out issues.** Both timeout failures were on issues with prior `failed` labels. The pick skill should deprioritize (or skip) issues that have been timed out multiple times — especially if the plan flags external blockers.

3. **Alert when whilp/cosmic pr_limit persists across N runs.** Five consecutive pr_limit skips with no intervention suggests the PRs aren't being reviewed/merged. Add a notification or auto-issue when cosmic is blocked for more than 3 consecutive runs.

4. **Triage whilp/working.** The repo had zero open issues for the entire day. Run the triage skill to generate new actionable issues or close stale ones, so the work loop has something to do.

5. **Consider raising or making pr_limit configurable per repo.** A hard limit of 4 open PRs may be too tight for cosmic, which has active parallel work streams. Evaluate whether bumping to 6 would be more appropriate while the backlog clears.
