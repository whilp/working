# Reflection: 2026-02-16

## Summary

Extremely active day — 66 runs covering massive infrastructure buildout: CI pipeline,
reflect pipeline, auth fixes, triage skill, iterate skill, and GitHub App token migration.
The one successful work run (23:04 UTC, scheduled) accomplished real work across all three
repos. Most work failures were auth-related (HTTP 401/403/128) due to an unresolved GitHub
App token problem that plagued the day. The reflect pipeline was bootstrapped from scratch,
hit repeated auth and timeout failures, and was partially fixed before day end.

## Runs

| workflow | total | pass | fail | cancel |
|---|---|---|---|---|
| test (CI) | 38 | 38 | 0 | 0 |
| work | 8 | 1 | 6 | 1 |
| reflect | 9 | 0 | 8 | 0 |
| **total** | **55** | **39** | **14** | **1** |

> Note: 66 analysis files exist; some overlap due to reflect counting its own runs.

## Failure Analysis

### 1. GitHub API 401 Bad Credentials (most common — work and reflect)

Affected runs: 22073381500, 22073559538, 22078768419, 22080717750, 22080811981 (work);
22078349401, 22078540480, 22078628401, 22078700990, 22078952728 (reflect).

Root cause: `GH_TOKEN` invalid or expired. The GitHub App installation may have had pending
permission changes not accepted by the owner, causing `actions/create-github-app-token` to
produce a token with stale/restricted scopes. All API calls failed uniformly — `ensure_labels`,
`count_open_prs`, `list_issues` all returned HTTP 401.

The scheduled work run at 23:04 UTC succeeded — the same workflow, same code — suggesting
the token problem was transient or tied to manual dispatch timing.

```
HTTP 401: Bad credentials (https://api.github.com/repos/whilp/working/...)
error: no branch in o/pick/issue.json
```

### 2. Reflect publish 403 / push denied

Affected runs: 22078349401, 22078540480, 22078628401, 22078700990, 22078952728.

