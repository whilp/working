# Reflection: 2026-03-17

## Summary

Two scheduled work runs executed on 2026-03-17. One run produced a successful PR for `whilp/ah`; the other found nothing to do. `whilp/working` was blocked all day by an excess of open PRs (5 vs 4 limit). `whilp/cosmic` had no todo issues in both runs.

## Runs

| workflow | total | pass | fail | cancel |
|---|---|---|---|---|
| work | 2 | 2 | 0 | 0 |

## Failure Analysis

No failures. Both runs concluded `success`.

One transient flake noted in run 23177424910: `test_timeout.tl` failed once during the `do` phase due to a make parallel jobserver race condition; a re-run passed cleanly. Not a systemic issue.

## Work Loop Outcomes

- **Run 23177424910** (03:45 UTC):
  - `whilp/ah` picked issue #538 "Add a lua tool" → verdict **pass** → PR created: `work/538-a3f7c219` ("tools: add lua tool with sandboxed execution environment")
  - `whilp/cosmic` → no open issues, skipped
  - `whilp/working` → pr_limit (5 open PRs), skipped
  - Duration: ~13 minutes

- **Run 23184571312** (08:10 UTC):
  - `whilp/ah` → no_issues (2 open PRs, none with feedback)
  - `whilp/cosmic` → no_issues (2 open PRs, none with feedback)
  - `whilp/working` → pr_limit (5 open PRs), skipped
  - Duration: ~30s per repo (all exited at pick)

## Patterns

- `whilp/working` PR queue is persistently above the 4-PR cap, blocking all work. Has been at 5 open PRs across both runs today. Needs manual triage to merge or close stale PRs.
- `whilp/ah` ran out of todo issues after the morning run — queue saturation is a recurring pattern.
- Node.js 20 deprecation warnings are present in every run across `actions/checkout`, `actions/create-github-app-token`, and `actions/upload-artifact`. These will become errors on June 2, 2026.
- The lua sandbox implementation (issue #538) noted a `getmetatable`/`setmetatable` escape path (`string.dump` via `getmetatable("").__index.dump`) deferred as non-critical; worth a follow-up issue.

## Recommendations

1. **Raise or dynamically tune the PR limit for `whilp/working`**: The hard 4-PR cap is blocking all automated work. Either raise it to 6, or add logic to skip repos only when open PRs are stale (e.g., no activity in N days), rather than on raw count.
2. **Track Node.js 20 → 24 action upgrade deadline**: Create an issue to update `actions/checkout`, `actions/create-github-app-token`, and `actions/upload-artifact` to Node.js 24-compatible versions before June 2, 2026.
3. **Follow up on lua sandbox escape path**: Create an issue to close the `getmetatable("").__index.dump` escape in `sys/tools/lua.tl` (blocks bytecode extraction even without OS/IO access).
4. **Address make parallel jobserver race in tests**: The `test_timeout.tl` flake from a jobserver race is a recurring risk under parallel CI. Investigate and fix the root cause rather than relying on re-runs.
