# autowork: autonomous improvement loop

design for an automated loop that continuously improves a target
codebase by measuring its performance, making changes, and keeping
only improvements.

## two layers

```
┌─────────────────────────────────────────────────────┐
│  autowork (this repo)                               │
│  loop machinery, decision logic, result tracking    │
│                                                     │
│  propose → apply → gate → measure → decide → log   │
└──────────────────────┬──────────────────────────────┘
                       │ reads
┌──────────────────────▼──────────────────────────────┐
│  optimization contract (per-target)                 │
│  "what better means and how to measure it"          │
│  analogous to program.md in autoresearch            │
└─────────────────────────────────────────────────────┘
```

**autowork** (layer 1) is the loop itself: clone, propose, gate,
measure, decide, log. it lives in this repo alongside the existing
work loop. it is target-agnostic — it reads an optimization contract
and executes the cycle.

**optimization contract** (layer 2) is per-target. it's the target's
`program.md` — a document that tells the loop what "better" means
for this specific codebase. it declares:

- how to build and validate (`make ci`)
- how to measure quality (the metric)
- what files are mutable vs immutable
- what kinds of changes to explore (proposal guidance)
- how to judge nonfunctional quality (rubric + weights)

for ah, this includes eval tasks (run ah on coding tasks, score the
output). for another target it might be benchmarks, test suites,
performance measurements, or something else entirely. the loop
doesn't prescribe the measurement strategy — the contract does.

this separation means:
- improving the loop machinery benefits all targets
- adding a new target means writing a contract, not changing the loop
- contracts are versioned in their respective repos

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

### pi-autoresearch (davebcn87/pi-autoresearch)

agent-native experiment loop for pi (a coding agent). extends
autoresearch with several sharp ideas:

- **separation of extension (infrastructure) from skill (domain)**.
  the generic loop tools (init, run, log) know nothing about what's
  being optimized. domain knowledge lives in a skill prompt.
- **append-only JSONL state** (`autoresearch.jsonl`). survives agent
  restarts, context resets, branch switches. agents resume by reading
  the file + a living markdown doc (`autoresearch.md`).
- **living document** (`autoresearch.md`). like `program.md` but
  updated by the agent during the loop. accumulates "what's been
  tried" so resuming agents don't repeat failed ideas.
- **measurement script** (`autoresearch.sh`). outputs `METRIC name=value`
  lines. the loop doesn't know how metrics are computed — the script
  is the contract boundary.
- **secondary metrics** for monitoring (compile time, memory, etc.)
  tracked alongside the primary metric but don't affect keep/discard.
  prevents multi-objective confusion.
- **segment-based re-init**. `init_experiment` can be called again
  with a new baseline and metric. allows pivoting optimization
  targets without losing history.
- **git as audit trail**. kept experiments auto-commit with a
  `Result: {...}` JSON trailer in the commit message. queryable via
  `git log --grep`.

key insight: separate the loop infrastructure from the domain
knowledge. the loop is generic; the "what to optimize" lives in a
measurement script + skill prompt.

### working (whilp/working)

the existing work loop already automates the PDCA cycle for github issues:

```
pick → clone → build → plan → do → push → check → act
```

it runs hourly, handles retries (3 loops), and has a reflect phase for
retrospective analysis. but it optimizes *for completing issues*, not
*for improving a target's ability to do its job*.

## layer 1: the loop (target-agnostic)

everything in this section is general. it applies regardless of what
repo is being optimized.

### loop phases

```
┌──────────────────────────────────────────────────────────┐
│                    AUTOWORK LOOP                         │
│                                                          │
│  ┌─────────┐  ┌───────┐  ┌──────┐  ┌─────────┐  ┌──────┐  │
│  │ propose │─▶│ apply │─▶│ gate │─▶│ measure │─▶│decide│  │
│  └─────────┘  └───────┘  └──────┘  └─────────┘  └──┬───┘  │
│       ▲                                          │      │
│       └──────────────────────────────────────────┘      │
└──────────────────────────────────────────────────────────┘
```

**1. propose**

an agent proposes a change to the target repo. it has access to:

