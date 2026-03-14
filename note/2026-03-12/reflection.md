# Reflection: 2026-03-12

## Summary

One work workflow run executed on 2026-03-12. Three parallel jobs ran (whilp/ah, whilp/cosmic, whilp/working). cosmic and working skipped (no open issues). ah attempted issue #504 but the do phase timed out twice, leaving the run failed with no PR.

## Runs

| workflow | total | pass | fail | cancel |
|---|---|---|---|---|
| work | 1 | 0 | 1 | 0 |

## Failure Analysis

### Do phase timeout (whilp/ah, issue #504)

The do phase hit the 420s limit on both attempts. The issue — "always write/tee tool outputs to a mkdtemp file" — requires threading `output_dir` through the agent loop: changes to `AgentOpts`, `looptool.execute_tool_calls`, and `truncate_output` call signatures. Substantive progress was made but the refactor was too large to complete within budget.

```
make[1]: *** [work.mk:193: o/do/done] Error 1
  extracting timeout notes from session
make[1]: *** [work.mk:193: o/do/done] Error 1
make: *** [work.mk:264: work] Error 2
Process completed with exit code 2.
```

## Work Loop Outcomes

| repo | issue | verdict | pr |
|---|---|---|---|
| whilp/ah | #504 — "always write/tee tool outputs to a mkdtemp file" | timeout (no verdict) | none |
| whilp/cosmic | — | no_issues | — |
| whilp/working | — | no_issues | — |

## Patterns

- **Recurring timeout on large refactors**: issue #504 is a cross-cutting change requiring updates to multiple core modules. The 420s do budget is insufficient for this class of work. This has likely caused repeated failures on the same issue.
- **Two repos consistently idle**: whilp/cosmic and whilp/working report `no_issues` on most runs. Either their issue backlogs are empty or the pick skill is not surfacing available work.
- **Node.js 20 deprecation warnings**: all three jobs emit warnings from `actions/checkout`, `actions/create-github-app-token`, and `actions/upload-artifact`. These will eventually become errors.

## Recommendations

1. **Split issue #504 into smaller sub-issues**: the `output_dir` threading change is too large for one do session. Break it into: (a) add `output_dir` to `AgentOpts` and plumb it to `looptool`, (b) update `truncate_output` signature, (c) wire per-session file writing end-to-end. Each should be completable in one pass.
2. **Add a do-phase scope check to plan**: before writing a plan, estimate whether the implementation fits within the 420s do budget. Flag plans that touch more than ~3 core files as high-risk and split them proactively.
3. **Investigate idle repos**: check whether whilp/cosmic and whilp/working have open `todo` issues. If not, consider whether the pick label criteria need adjustment or whether new issues should be filed to keep those loops active.
4. **Upgrade GitHub Actions to Node.js 20+ versions**: update `actions/checkout`, `actions/create-github-app-token`, and `actions/upload-artifact` to their latest versions to eliminate deprecation warnings before they become failures.
