---
name: cosmic
description: Run CI checks, fix type errors, format issues, and test failures using the cosmic teal/lua runtime.
---

# Cosmic

You are running CI validation and fixing issues in a codebase that uses cosmic, a teal/lua runtime.

## Environment

- The target repository is at `o/repo/`.
- The cosmic binary is at `o/bin/cosmic`.
- Build dependencies are pre-fetched under `o/repo/o/`.
- You have tools: `bash`.

## Instructions

1. Run the full CI pipeline:

   ```bash
   cd o/repo && make ci
   ```

   This runs four checks:
   - `make check-types` — teal type checking on all non-test `.tl` files.
   - `make check-format` — formatting check on all non-test `.tl` files.
   - `make check-length` — file length lint (500-line default limit).
   - `make test` — runs all `test_*.tl` files.

2. If any checks fail, read the output to identify failures.

3. For each failure type:
   - **type errors**: read the failing `.tl` file, fix the type annotation or usage.
   - **format errors**: run `o/bin/cosmic --format <file.tl>` to see the expected format, then apply changes.
   - **length errors**: refactor the file to reduce line count below its limit.
   - **test failures**: read the test file and the source it exercises, fix the issue.

4. After fixes, stage changed files and commit with a descriptive message.

5. Re-run `make ci` to confirm all checks pass.

## Cosmic CLI

| command | description |
|---|---|
| `cosmic <script.tl> [args]` | run a teal script |
| `cosmic --check-types <file.tl>` | type check a teal file |
| `cosmic --format <file.tl>` | print formatted source to stdout |
| `cosmic --test <output> <cmd> [args]` | run a command, write pass/fail to output |
| `cosmic --report <results...>` | summarize pass/fail results |

## Constraints

- Do not skip failing checks. All four CI checks must pass.
- Do not modify test behavior to make tests pass — fix the source.
- Follow repo conventions in `AGENTS.md` and `docs/conventions.md`.

## Output

Write `o/cosmic/cosmic.json`:

```json
{
  "types": "pass|fail",
  "format": "pass|fail",
  "length": "pass|fail",
  "tests": "pass|fail",
  "fixed": ["<file>: <what was fixed>"]
}
```
