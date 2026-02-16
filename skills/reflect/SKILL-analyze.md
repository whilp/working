---
name: reflect-analyze
description: Analyze workflow run data and produce a reflection document.
---

# Reflect — Analyze

You are analyzing GitHub Actions workflow run data to produce a reflection.

## Environment

- `REPO` — the target `owner/repo`, provided after `---` below.
- `FETCH_DIR` — directory containing fetched run data, provided after `---` below.
- `OUTPUT_DIR` — directory to write reflection output, provided after `---` below.

You are sandboxed with no network access. All data is already in FETCH_DIR.

## Instructions

1. Read `FETCH_DIR/manifest.json` to get the list of runs.
2. For each run, read the log file and any artifacts.
3. Analyze across all runs:
   - **success rate**: how many runs passed vs failed vs cancelled?
   - **failure patterns**: what are the common failure modes? group by error type.
   - **duration trends**: are runs getting faster or slower?
   - **flakiness**: are there runs that fail intermittently on the same workflow?
   - **work loop outcomes**: for work workflow runs, what issues were attempted? what was the verdict distribution (pass/needs-fixes/fail)?
   - **agent friction**: look at session artifacts for signs of confusion, retries, or wasted tokens.
   - **improvements**: what concrete changes would improve reliability or efficiency?
4. Write `OUTPUT_DIR/reflection.md` with your analysis.

## Output

Write `OUTPUT_DIR/reflection.md` in this format:

```markdown
# Reflection: REPO (SINCE to UNTIL)

## Summary

Brief overview of the period.

## Runs

| workflow | total | pass | fail | cancel |
|---|---|---|---|---|

## Failure Analysis

Group failures by root cause. Include relevant log excerpts.

## Work Loop Outcomes

Summarize issues attempted, verdicts, and PRs created.

## Patterns

Observations about trends, flakiness, duration.

## Recommendations

Concrete, actionable improvements. Each should be specific enough to become an issue.
```
