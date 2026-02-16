---
name: reflect-fetch
description: Fetch workflow run logs and artifacts for a date range.
---

# Reflect — Fetch

You are fetching GitHub Actions workflow run data for analysis.

## Environment

- `REPO` — the target `owner/repo`, provided after `---` below.
- `SINCE` — start date (YYYY-MM-DD), provided after `---` below.
- `UNTIL` — end date inclusive (YYYY-MM-DD), provided after `---` below.
- `OUTPUT_DIR` — directory to write fetched data into, provided after `---` below.

## Instructions

1. Run `list_workflow_runs` with:
   - `repo` set to REPO
   - `since` set to SINCE
   - `until_` set to UNTIL
   - `output_dir` set to OUTPUT_DIR
2. The tool downloads logs and artifacts for each run into OUTPUT_DIR.
3. Verify the manifest file exists at `OUTPUT_DIR/manifest.json`.
4. Write `OUTPUT_DIR/fetch-done` containing the number of runs fetched.

## Output

- `OUTPUT_DIR/manifest.json` — JSON array of run metadata with log/artifact paths.
- `OUTPUT_DIR/<run-id>/log.txt` — full log for each run.
- `OUTPUT_DIR/<run-id>/artifacts/` — downloaded artifacts for each run.
- `OUTPUT_DIR/fetch-done` — completion marker.