- the target source code
- the target config (mutable zones, proposal guidance)
- recent eval results (what scored well/poorly)
- the discard log (what was tried and failed)

the proposal is a description + a branch with commits. the agent only
modifies files within declared mutable zones.

**2. apply**

the proposed changes are applied to a fresh target checkout. build
from clean state.

**3. gate**

cheap, deterministic checks before expensive eval:

- does the target's build command pass? (`make ci`, `cargo test`, etc.)
- is the diff within the size limit?
- are all changed files within mutable zones?
- do static signals pass? (type checks, format, lint)

if any gate fails, discard immediately — no eval needed. gates are
fast and free compared to eval.

**4. measure**

run the target's measurement script. the loop doesn't know what the
script does — it just calls it and reads the JSON output. the script
is the contract boundary between the loop (generic) and the
measurement strategy (target-specific).

the measurement script might run eval tasks (ah), benchmarks (cosmic),
test suites, or anything else. the loop only cares about the
`composite` field in the output.

**5. decide**

compare to current best score, with a simplicity criterion adapted
from autoresearch:

```
if new_score > best_score + noise_threshold:
    if complexity_delta <= 0:
        keep (better AND simpler — ideal)
    elif new_score > best_score + complexity_tax:
        keep (better enough to justify added complexity)
    else:
        discard (improvement too small to justify complexity cost)
elif abs(new_score - best_score) <= noise_threshold:
    if complexity_delta < 0:
        keep (equal performance, simpler — always a win)
    else:
        discard (equal performance, more complex — never worth it)
else:
    discard (worse)
```

the key insight from autoresearch: **simplification at equal
performance is always worth keeping. complexity must earn its place.**

`complexity_delta` is measured from the diff:
- lines added - lines removed (net growth)
- new files added
- new dependencies introduced
- cyclomatic complexity increase (if measurable)

a negative complexity_delta means the codebase got simpler. these
changes get a lower bar for acceptance. a positive delta means the
change adds weight — it needs to produce proportionally more value.

`complexity_tax` scales with `complexity_delta`: bigger diffs need
bigger improvements. a 2-line change that gains 0.01 is fine. a
50-line change that gains 0.01 is not.

```
complexity_tax = base_tax × log(1 + abs(complexity_delta))
```

this creates a natural pressure toward elegant, minimal solutions.
the agent learns that deleting code is cheap to keep and adding code
is expensive to keep.

log the result regardless:

```tsv
commit	composite	pass_rate	mean_quality	mean_tokens	status	description
b2c3d4e	0.74	0.80	0.85	42000	keep	reduce tool prompt verbosity
c3d4e5f	0.71	0.70	0.82	48000	discard	add retry logic to edit tool
```

### measurement contract

the loop requires exactly one thing from the target: a measurement
script that returns JSON.

```sh
# the loop calls:
eval/measure.sh

# the script returns:
{
  "composite": 0.74,          # primary metric (required)
  "secondary": {              # monitoring metrics (optional)
    "pass_rate": 0.80,
    "mean_tokens": 42000,
    "p95_time": 285
  }
}
```

how the script computes `composite` is entirely target-specific:

- **ah**: run eval tasks, judge outputs, aggregate scores
- **cosmic**: run benchmarks, compute speed × correctness
- **a web app**: run lighthouse, measure performance score
- **a library**: run test suite, measure coverage × perf

the script is the contract boundary. the loop treats it as a black
box. this is what makes autowork target-agnostic — it doesn't need
to understand eval tasks, judges, or benchmarks. it just reads a
number and decides keep/discard.

the primary metric must have a declared direction (higher or lower
is better). secondary metrics are tracked but don't affect the
decision — they help humans understand *why* the primary changed.

### state persistence

following pi-autoresearch's pattern, the loop maintains two state
artifacts that survive context resets and agent restarts:

**results.jsonl** — append-only experiment log. each line is a JSON
record with commit, scores, status, description, timestamp. the loop
never truncates this file — it only appends. on resume, the loop
reads this file to reconstruct state (current best, experiment count,
what's been tried).

**autowork-state.md** — living document updated by the loop after each
experiment. contains:

- current best score and commit
- what's been tried (accumulated, so resuming agents don't repeat)
- secondary metric trends
- recent experiment summaries

