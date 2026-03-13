# autowork: autonomous improvement loop for ah

design for an automated loop that continuously improves ah by measuring
its performance, making changes, and keeping only improvements.

## problem

ah is an agent harness. its value is measured by how well agents using it
complete tasks. today, improvements come from humans filing issues and the
work loop executing them. there is no systematic way to:

1. measure ah's task-completion quality
2. automatically propose and test improvements
3. keep winners and discard losers
4. compound gains over time

we want an outer loop that treats ah itself as the thing being optimized,
analogous to how autoresearch treats `train.py` as the thing being optimized.

## prior art

### autoresearch (karpathy/autoresearch)

autonomous neural network optimization. core design:

- **single mutable file** (`train.py`) — agent edits only this
- **fixed contract** (`prepare.py`) — immutable evaluation harness
- **single metric** (val_bpb) — unambiguous win/lose signal
- **fixed time budget** (5 min) — experiments are directly comparable
- **keep/discard ratchet** — branch only advances on improvement
- **human meta-optimization** — humans refine `program.md` to guide agent

results: ~100 experiments overnight, ~15 kept, ~2% improvement in val_bpb.
the system exhibits natural diminishing returns.

key insight: if you can evaluate an improvement in N minutes with a clear
metric, you can build an autonomous researcher.

### working (whilp/working)

the existing work loop already automates the PDCA cycle for github issues:

```
pick → clone → build → plan → do → push → check → act
```

it runs hourly, handles retries (3 loops), and has a reflect phase for
retrospective analysis. but it optimizes *for completing issues*, not
*for improving ah's ability to complete issues*.

## what to measure

the central question: what metric captures "ah got better"?

### candidates

| metric | signal strength | cost to measure | notes |
|--------|----------------|-----------------|-------|
| test pass rate | weak | cheap | tests only cover what's written; 100% is trivial to game |
| test coverage % | weak | cheap | coverage ≠ quality; easy to game with meaningless tests |
| `make ci` pass/fail | binary | cheap | necessary but insufficient; a gate, not a gradient |
| SWE-bench score | strong | expensive | gold standard for agent coding ability; measures real tasks |
| internal task completion | medium | medium | run ah on its own issues; circular but useful |
| token efficiency | medium | cheap | tokens per successful task; measures but doesn't drive quality |
| turn count | medium | cheap | fewer turns = more efficient; but not if it gives up early |
| judge score | strong | medium | LLM judges output quality; flexible but noisy |
| time to completion | medium | cheap | wall clock per task; conflated with task difficulty |

### recommended: composite eval score

no single metric suffices. use a composite:

```
score = task_success × quality_factor / cost_factor

where:
  task_success  ∈ {0, 1}         — did the task complete correctly?
  quality_factor ∈ [0.0, 1.0]    — judge assessment of output quality
  cost_factor   = tokens / budget — normalized resource consumption
```

this rewards completing tasks correctly, with high quality, using fewer
resources. a perfect score means: task done, judge approves, minimal tokens.

## eval design

### eval set

a fixed set of tasks that ah should be able to complete. each task is:

```
task/
  prompt.md       — the task description (what to do)
  repo/           — starting repo state (git bundle or snapshot)
  expect.md       — expected outcomes for judging
  config.toml     — time budget, token budget, allowed tools
```

tasks should cover ah's key capabilities:

1. **file editing** — edit a file to fix a bug or add a feature
2. **multi-file changes** — coordinated changes across files
3. **test writing** — write tests for existing code
4. **debugging** — diagnose and fix a failing test
5. **refactoring** — restructure code while preserving behavior
6. **tool use** — effective use of read/write/edit/bash

start with 10-20 tasks. grow the set over time. tasks should be:

- **deterministic to set up** — no network, no external deps
- **fast to run** — each task completes in < 5 minutes
- **objectively judgeable** — clear pass/fail criteria + quality rubric
- **representative** — cover the space of real ah usage

### eval harness

the eval harness is the immutable contract (like `prepare.py`). it:

1. sets up a clean environment for each task
2. runs ah with the task prompt against the repo snapshot
3. captures: exit code, session.db, changed files, token usage, time
4. runs the judge to score quality
5. aggregates scores into a single composite number

```sh
# pseudocode
for task in eval_set:
    setup_clean_env(task)
    run_ah(task.prompt, task.repo, task.config)
    result = judge(task.expect, actual_output)
    scores.append(result)
composite = aggregate(scores)
```

the harness must be **fast**. if the full eval takes 30 minutes, we get
~48 experiments/day. if 5 minutes, ~288/day. speed determines how many
ideas we can test.

### judge

an LLM judge (separate ah invocation or direct API call) that:

1. reads the task description and expected outcomes
2. reads the actual changes (diff) and session log
3. scores on a rubric: correctness, completeness, code quality, efficiency
4. returns a structured score

