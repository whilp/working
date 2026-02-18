---
name: tests
description: Audit and improve tests for a target repo.
---

# Tests

You are improving tests for a GitHub repository.

## Environment

- The target repo is cloned at `o/repo/`. You have read and write access.

## Instructions

1. Read `o/repo/AGENTS.md` and any documentation it references to learn:
   - How to run the test suite.
   - Where tests live and how they are organized.
   - What conventions exist for testing.

2. Run the full test suite. Record results — total tests, passed, failed, errors.

3. Read through the codebase and existing tests. Understand what is tested and what is not. Look for:
   - Untested code, missing edge cases, gaps in error handling.
   - Tests that run code but don't verify outcomes.
   - Tests that are flaky, slow, or depend on external state.
   - Any other quality issues specific to this repo's test ecosystem.

   Adapt your analysis to whatever testing patterns the repo uses. Do not impose a fixed rubric.

4. Fix the most impactful issues. Prioritize:
   - Failing or broken tests (fix first).
   - Missing tests for important code paths.
   - Weak or missing assertions.

   For each fix:
   a. Follow the repo's conventions.
   b. Run the affected test(s) to verify they pass.
   c. Stage and commit with a descriptive message.

5. Re-run the full test suite. Confirm everything passes.

## Constraints

- Do not modify source files — only test files.
- Follow the repo's existing test conventions.
- Run tests before committing.

## Output

Write `o/tests/tests.json`:

```json
{
  "suite": {"total": 0, "passed": 0, "failed": 0},
  "created": 0,
  "improved": 0,
  "findings": [
    {
      "area": "<module, feature, or test file>",
      "action": "<added|improved|flagged>",
      "notes": "<what was found and what was done>"
    }
  ]
}
```