this document is the loop's memory across sessions. an agent that
starts with zero context reads this file and knows exactly where
things stand.

### git integration

kept experiments are auto-committed with a `Result:` JSON trailer in
the commit message:

```
loop: reduce tool prompt verbosity

Result: {"composite":0.74,"pass_rate":0.80,"status":"keep"}
```

this makes the experiment history queryable via
`git log --grep="Result:"` and preserves the full audit trail in
version control alongside the code changes.

### scope control

the agent should make **small, focused changes**. enforce via:

1. **one-change-per-experiment rule**: each proposal is a single
   conceptual change (one commit, or a small coherent set).
2. **diff size gate**: reject proposals with large diffs (> N lines
   changed). N is set in the target config (default: 50).
3. **zone enforcement**: changes outside declared mutable zones are
   rejected at the gate phase. the agent cannot modify the eval
   harness, the judge, or the task set.
4. **simplicity criterion**: complexity_tax in the decision function
   creates continuous pressure toward small, clean changes.

### composite eval score

```
score = task_success × quality_factor / cost_factor

where:
  task_success  ∈ {0, 1}         — did the task complete correctly?
  quality_factor ∈ [0.0, 1.0]    — judge assessment of output quality
  cost_factor   = tokens / budget — normalized resource consumption
```

this rewards completing tasks correctly, with high quality, using fewer
resources. a perfect score means: task done, judge approves, minimal tokens.

### results log

append-only TSV file tracking every experiment. this is the audit
trail. it answers: what was tried, what worked, what didn't, and why.

the loop writes one line per experiment, regardless of keep/discard.
the target config controls which columns are included beyond the
required set (commit, composite, status, description).

### observability

the loop extracts metrics from whatever artifacts the target produces.
the target config declares where to find them and how to parse them.
common patterns:

- session database (ah): tokens, latency, tool calls, errors
- stdout/stderr capture: timing, exit codes
- file artifacts: generated files, diffs

aggregate metrics across the eval suite:

```
pass_rate           — fraction of tasks completed successfully
mean_quality        — mean judge quality score
mean_tokens         — mean tokens per task (if applicable)
median_time         — median wall clock time
p95_time            — 95th percentile time (tail latency)
composite_score     — the single number we optimize
```

## guarding against overfitting

the keep/discard ratchet creates strong selection pressure on a fixed
task set. the agent will find whatever makes the number go up. if the
task set is small or narrow, "better at tasks" diverges from "better
at real work". this is the classic train/test split problem.

these defenses are part of the loop (layer 1), not target-specific.

### defense in depth

no single mechanism is sufficient. layer multiple defenses:

**1. holdout set (primary defense)**

split eval tasks into two pools:

- **train set** (70%) — used for the keep/discard decision
- **holdout set** (30%) — scored but never used for decisions

the agent never sees holdout scores. monitor holdout score alongside
train score. if train score rises but holdout is flat or falling, the
agent is overfitting. halt the loop and investigate.

```
experiment  train_score  holdout_score  status
baseline    0.72         0.71           —
exp-001     0.74         0.72           keep (both up)
exp-007     0.78         0.71           keep (train up, holdout flat — watch)
exp-012     0.80         0.68           HALT (divergence detected)
```

holdout tasks should overlap in capability coverage with train tasks
but use different repos, prompts, and expected outputs. same skills
tested, different instances.

**2. task rotation**

periodically (e.g. every 20 experiments or weekly), rotate tasks:

- move some holdout tasks into the train set
- move some train tasks into the holdout set
- add new tasks to replace retired ones

this prevents the agent from implicitly memorizing the train set
through accumulated kept changes. each rotation resets the selection
pressure.

rotation must be a human decision — the agent must never control which
tasks are in which set.

**3. generalization probes**

periodically run the current best on entirely new tasks — tasks
never in either set. these are one-off probes, not recurring:

- hand-written tasks targeting a capability the agent hasn't seen
- tasks from external benchmarks (SWE-bench subset)
- real issues from the target's own history (retrospective replay)

