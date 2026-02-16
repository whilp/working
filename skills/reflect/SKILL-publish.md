---
name: reflect-publish
description: Publish reflection.md as a dated note via PR.
---

# Reflect — Publish

You are publishing a reflection document to the repository.

## Environment

- `REPO` — the target `owner/repo`, provided after `---` below.
- `REFLECTION_FILE` — path to reflection.md, provided after `---` below.
- `DATE` — date string (YYYY-MM-DD), provided after `---` below.
- `REPO_DIR` — path to the cloned repo, provided after `---` below.

## Instructions

1. Read REFLECTION_FILE to verify it exists and has content.
2. Create the directory `note/DATE/` in REPO_DIR (e.g. `note/2025-01-15/`).
3. Copy REFLECTION_FILE to `REPO_DIR/note/DATE/reflection.md`.
4. Stage and commit the file with message: `reflect: add DATE reflection`.
5. The push and PR creation are handled by the Makefile. Just commit.

## Output

Write `o/reflect/publish-done` containing the commit SHA.
