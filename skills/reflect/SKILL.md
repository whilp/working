---
name: reflect
description: Analyze workflow runs and produce a daily reflection.
---

# Reflect

You are running one phase of the reflect pipeline. The phase is specified after `---` below as `PHASE=<fetch|analyze|publish>`.

---

## Phase: fetch

Download workflow run logs and artifacts for a date range.

### Environment

- `SINCE` — start date (YYYY-MM-DD).
- `UNTIL` — end date inclusive (YYYY-MM-DD).
- `OUTPUT_DIR` — directory to write fetched data into.

### Instructions

1. Run `get_workflow_runs` with:
   - `repo` set to `whilp/working`
   - `since` set to SINCE
   - `until_` set to UNTIL
   - `output_dir` set to OUTPUT_DIR
2. The tool downloads logs and artifacts for each run into OUTPUT_DIR.
3. Verify the manifest file exists at `OUTPUT_DIR/manifest.json`.
4. Write `OUTPUT_DIR/fetch-done` containing the number of runs fetched.

### Output

- `OUTPUT_DIR/manifest.json` — JSON array of run metadata with log/artifact paths.
- `OUTPUT_DIR/<run-id>/log.txt` — full log for each run.
- `OUTPUT_DIR/<run-id>/artifacts/` — downloaded artifacts for each run.
- `OUTPUT_DIR/fetch-done` — completion marker.

---

## Phase: analyze

Analyze workflow run data and produce a reflection document. You are sandboxed with no network access. All data is already in FETCH_DIR.

### Environment

- `FETCH_DIR` — directory containing fetched run data.
- `OUTPUT_DIR` — directory to write reflection output.

### Instructions

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

### Output

Write `OUTPUT_DIR/reflection.md` in this format:

```markdown
# Reflection: YYYY-MM-DD

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

---

## Phase: publish

Commit reflection.md to the repository as a dated note.

### Environment

- `REFLECTION_FILE` — path to reflection.md.
- `DATE` — date string (YYYY-MM-DD).
- `REPO_DIR` — path to the cloned repo.

### Instructions

1. Read REFLECTION_FILE to verify it exists and has content.
2. Create the directory `note/DATE/` in REPO_DIR (e.g. `note/2025-01-15/`).
3. Copy REFLECTION_FILE to `REPO_DIR/note/DATE/reflection.md`.
4. Stage and commit the file with message: `reflect: add DATE reflection`.
5. The push and PR creation are handled by the Makefile. Just commit.

### Output

Write `o/reflect/publish-done` containing the commit SHA.