generalization probes answer: "does this improvement help in general,
or just on our eval set?" they are expensive (human effort to create)
so use them sparingly — at milestones, not every experiment.

**4. change auditing**

after every N kept experiments (e.g. N=5), a human reviews:

- the diffs of all kept changes
- whether improvements feel like real improvements or like gaming
- whether the agent is pattern-matching to specific task features

signs of overfitting to watch for:

- changes that help only 1-2 tasks and are neutral on the rest
- system prompt additions that reference specific patterns from tasks
- hardcoded special cases (if input looks like X, do Y)
- complexity growth without clear purpose

the simplicity criterion (discard changes that add complexity without
proportional gain) is also an overfitting defense — overfitting often
manifests as "weird special-case logic that happens to help".

**5. capability-stratified scoring**

don't just track one composite number. break scores down by capability:

```
capability     train  holdout  delta
file_editing   0.85   0.82     +0.03
multi_file     0.70   0.68     +0.02
debugging      0.75   0.60     +0.15  ← suspicious: big gap
test_writing   0.80   0.79     +0.01
refactoring    0.65   0.64     +0.01
```

a large gap in one capability signals the agent found a trick that
works on specific tasks, not a general improvement.

capabilities are declared in the target config. the loop tracks
per-capability scores automatically.

**6. anti-memorization in task design**

design tasks to resist memorization:

- use parameterized tasks where possible (same structure, different
  variable names / file names / values). the harness generates a fresh
  instance each run.
- avoid tasks where the "answer" is a specific string the agent could
  learn to emit. prefer tasks where correctness is structural (tests
  pass, behavior changes, refactoring preserves semantics).
- include tasks where the optimal approach depends on context that
  changes between runs (e.g. file contents vary slightly).

## nonfunctional requirements

the composite score should capture not just "did it work?" but "how
well did it work?" a correct change that is ugly, sprawling, or
fragile is worse than a correct change that is clean, minimal, and
robust.

how nonfunctional quality is measured is up to the target's
measurement script. but for targets that use an LLM judge (like ah),
the following framework of quality dimensions is useful. targets
that measure quality differently (benchmarks, test suites) can ignore
this section entirely.

### quality dimensions

the judge scores each task on multiple dimensions. each dimension gets
a score from 0.0 to 1.0. quality_factor is their weighted product.

**1. correctness (weight: mandatory gate)**

did the change actually solve the task? this is binary: pass or fail.
if correctness fails, quality_factor = 0 regardless of other scores.
verified by:

- expected tests pass
- expected behavior observable
- no regressions (existing tests still pass)

correctness is not a dimension to score — it's a gate. everything
below only matters if correctness passes.

**2. minimality (weight: configurable, default 0.30)**

did the agent make the smallest change that solves the problem?

| signal | good | bad |
|--------|------|-----|
| lines changed | few, focused | many, scattered |
| files touched | only necessary ones | unrelated files modified |
| scope creep | none | "while I was here" changes |
| unnecessary additions | none | comments, docstrings, type hints on untouched code |

scoring guide:
- 1.0 — minimal diff; every line serves the task
- 0.7 — slight scope creep (1-2 unnecessary changes)
- 0.4 — significant unnecessary changes
- 0.1 — rewrote large sections without need

**3. readability (weight: configurable, default 0.25)**

would a competent human reviewer understand the change?

| signal | good | bad |
|--------|------|-----|
| naming | clear, conventional | obscure, abbreviated |
| structure | follows existing patterns | invents new patterns |
| complexity | proportional to problem | over-engineered |
| consistency | matches surrounding code style | introduces new style |

scoring guide:
- 1.0 — reads naturally; follows project conventions
- 0.7 — mostly clear; minor style inconsistencies
- 0.4 — hard to follow; unconventional patterns
- 0.1 — confusing; would be rejected in review

the judge assesses readability by examining the diff in context of the
surrounding code. key question: "does this look like it belongs?"

**4. robustness (weight: configurable, default 0.25)**

does the change handle edge cases and failure modes?

