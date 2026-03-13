# autowork: detail — overfitting, quality, and risks

continuation of [autowork.md](autowork.md). covers overfitting defenses,
nonfunctional requirements, the judge rubric, risks, comparisons, and open
questions.

## guarding against overfitting

the keep/discard ratchet creates strong selection pressure on a fixed
task set. the agent will find whatever makes the number go up. if the
task set is small or narrow, "better at tasks" diverges from "better
at real work". this is the classic train/test split problem.

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

periodically run the current best ah on entirely new tasks — tasks
never in either set. these are one-off probes, not recurring:

- hand-written tasks targeting a capability the agent hasn't seen
- tasks from external benchmarks (SWE-bench subset)
- real issues from ah's own history (retrospective replay)

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
works on specific debugging tasks, not a general debugging improvement.

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

task_success answers "did it work?" but real-world value also depends
on *how* it worked. a correct change that is ugly, sprawling, or
fragile is worse than a correct change that is clean, minimal, and
robust. the quality_factor in the composite score must capture this.

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

**2. minimality (weight: 0.30)**

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

minimality is measurable: count lines changed, files touched, and
compare to a reference solution (or to the minimal set of files the
task requires changing). the judge can also assess this from the diff.

**3. readability (weight: 0.25)**

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

**4. robustness (weight: 0.25)**

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

**5. efficiency (weight: 0.20)**

did the agent use resources well?

this is partially captured by cost_factor (tokens / budget) in the
composite score, but the judge also assesses the *code's* efficiency:

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
quality_factor = minimality^0.30 × readability^0.25 × robustness^0.25 × efficiency^0.20
```

geometric mean with weights ensures that a zero in any dimension tanks
the overall score, and that balanced quality beats lopsided quality.

example:
```
minimality=0.9, readability=0.8, robustness=0.7, efficiency=0.9
quality_factor = 0.9^0.30 × 0.8^0.25 × 0.7^0.25 × 0.9^0.20
               = 0.970 × 0.946 × 0.915 × 0.979
               = 0.821
```

### judge rubric format

the judge receives a structured rubric and must return structured
scores. this constrains the judge to evaluate what we care about
rather than inventing its own criteria.

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
- **type check**: does `make check-types` still pass?
- **format check**: does `make check-format` still pass?
- **test count delta**: did the agent add/remove tests?
- **lint violations**: new warnings introduced?

these can gate before the judge runs (fail fast on obvious problems)
or supplement the judge's score with objective measurements. they are
cheap and deterministic — unlike the judge, they don't add variance.

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

### calibrating the weights

the dimension weights (0.30, 0.25, 0.25, 0.20) are a starting point.
calibrate during phase 2 (manual experiments):

1. have a human score 10+ task completions on all dimensions
2. compare human scores to judge scores (judge accuracy)
3. compare composite quality_factor to human "overall quality" rating
4. adjust weights until composite tracks human intuition

if minimality matters more in practice than robustness (or vice versa),
the weights should reflect that. the point is to have explicit,
adjustable knobs rather than a black-box "quality" score.

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