the judge prompt and rubric are part of the immutable contract. changing
the judge changes what "better" means, so it requires human review.

### baseline

before the loop starts, run the full eval suite against the current ah.
this is the baseline score. all future experiments are compared to it.

store baselines in a results log:

```tsv
commit	score	tokens	time_s	status	description
a1b2c3d	0.72	45000	180	baseline	current ah main
```

## loop design

### the autoresearch pattern, adapted

```
┌──────────────────────────────────────────────────────────┐
│                    AUTOWORK LOOP                         │
│                                                          │
│  ┌─────────┐    ┌──────────┐    ┌───────┐    ┌───────┐  │
│  │ propose │───▶│ apply    │───▶│ eval  │───▶│decide │  │
│  │ change  │    │ to ah    │    │ suite │    │keep/  │  │
│  └─────────┘    └──────────┘    └───────┘    │discard│  │
│       ▲                                      └───┬───┘  │
│       │                                          │      │
│       └──────────────────────────────────────────┘      │
│                                                          │
│  immutable: eval set, harness, judge                     │
│  mutable: ah source (lib/ah/, sys/tools/, sys/system.md) │
└──────────────────────────────────────────────────────────┘
```

### phases

**1. propose**

an agent (running on ah itself, or a separate instance) proposes a change
to ah. it has access to:

- ah source code
- recent eval results (what scored well/poorly)
- the discard log (what was tried and failed)
- a skill prompt guiding what kinds of changes to explore

the proposal is a description + a branch with commits.

**2. apply**

the proposed changes are applied to a fresh ah checkout. `make ci` must
pass — if it doesn't, the proposal is discarded immediately (no eval
needed).

**3. eval**

run the full eval suite with the modified ah. capture the composite score.

**4. decide**

compare to current best score:

```
if new_score > best_score:
    keep (advance branch, update baseline)
elif new_score == best_score and diff_is_simpler:
    keep (prefer simplicity at equal performance)
else:
    discard (revert to previous best)
```

log the result regardless:

```tsv
b2c3d4e	0.74	42000	175	keep	reduce tool prompt verbosity
c3d4e5f	0.71	48000	190	discard	add retry logic to edit tool
```

### what the agent can change

unlike autoresearch's single-file constraint, ah has meaningful
boundaries between components. define **mutable zones**:

| zone | files | rationale |
|------|-------|-----------|
| system prompt | `sys/system.md` | prompt engineering directly affects agent behavior |
| tool implementations | `sys/tools/*.tl` | tool behavior shapes task completion |
| tool guidance | tool `system_prompt` fields | how the agent uses tools |
| core loop | `lib/ah/loop.tl` | loop detection, compaction thresholds |
| compaction | `lib/ah/compact.tl` | how context is managed |
| truncation | `lib/ah/truncate.tl` | what the agent sees from tool output |
| API params | `lib/ah/api.tl` | temperature, caching strategy |

**immutable zones** (changing these would invalidate the eval):

| zone | files | rationale |
|------|-------|-----------|
| eval harness | `eval/` | the measurement contract |
| judge prompt | `eval/judge.md` | the definition of "better" |
| task set | `eval/tasks/` | the benchmark |
| session schema | `lib/ah/db.tl` | observation infrastructure |

### scope control

the agent should make **small, focused changes**. autoresearch enforces
this naturally because there's one file. for ah, enforce it via:

1. **one-change-per-experiment rule**: each proposal should be a single
   conceptual change (one commit, or a small coherent set).
2. **diff size gate**: reject proposals with large diffs (> N lines
   changed). start with N=50.
3. **simplicity criterion** (from autoresearch): a small improvement that
   adds ugly complexity is not worth it. a simplification at equal
   performance is always worth it.

## observability

### session database as telemetry

ah already records everything in session.db:

- every API call (tokens, latency, model)
- every tool call (input, output, duration)
- loop detection events
- compaction events
- stop reasons

the eval harness extracts metrics from session.db after each run. this
is zero-cost instrumentation — it's already there.

### metrics to extract per task

```
tokens_in           — total input tokens
tokens_out          — total output tokens
api_calls           — number of API round-trips
tool_calls          — number of tool invocations
tool_errors         — number of tool calls returning errors
compactions         — number of compaction events
loop_warnings       — number of loop detection warnings
wall_time_s         — total wall clock time
```

### aggregate metrics across eval suite

```
pass_rate           — fraction of tasks completed successfully
mean_quality        — mean judge quality score
mean_tokens         — mean tokens per task
median_time         — median wall clock time
p95_time            — 95th percentile time (tail latency)
composite_score     — the single number we optimize
```

### results log

append-only TSV file tracking every experiment:

```
commit	composite	pass_rate	mean_quality	mean_tokens	status	description
```

this is the audit trail. it answers: what was tried, what worked, what
didn't, and why.