| signal | good | bad |
|--------|------|-----|
| error handling | appropriate for the context | swallowed errors, bare try/except |
| input validation | at boundaries | everywhere (defensive overload) or nowhere |
| invariants | preserved or strengthened | weakened or ignored |
| assumptions | documented or obvious | hidden |

scoring guide:
- 1.0 — handles realistic failure cases; clear error paths
- 0.7 — mostly robust; minor gaps
- 0.4 — fragile; obvious failure modes unhandled
- 0.1 — would break on non-happy-path inputs

note: over-handling is also a robustness failure. adding try/catch
around every line, validating inputs that are already validated
upstream, or handling impossible states adds complexity without value.
the rubric should penalize both under- and over-handling.

**5. efficiency (weight: configurable, default 0.20)**

did the agent use resources well?

| signal | good | bad |
|--------|------|-----|
| algorithmic | appropriate for scale | needlessly quadratic, etc. |
| resource use | bounded | unbounded allocations, leaks |
| API surface | minimal | introduces unnecessary dependencies |

scoring guide:
- 1.0 — efficient; no waste
- 0.7 — acceptable; minor inefficiencies
- 0.4 — wasteful; could be much simpler
- 0.1 — pathologically inefficient

### composite quality_factor

```
quality_factor = minimality^w1 × readability^w2 × robustness^w3 × efficiency^w4
```

geometric mean with weights ensures that a zero in any dimension tanks
the overall score, and that balanced quality beats lopsided quality.
weights are set in the target config.

example (default weights):
```
minimality=0.9, readability=0.8, robustness=0.7, efficiency=0.9
quality_factor = 0.9^0.30 × 0.8^0.25 × 0.7^0.25 × 0.9^0.20
               = 0.970 × 0.946 × 0.915 × 0.979
               = 0.821
```

### the simplicity criterion

autoresearch encodes a powerful meta-rule: "all else being equal,
simpler is better." this applies at two levels:

**level 1: the code change itself (captured by minimality dimension)**

the minimality dimension rewards small diffs. but simplicity is more
than diff size — it's about whether the resulting codebase is simpler
or more complex after the change. a 20-line refactoring that replaces
40 lines of spaghetti is a simplification even though the diff is
large.

the judge should assess: is the codebase simpler after this change?
not just "is the diff small?" consider:

- did the change reduce total line count?
- did it eliminate special cases, branches, or indirection?
- did it consolidate duplicated logic?
- did it remove unused code or dead paths?

**level 2: the keep/discard decision (captured by complexity_tax)**

the decision logic penalizes complexity in the acceptance threshold
itself. even if the judge gives high quality scores, the decision
function requires bigger improvements to accept bigger diffs. this
creates a ratchet toward simplicity: the easiest changes to keep are
deletions and simplifications.

**practical effect**: over many experiments, the agent learns that:

- deleting 5 lines and maintaining score → always kept
- adding 50 lines for +0.01 score → usually discarded
- rewriting 30 lines into 15 cleaner lines at equal score → kept

this pressure compounds. each kept simplification makes the codebase
easier to understand, which makes future improvements easier to find,
which accelerates the loop.

### judge rubric format

the judge receives a structured rubric and must return structured
scores. this constrains the judge to evaluate what we care about
rather than inventing its own criteria.

the rubric template is general; the target config fills in
target-specific context (e.g. what conventions to check for, what
"idiomatic" means for this language/project).

```markdown
## judge rubric

evaluate the agent's work on this task. score each dimension 0.0-1.0.

### correctness (gate)
- do the expected tests pass?
- does the change achieve the stated goal?
- are there regressions?
verdict: PASS or FAIL

### minimality (0.0-1.0)
- how many lines were changed? how many files?
- are all changes necessary for the task?
- is there scope creep?
score: N.N
reasoning: ...

### readability (0.0-1.0)
- does the code follow existing project conventions?
- are names clear and consistent?
- would a reviewer understand the change without explanation?
score: N.N
reasoning: ...

### robustness (0.0-1.0)
- are realistic failure modes handled?
- is error handling proportional (not under- or over-done)?
- are invariants preserved?
score: N.N
reasoning: ...

### efficiency (0.0-1.0)
- is the approach algorithmically appropriate?
- are resources used well?
- are dependencies minimal?
score: N.N
reasoning: ...
```

