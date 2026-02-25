# Reflection: 2026-02-24

## Summary

Four work runs executed across three repos (whilp/ah, whilp/cosmic, whilp/working). Two systemic failure modes dominated the day: (1) the `do`/`plan` phase timing out in whilp/cosmic due to build slowness consuming the budget, and (2) the act phase failing in whilp/ah due to missing `/tmp/lua_*` temp files. Despite these failures, whilp/ah produced a clean pass verdict on issue #258 in multiple runs — though the PR was never successfully published due to act failures. whilp/working found no issues in all four runs.

## Runs

| workflow | total | pass | fail | cancel |
|---|---|---|---|---|
| work | 4 | 1 | 3 | 0 |

- run 22330417546 (00:05 UTC): success (all jobs completed; act failed silently)
- run 22339111520 (06:16 UTC): failure (cosmic do ×2 timeout; ah act temp file error)
- run 22364040351 (18:15 UTC): failure (cosmic plan timeout)
- run 22370121654 (21:08 UTC): failure (cosmic do ×2 timeout; ah act temp file error)

## Failure Analysis

### 1. cosmic build time exhausts phase budget (3 runs)

cosmic's `make ci` takes ~4 minutes. With a 300s phase limit, this leaves no time for implementation in the `do` phase, or barely enough for research in `plan`. Result: timeout exits (code 124) on both retry attempts.

- run 22339111520: do phase timed out ×2 (issue #299 add --check-style)
- run 22364040351: plan phase timed out after 300s (issue #193 crypto.encrypt/decrypt)
- run 22370121654: do phase timed out ×2 (issue #312 add --write-if-changed)

Representative log line:
```
make[1]: *** [work.mk:176: o/do/done] Error 124
```

The worst case is self-referential: issue #312 (--write-if-changed, intended to speed up cosmic CI) cannot be implemented because cosmic CI is too slow.

### 2. act phase /tmp temp file missing (2 runs)

The act tool uses `gh` CLI with temp files under `/tmp/lua_*` for body content. Those files disappear between the check phase and the act phase (likely ephemeral-storage cleanup or sandbox reset between steps).

- run 22339111520: ah issue #186 — both `comment_issue` and `create_pr` failed
- run 22370121654: ah issue #258 — both `comment_issue` and `create_pr` failed

Representative log lines:
```
comment_issue failed: gh failed (exit 1): open /tmp/lua_ithmes: no such file or directory
create_pr failed: gh failed (exit 1): open /tmp/lua_msnfwe: no such file or directory
```

Act failures are silently labeled `failed` on the issue — the work is done and verified but never published.

### 3. cosmic needs-fixes: missing help.md update (run 22330417546)

The do phase for cosmic #312 (first run) added `--write-if-changed` to `longopts` in `args.tl` but skipped updating `sys/help.md`. Both `args_test.tl` and `help_test.tl` failed. A one-line fix would have made it pass.

## Work Loop Outcomes

| repo | issue | attempts | verdict | PR |
|---|---|---|---|---|
| whilp/ah | #258 multi-line bash display | 3 | pass (×3) | not published (act failures) |
| whilp/ah | #186 walk ancestor dirs | 1 | pass | not published (act failure) |
| whilp/cosmic | #312 --write-if-changed | 2 | needs-fixes / do-timeout | none |
| whilp/cosmic | #299 --check-style | 1 | do-timeout | none |
| whilp/cosmic | #193 crypto.encrypt/decrypt | 1 | plan-timeout | none |
| whilp/working | — | 4 | no_issues | — |

whilp/ah issue #258 received a clean pass verdict three times — once in each run that attempted it — but the PR was never created because the act phase failed every time.

## Patterns

- **whilp/working always skips**: no `todo`-labeled issues in the repo across all 4 runs. The pick phase exits in ~14s each time with `no_issues`.
- **cosmic CI build (~4min) exceeds phase budget (300s)**: this is a structural conflict. Any complex cosmic issue will timeout unless the build is fixed first.
- **ah issue #258 re-picked multiple times**: the same issue was picked in runs 22330417546 and 22364040351 (and possibly 22370121654). Since act fails and the label isn't updated, the issue remains in `todo` state and gets picked again.
- **Act temp file error is recurring**: appeared in at least 2 separate runs (22339111520, 22370121654). Not a one-off.
- **do phase double-timeout**: cosmic do phase ran twice (two retry sessions) in multiple runs — confirmed by two session DBs in artifacts.

## Recommendations

1. **Fix act phase /tmp temp file lifecycle** — the gh CLI body content files vanish between phases. The act tool should write body content to a stable path (e.g., within the job's working directory) rather than relying on `/tmp/lua_*` ephemeral files. Track as a bug in the act tool.

2. **Increase plan/do phase timeout for cosmic** — or detect slow-building repos and skip complex issues. The current 300s limit is insufficient when the build itself takes ~240s. Either raise the limit for known-slow repos or add a heuristic: if build time > N seconds, skip `do` for complex (p1/large) issues.

3. **Deduplicate issue picks across failed act runs** — when act fails and the label remains `todo`, the same issue gets re-picked every run. Add logic to detect re-picks (e.g., check for existing work branches) or force label transition even on partial act success.

4. **Prioritize cosmic issue #312 (--write-if-changed)** — this issue directly fixes the CI speed problem that causes all other cosmic timeouts. Consider implementing it manually or giving it a longer do budget, since it's a prerequisite for all other cosmic work.

5. **Add cosmic build health check to pick** — if the cosmic build is broken or takes >180s, deprioritize or skip complex feature issues. Only attempt simple/bounded fixes when build time is high.
