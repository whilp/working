# Reflection: 2026-02-26

## Summary

Four scheduled work runs executed across the day. All three repos (whilp/ah, whilp/cosmic, whilp/working) ran in parallel each time. Work was completed successfully on multiple issues (ah#258 twice, cosmic#290, cosmic#312), but **every single act phase failed** due to a recurring temp file bug in the gh CLI wrapper — no PRs were created and no issue comments were posted all day. Two additional failures occurred: a cosmic do-phase timeout (issue#299) and an ah pick timeout.

## Runs

| workflow | total | pass | fail | cancel |
|---|---|---|---|---|
| work | 4 | 2 | 2 | 0 |

Note: the 2 "success" conclusions are misleading — both had act failures that did not propagate to workflow conclusion.

## Failure Analysis

### 1. Act temp file errors (all 4 runs, all repos with work to do)

Every act phase failed with the same error:

```
comment_issue failed: gh failed (exit 1): open /tmp/lua_XXXXXX: no such file or directory
create_pr failed: gh failed (exit 1): open /tmp/lua_XXXXXX: no such file or directory
```

The gh CLI wrapper uses `os.tmpname()` to create a temp file for request bodies, then passes the path to `gh`. By the time `gh` opens it, the file is gone (or was never created). This is likely a Lua `os.tmpname()` race — the function returns a name without creating the file, and something cleans `/tmp` between name generation and `gh` open. This blocked all PR creation and issue commenting for the entire day. The act.json correctly records `actions_failed: 2`, but the label is set to `failed` even when the underlying work passed check — causing good work to be silently discarded.

**Affected issues**: ah#258 (×3 runs), cosmic#312 (×1), cosmic#290 (×1).

### 2. cosmic#299 do-phase timeout (run 22431974464)

The `--check-style` feature addition hit the 300s do-phase limit twice. The build itself took ~3.5 min (CI failing on checkout branch), leaving little time for the agent session. This issue has been attempted multiple times and consistently times out.

### 3. ah pick timeout (run 22455022887)

Pick was killed after 120s (exit 124) with many issues to analyze. The agent had listed issues but had not written `o/pick/issue.json` before the deadline. This is a repeat pattern.

## Work Loop Outcomes

| repo | issue | title | verdict | PR |
|---|---|---|---|---|
| whilp/ah | #258 | fix inconsistent tool call display | pass | not created (act failed) |
| whilp/cosmic | #312 | add --write-if-changed flag | pass | not created (act failed) |
| whilp/cosmic | #290 | generalize doc depth | pass | not created (act failed) |
| whilp/ah | #258 | fix inconsistent tool call display | pass | not created (act failed) |
| whilp/cosmic | #299 | add --check-style | (do timeout) | — |
| whilp/working | — | — | no_issues | — |

0 PRs created. 0 comments posted. All passing work was silently lost.

## Patterns

- **Act failures are 100% blocking**: every run that produced passing work failed to act on it. The bug is deterministic and persistent — not flaky.
- **whilp/working has no issues**: all four runs returned `no_issues`. The working issue backlog is either empty or all items are labeled non-todo.
- **cosmic#299 is consistently too large**: every attempt times out during do. The issue needs to be split into smaller tasks.
- **ah pick is slow with many issues**: the 120s limit is insufficient when there are many collaborator-filed issues without `todo` labels requiring analysis.
- **Act failures set label to `failed`**: even when work passes check, the label ends up `failed` due to act errors — the label doesn't reflect the true verdict.
- **Run timing**: typical full cycle (pick→clone→build→plan→do→check) takes ~20 min per repo.

## Recommendations

1. **Fix act temp file bug** — replace `os.tmpname()` in the gh CLI wrapper with `os.tmpfile()` or use `io.popen("mktemp")` to atomically create the temp file before passing its path to `gh`. This is the single highest-impact fix: it blocked all PR creation for the entire day. (`tools/` or `lib/work/`)

2. **Don't overwrite label to `failed` when act errors** — when check verdict is `pass` but act fails, preserve the `doing` or `done` label (or add a new `act-failed` label) so the issue isn't re-picked in a broken state. Currently passing work is being silently discarded and the issue is relabeled as if the work itself failed.

3. **Split cosmic#299 (add --check-style)** — the task consistently exceeds the 300s do-phase budget. Split into: (a) add `check_style` lint rule to `lint.tl`, (b) wire `--check-style` flag to CLI, (c) add tests. File a separate issue for each.

4. **Increase or relax pick timeout for ah** — the 120s pick budget is insufficient when many collaborator-filed issues (without `todo` labels) need analysis. Either increase the pick timeout, or pre-filter issues to only those with `todo` labels and let triage handle labeling.

5. **Add issues to whilp/working backlog** — the repo has had `no_issues` for all four runs today. Either file new issues or ensure triage runs to label existing ones as `todo`.