the judge returns JSON:

```json
{
  "correctness": "pass",
  "minimality": 0.9,
  "readability": 0.8,
  "robustness": 0.7,
  "efficiency": 0.9,
  "quality_factor": 0.821,
  "reasoning": {
    "minimality": "clean diff, only touched 2 files",
    "readability": "good naming but inconsistent indent style",
    "robustness": "missing nil check on optional field",
    "efficiency": "appropriate approach"
  }
}
```

### static signals (cheap, supplement the judge)

some quality signals are measurable without an LLM:

- **diff size**: lines added + removed + modified
- **file count**: number of files touched
- **type check**: does the build command still pass?
- **format check**: does the format check still pass?
- **test count delta**: did the agent add/remove tests?
- **lint violations**: new warnings introduced?

these can gate before the judge runs (fail fast on obvious problems)
or supplement the judge's score with objective measurements. they are
cheap and deterministic — unlike the judge, they don't add variance.

which static signals are available depends on the target. the target
config declares them.

### calibrating the weights

the dimension weights are a starting point. calibrate during phase 2
(manual experiments):

1. have a human score 10+ task completions on all dimensions
2. compare human scores to judge scores (judge accuracy)
3. compare composite quality_factor to human "overall quality" rating
4. adjust weights until composite tracks human intuition

if minimality matters more in practice than robustness (or vice versa),
the weights should reflect that. the point is to have explicit,
adjustable knobs rather than a black-box "quality" score.

calibration is per-target — different projects may value different
dimensions.

## layer 2: the optimization contract

the optimization contract is the target's `program.md`. it's a
document (plus supporting files) that lives in the target repo and
tells the loop everything it needs to know to optimize this codebase.

the contract answers three questions:

1. **what can change?** — mutable zones (files the agent may edit)
   and immutable zones (measurement infrastructure, schemas, etc.)
2. **how do we measure?** — the measurement strategy. this is
   target-specific and unconstrained by the loop.
3. **what should we try?** — proposal guidance. what kinds of changes
   are likely to help, what to avoid, what's been tried before.

### contract format

```
AUTOWORK.md          — the contract (human-written, like program.md)
eval/
  measure.sh         — measurement script (returns JSON with scores)
  judge.md           — quality rubric for LLM judge
  proposal.md        — guidance for the proposing agent
  ...                — target-specific eval infrastructure
```

`AUTOWORK.md` is the entry point. the loop reads it to understand the
target. it declares zones, points to the measurement script, and
provides context. example structure:

```markdown
# optimization contract for ah

## build
make ci

## zones
mutable: sys/system.md, sys/tools/*.tl, lib/ah/loop.tl, ...
immutable: eval/**, lib/ah/db.tl

## measurement
eval/measure.sh — runs eval tasks, returns composite score as JSON

## decision parameters
noise_threshold: 0.02
base_tax: 0.01
max_diff_lines: 50

## quality weights
minimality: 0.30, readability: 0.25, robustness: 0.25, efficiency: 0.20
```

the measurement script is the key abstraction. the loop calls it and
expects JSON back:

```json
{
  "composite": 0.74,
  "pass_rate": 0.80,
  "mean_quality": 0.85,
  "mean_tokens": 42000,
  "details": { ... }
}
```

how the script computes those numbers is entirely up to the target.
for ah, it runs eval tasks and judges them. for a benchmark target, it
might run benchmarks. for a library, it might run a test suite and
measure coverage + performance. the loop doesn't care — it just reads
the composite score and decides keep/discard.

## ah: the first optimization contract

ah is an agent harness written in teal. it manages agent sessions:
prompt → API call → tool execution → loop. its optimization contract
defines what "better" means for an agent harness.

### AUTOWORK.md for ah

