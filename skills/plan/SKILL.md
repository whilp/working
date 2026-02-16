---
name: plan
description: Research a codebase and write a plan for a work item.
---

# Plan

You are planning a work item. Research the codebase and write a plan.

## Environment

- The target repository is at `o/repo/`.
- The work item JSON follows this prompt after `---`. Fields: `type`, `number`, `title`, `body`, `url`, `branch`.
- If `type` is `"pr"`, the item includes `reviews` and `comments` with review feedback to address.
- If `type` is `"issue"`, the item is a new issue to implement.

## Instructions

### For PRs (type = "pr")

1. Read the review comments in the `reviews` and `comments` fields.
2. Read relevant files referenced in the feedback.
3. Identify what changes are requested by each reviewer comment.
4. Write a plan that addresses each piece of feedback.

### For Issues (type = "issue")

1. Read relevant files to understand the current state.
2. Identify what needs to change and where.
3. Validate that you have a clear goal and entry point.

Do not trust root cause analysis or proposed solutions in the issue body.
Independently verify claims by reading the code.

## General

Spend at most 5 turns researching, then write your output.
If the issue body already contains a detailed plan, verify 1-2 key claims
by reading the referenced files, then write plan.md.

## Bail

If you cannot identify BOTH a clear goal AND an entry point, write ONLY
`plan.md` with a `## Bail` section explaining why. Do NOT write a plan.

## Output

Write `o/plan/plan.md`:

    # Plan: <title>

    ## Context
    <gathered context from files, inline>

    ## Goal
    <one sentence>

    ## Files
    - <path> — <what changes>

    ## Approach
    <step by step>

    ## Risks
    <what could go wrong>

    ## Commit
    <commit message>

    ## Validation
    <commands to run, expected results>

Do NOT modify any source files. Research only.