Root cause: reflect.yml used default `GITHUB_TOKEN` (github-actions[bot]) which lacks write
access to push branches. The work.yml uses `actions/create-github-app-token`; reflect.yml
did not (until PR #38 fix). Multiple auth-fix PRs landed during the day (#23–#30).

```
remote: Permission to whilp/working.git denied to github-actions[bot].
```

### 3. Reflect checkout auth failure

Affected runs: 22078479564, 22078893596.

Root cause: `actions/checkout` failed because no valid token was wired into the checkout
step. The reflect workflow was missing the app token generation step.

```
fatal: could not read Username for 'https://github.com': terminal prompts disabled
The process '/usr/bin/git' failed with exit code 128
```

### 4. Reflect fetch timeout

Affected run: 22079035373.

Root cause: `get_workflow_runs` tool call exceeded the make timeout (~2 min). The agent
started but didn't write `fetch-done` in time. Fix: PR #31 bumped fetch timeout to 300s.

### 5. Work push auth failure + artifact name invalid

Affected run: 22071650965.

The cloned `o/repo` had no git credentials injected, so push failed with exit 128. Also,
artifact name `work-whilp/ah` contains a forward slash which GitHub rejects. Both are infra
bugs; the actual agent work (plan + do) succeeded.

```
fatal: could not read Username for 'https://github.com': No such device or address
The artifact name is not valid: work-whilp/ah. Contains: Forward slash /
```

### 6. Reflect Anthropic API transport error

Affected run: 22078266118.

Root cause: Connection reset during Anthropic API call mid-analysis (`fetch failed: transport
error`). Old monolithic analyze phase read all 43 run logs in one session, likely hitting
context or response size limits. Fixed by splitting into per-run analyze + summarize.

### 7. Pick skill: `gh` exit 4 (access failure)

Affected runs: 22073381500, 22073559538.

`gh` returned exit 4 for `count_open_prs` and `list_issues` against whilp/ah and
whilp/cosmic. `ensure_labels` succeeded, suggesting the token had write access to
whilp/working but not to the target repos at that moment.

## Work Loop Outcomes

| run | repos | outcome |
|---|---|---|
| 22071650965 | whilp/ah | plan+do succeeded (#183), push failed (no git creds) |
| 22072694235 | whilp/ah | cancelled during pick, no issue |
| 22073381500 | whilp/ah, whilp/cosmic | pick failed (gh exit 4) |
| 22073559538 | whilp/ah, whilp/cosmic | pick failed (gh exit 4) |
| 22078768419 | all three | pick failed (401) |
| 22080065658 | all three | **success** — 3 issues completed, 2 PRs created |
| 22080717750 | all three | pick failed (401) |
| 22080811981 | all three | pick failed (401) |

**Successful work run (22080065658, 23:04 UTC):**
- whilp/ah #287: already resolved, agent identified early and closed (no unnecessary work)
- whilp/cosmic #229: fixed `setitimer` parameter order; PR created
- whilp/working #35: triage skill implemented; PR created

## Patterns

- **Auth failures dominate.** 13 of 14 failures involve auth (401/403/128). The one
  exception (Anthropic transport error) was a context overload issue since fixed.
- **Scheduled runs are more reliable than manual dispatch.** The only successful work run
  was a scheduled trigger. All manual dispatch work runs failed (401). Same workflow, same
  code — token generation may behave differently under manual dispatch.
- **CI is rock-solid.** 38 CI runs, 38 passed. Format, type, and test checks consistently
  complete in 10–15 seconds. Tool coverage grew from 7 → 9 → 11 tools during the day.
- **Reflect pipeline was built and broken the same day.** 9 reflect runs, 0 succeeded.
  Multiple PRs shipped to fix auth and timeouts. Should work after PR #38 (app token auth).
- **Pick error messages are inconsistent.** The same gh API failure produces different error
  strings: "no issues", "api failure", "authentication failed", "repository not accessible" —
  depending on agent reasoning. Makes triage harder.
- **Artifact names cannot contain slashes.** `work-whilp/ah` breaks GitHub artifact upload.
  Work artifacts are currently named `work-0`, `work-1`, etc. to avoid this, but the root
  cause (REPO containing a slash) isn't guarded elsewhere.

## Recommendations

1. **Guard work push credentials**: inject `GH_TOKEN` into cloned repo remote URL before
   push (`git remote set-url origin https://x-access-token:$GH_TOKEN@github.com/...`).
   Currently the cloned repo has no credentials and push fails (seen in run 22071650965).

2. **Normalize pick error codes** (#65): define a fixed enum of error values for `o/pick/issue.json`
   (`{"error": "auth_failure"}`, `{"error": "no_issues"}`, `{"error": "api_failure"}`).
   Inconsistent strings ("no issues" vs "api failure" vs "authentication failed") confuse
   downstream diagnosis and make error patterns harder to detect.

3. **Add scheduled reflect workflow test**: the reflect workflow was run 9 times manually
   with 0 successes. Add a check that the reflect.yml uses `actions/create-github-app-token`
   the same way work.yml does. Consider a dry-run CI test that validates workflow YAML structure.

4. **Investigate manual dispatch token generation**: scheduled work runs succeed while manual
   dispatches fail (401). Determine whether `actions/create-github-app-token` behaves
   differently under `workflow_dispatch` vs `schedule`. Add a debug step logging token
   expiry and scopes.

5. **gh exit code handling in pick** (#66): distinguish gh exit 4 (resource not found / no access)
   from other errors. Currently exit 4 surfaces as "no issues" in some codepaths, masking
   real permission errors.

6. **Sanitize artifact names** (#67): replace `/` with `-` in artifact names derived from REPO
   (e.g. `work-whilp-ah` instead of `work-whilp/ah`). Add a guard or note in work.yml.