```markdown
# optimization contract: ah

## objective
improve ah's ability to complete coding tasks: fix bugs, add features,
write tests, refactor code. measure by running ah on a fixed set of
eval tasks and scoring the outputs.

## build
make ci

## primary metric
composite eval score (higher is better):
  score = task_success × quality_factor / cost_factor

## measurement
eval/measure.sh — runs eval tasks, judges outputs, returns composite.

## zones
mutable:
  sys/system.md, sys/tools/*.tl, lib/ah/loop.tl,
  lib/ah/compact.tl, lib/ah/truncate.tl, lib/ah/api.tl

immutable:
  eval/**, lib/ah/db.tl

## secondary metrics (monitoring, not decision)
  pass_rate, mean_quality, mean_tokens, p95_time

## quality weights
  minimality: 0.30, readability: 0.25, robustness: 0.25, efficiency: 0.20

## decision
  noise_threshold: 0.02, base_tax: 0.01, max_diff_lines: 50

## what to try
see eval/proposal.md
```

### measurement script

ah's `eval/measure.sh` runs eval tasks and returns JSON. the tasks
are ah-specific: run ah on coding problems, judge the output.

```
eval/
  measure.sh          — orchestrates: setup → run → judge → aggregate
  judge.md            — quality rubric for LLM judge
  proposal.md         — guidance for proposing agent
  tasks/
    001-fix-off-by-one/
      prompt.md       — task description
      repo.bundle     — starting repo state
      expect.md       — expected outcomes
      config.toml     — time/token budget
      capability      — "debugging"
    002-add-timeout/
      ...
```

the tasks cover ah's key capabilities:

1. **file editing** — single-file bug fix or feature
2. **multi-file changes** — coordinated cross-file changes
3. **test writing** — write tests for existing code
4. **debugging** — diagnose and fix failing tests
5. **refactoring** — restructure while preserving behavior
6. **tool use** — effective use of read/write/edit/bash

tasks should be deterministic to set up, fast to run (< 5 min each),
and objectively judgeable. start with 10-20, grow over time.

### ah-specific observability

ah records everything in session.db — zero-cost instrumentation:

- every API call (tokens, latency, model)
- every tool call (input, output, duration)
- loop detection events, compaction events, stop reasons

`measure.sh` extracts per-task metrics from session.db:

```
tokens_in, tokens_out, api_calls, tool_calls, tool_errors,
compactions, loop_warnings, wall_time_s
```

### ah-specific quality considerations

ah is teal (typed lua). readability in this context means:

- follows teal conventions (typed records, explicit returns)
- matches ah's existing patterns (tool format, error prefixing)
- uses cosmic APIs idiomatically (child.spawn, json.encode)
- respects ah's design principles (composable, embeddable, minimal)

the judge rubric for ah should reference AGENTS.md and the existing
code style. this is encoded in `eval/judge.md` in the ah repo.

### what the proposing agent should explore

ah has several high-leverage areas:

- **system prompt** (`sys/system.md`): prompt engineering directly
  shapes agent behavior. small changes can have large effects.
- **tool implementations** (`sys/tools/*.tl`): tool behavior shapes
  task completion. better error messages, smarter defaults.
- **tool guidance** (tool `system_prompt` fields): how the agent
  decides which tool to use and with what parameters.
- **loop parameters** (`lib/ah/loop.tl`): loop detection thresholds,
  compaction triggers, steering messages.
- **truncation** (`lib/ah/truncate.tl`): what the agent sees from
  long tool outputs. too much = noise; too little = lost context.
- **API params** (`lib/ah/api.tl`): caching strategy, retry logic.

## other targets (future)

to add a new target, write an AUTOWORK.md + measurement script.
examples:

- **cosmic** — optimize the lua runtime. measurement: run benchmarks,
  compare speed × correctness. mutable: stdlib, builtins.
- **working** — optimize the work loop itself. measurement: replay
  historical issues, compare success rate. mutable: skills, tools.
- **any codebase** — if you can define "better" and write a script
  that measures it, autowork can optimize it.

## comparison to existing work loop

| aspect | work loop | autowork loop |
|--------|-----------|---------------|
| optimizes | issue completion | target's task-completion ability |
| input | github issues | eval task set |
| metric | check verdict (pass/fail) | composite eval score |
| cycle time | ~1 hour | ~1-3 hours |
| scope | any repo | one target repo |
| convergence | 3 retries per issue | keep/discard ratchet |
| human role | file issues | maintain eval set + judge |
| generality | general (any repo) | general (any target config) |