## implementation plan

### phase 1: eval harness (week 1-2)

build the eval infrastructure. no auto-loop yet — just the ability to
measure ah's performance on a fixed task set.

1. define 10 initial eval tasks (prompt + repo snapshot + expectations)
2. build the eval runner (setup, run ah, capture results)
3. build the judge (LLM-based quality scoring)
4. build the aggregator (composite score from per-task scores)
5. run baseline eval, record initial scores
6. validate: re-run and check score stability (variance < 5%)

deliverables:
- `eval/` directory with tasks, harness, judge
- `make eval` target
- baseline results

### phase 2: manual experiment loop (week 3)

use the eval harness manually. human proposes changes, runs eval, decides
keep/discard. this validates the metric before automating.

1. run 5-10 manual experiments
2. verify that the composite score correlates with intuition
   (changes you think are good should score higher)
3. adjust judge rubric if scores don't match intuition
4. calibrate thresholds (diff size gate, score improvement threshold)

deliverables:
- validated metric (composite score tracks real quality)
- calibrated thresholds
- initial results.tsv with manual experiments

### phase 3: automated loop (week 4-5)

close the loop. the agent proposes, evals, and decides autonomously.

1. write the proposal skill (what to change, guided by eval results)
2. write the autowork loop script (propose → apply → eval → decide)
3. add `make autowork` target
4. run overnight, review results in the morning
5. add a reflect-like analysis phase for autowork runs

deliverables:
- `skills/autowork/` with SKILL.md and tools
- `autowork.mk` with loop targets
- `.github/workflows/autowork.yml` scheduled workflow

### phase 4: scaling (week 6+)

expand the eval set, improve the proposal agent, add parallelism.

1. grow eval set to 50+ tasks
2. add task categories (easy/medium/hard, by capability)
3. parallelize eval runs (run tasks concurrently)
4. add SWE-bench subset as external validation
5. build a dashboard for tracking score over time

## risks and mitigations

### risk: metric gaming

the agent optimizes the metric, not the thing the metric measures.
examples: hardcoding expected outputs, overfitting to specific tasks.

**mitigation**: periodic human review of kept changes. the results.tsv
and git history make this easy. rotate eval tasks periodically. hold out
a test set the agent never sees.

### risk: eval instability

LLM-based judging introduces variance. the same change might score
differently on successive runs.

**mitigation**: run each eval task N times (N=3) and use the median.
require improvement > noise floor to keep. measure and report variance.

### risk: slow eval cycle

if each experiment takes 30+ minutes, progress is too slow.

**mitigation**: fast tasks (< 5 min each), parallel execution, cache
unchanged results. 10 tasks × 5 min = 50 min per experiment. with
3-run median: 150 min. this gives ~10 experiments/day. acceptable for
a start; parallelize to improve.

### risk: catastrophic changes

the agent makes a change that passes eval but breaks something not
covered by the eval set.

**mitigation**: `make ci` gate before eval. eval set should be
comprehensive. periodic manual testing. the keep/discard ratchet means
we can always revert to the last known-good commit.

### risk: diminishing returns

like autoresearch, improvements will flatten over time.

**mitigation**: this is expected, not a failure. when the curve flattens:
expand the eval set (harder tasks), expand the mutable zone (more things
the agent can change), or refine the proposal skill (human meta-optimization).

## comparison to existing work loop

| aspect | work loop | autowork loop |
|--------|-----------|---------------|
| optimizes | issue completion | ah's task-completion ability |
| input | github issues | eval task set |
| metric | check verdict (pass/fail) | composite eval score |
| cycle time | ~1 hour | ~1-3 hours |
| scope | any repo | ah itself |
| convergence | 3 retries per issue | keep/discard ratchet |
| human role | file issues | maintain eval set + judge |

the two loops are complementary. the work loop improves ah by completing
human-filed issues. the autowork loop improves ah by systematically
searching for improvements that make it better at tasks. the work loop
is breadth (many repos, many issues). the autowork loop is depth (one
repo, one metric, relentless optimization).

## open questions

1. **eval task sourcing**: where do the initial 10 tasks come from? options:
   past ah issues, SWE-bench subset, synthetic tasks, or hand-written.

2. **judge calibration**: how do we validate that the judge's scores
   correlate with human judgment? need a calibration set with human
   ratings.

3. **proposal guidance**: what should the proposal skill focus on?
   options: system prompt tuning, tool behavior, loop parameters,
   error handling. start broad or narrow?

4. **resource budget**: each experiment costs API tokens. at ~50k tokens
   per eval task × 10 tasks × 3 runs = ~1.5M tokens per experiment.
   how many experiments per day can we afford?

5. **interaction with work loop**: should autowork changes go through the
   normal PR process (autowork proposes, work loop reviews)? or bypass
   it for speed?
