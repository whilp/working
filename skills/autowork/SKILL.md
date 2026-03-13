---
name: autowork
description: Propose a small, focused improvement to ah based on eval results and discard history.
---

# Autowork: Propose

You are proposing a single improvement to ah. Your goal is to make a small,
focused change that improves ah's eval score.

## Environment

- The ah repository is at `o/repo/`.
- Recent eval results are in `o/autowork/eval/summary.json` (if available).
- The results log is in `o/autowork/results.tsv` (if available).
- The discard log lists previously tried and rejected changes.

## Mutable zones

You may ONLY modify files in these zones:

| zone | files | rationale |
|------|-------|-----------|
| system prompt | `sys/system.md` | prompt engineering affects agent behavior |
| tool implementations | `sys/tools/*.tl` | tool behavior shapes task completion |
| tool guidance | tool `system_prompt` fields | how the agent uses tools |
| core loop | `lib/ah/loop.tl` | loop detection, compaction thresholds |
| compaction | `lib/ah/compact.tl` | context management |
| truncation | `lib/ah/truncate.tl` | tool output visibility |
| API params | `lib/ah/api.tl` | temperature, caching strategy |

Do NOT modify anything in `eval/` — that is the immutable measurement contract.

## Instructions

1. Read `o/repo/AGENTS.md` if it exists for repo context.
2. Read the eval summary to understand current performance:
   - Which capabilities score lowest?
   - Which tasks fail most often?
   - What are common failure patterns?
3. Read the results log and discard history to avoid repeating failed experiments.
4. Identify ONE focused improvement. Good candidates:
   - Reduce verbosity in system prompt (saves tokens)
   - Improve tool error messages (helps recovery)
   - Tune compaction thresholds (keeps relevant context)
   - Fix truncation patterns (shows important output)
   - Simplify loop detection (fewer false positives)
5. Make the change in `o/repo/`. Keep it small:
   - ONE conceptual change
   - Prefer deletions and simplifications over additions
   - Max 50 lines changed (net)
6. Run `cd o/repo && make ci` to validate. If it fails, fix or abandon.
7. Commit with a clear message explaining what and why.

## Constraints

- ONE change per proposal. Do not bundle multiple improvements.
- Prefer simplification. Deleting 5 lines is cheaper to keep than adding 50.
- Do not add new dependencies.
- Do not modify test infrastructure or eval tasks.
- Do not add comments, docstrings, or type annotations to unchanged code.

## Output

Write `o/autowork/propose/proposal.md`:

```markdown
# Proposal

## Change
<one-sentence description of what changed>

## Rationale
<why this should improve eval score, based on data>

## Risk
<what could go wrong>

## Files
<list of files modified>

## Diff size
<lines added / removed / net>
```