the two loops are complementary. the work loop improves a target by
completing human-filed issues (breadth). the autowork loop improves a
target by systematically searching for changes that improve eval
scores (depth).

## risks and mitigations

### risk: metric gaming

the agent optimizes the metric, not the thing the metric measures.
examples: hardcoding expected outputs, overfitting to specific tasks.

**mitigation**: layered overfitting defenses (see above). periodic
human review of kept changes. the results log and git history make
this easy.

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

**mitigation**: build command gate before eval. holdout set catches
some cases. periodic manual testing. the keep/discard ratchet means
we can always revert to the last known-good commit.

### risk: diminishing returns

like autoresearch, improvements will flatten over time.

**mitigation**: this is expected, not a failure. when the curve flattens:
expand the eval set (harder tasks), expand the mutable zone (more things
the agent can change), or refine the proposal guidance (human
meta-optimization).

## implementation plan

### phase 1: eval harness for ah (week 1-2)

build the eval infrastructure. no auto-loop yet — just the ability to
measure ah's performance on a fixed task set.

1. define 10 initial eval tasks for ah (prompt + repo snapshot + expectations)
2. build the eval runner (setup, run ah, capture results)
3. build the judge (LLM-based quality scoring with rubric)
4. build the aggregator (composite score from per-task scores)
5. run baseline eval, record initial scores
6. validate: re-run and check score stability (variance < 5%)

deliverables:
- `eval/` directory in ah repo with tasks, harness, judge
- `make eval` target in ah
- baseline results

### phase 2: manual experiment loop (week 3)

use the eval harness manually. human proposes changes, runs eval, decides
keep/discard. this validates the metric before automating.

1. run 5-10 manual experiments
2. verify that the composite score correlates with intuition
   (changes you think are good should score higher)
3. adjust judge rubric if scores don't match intuition
4. calibrate thresholds (diff size gate, score improvement threshold)
5. calibrate quality weights per dimension

deliverables:
- validated metric (composite score tracks real quality)
- calibrated thresholds and weights
- initial results.tsv with manual experiments

### phase 3: automated loop (week 4-5)

close the loop. the agent proposes, evals, and decides autonomously.
build the general loop machinery in this repo (working).

1. define target config format (toml)
2. write the loop script (propose → apply → gate → eval → decide)
3. write the proposal skill
4. add `make autowork` target
5. add holdout set and divergence monitoring
6. run overnight, review results in the morning

deliverables:
- `skills/autowork/` with SKILL.md and tools
- `autowork.mk` with loop targets
- `.github/workflows/autowork.yml` scheduled workflow
- target config for ah

### phase 4: scaling and generalization (week 6+)

expand eval, improve proposals, add more targets.

1. grow ah eval set to 50+ tasks
2. add task categories (easy/medium/hard, by capability)
3. parallelize eval runs (run tasks concurrently)
4. add SWE-bench subset as external validation
5. build a dashboard for tracking score over time
6. add second target (cosmic or working) to validate generality

## open questions

1. **eval task sourcing**: where do the initial 10 ah tasks come from?
   options: past ah issues, SWE-bench subset, synthetic tasks, or
   hand-written.

2. **judge calibration**: how do we validate that the judge's scores
   correlate with human judgment? need a calibration set with human
   ratings.

3. **proposal guidance**: what should the ah proposal skill focus on?
   options: system prompt tuning, tool behavior, loop parameters,
   error handling. start broad or narrow?

4. **resource budget**: each experiment costs API tokens. at ~50k tokens
   per eval task × 10 tasks × 3 runs = ~1.5M tokens per experiment.
   how many experiments per day can we afford?

5. **interaction with work loop**: should autowork changes go through the
   normal PR process (autowork proposes, work loop reviews)? or bypass
   it for speed?

6. **target config location**: should target configs live in the target
   repo (close to the code) or in this repo (close to the loop)?
   leaning toward target repo for ownership, with this repo providing
   defaults and the loop machinery.
