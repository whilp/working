# work.mk: work targets
#
# implements the PDCA work loop as make targets:
#   pick -> clone -> plan -> do -> push -> check -> act
#
# convergence: check writes o/do/feedback.md when verdict is needs-fixes.
# since do depends on feedback.md, the next make run re-executes do -> push -> check.
# the caller runs `make work` which loops until convergence or a retry limit.

REPO ?=
MAX_PRS ?= 4
work_tl := lib/work/work.tl

export PATH := $(CURDIR)/$(o)/bin:$(PATH)

# target repo clone
repo_dir := $(o)/repo
default_branch = $(shell git -C $(repo_dir) symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/||')

# shared env vars for all work.tl subcommands
export WORK_REPO := $(REPO)
export WORK_MAX_PRS := $(MAX_PRS)
export WORK_INPUT := $(o)/pick/issues.json
export WORK_ISSUE := $(o)/pick/issue.json
export WORK_ACTIONS := $(o)/check/actions.json

# named targets
issue := $(o)/pick/issue.json
plan_dir := $(o)/plan
plan := $(plan_dir)/plan.md
do_dir := $(o)/do
feedback := $(do_dir)/feedback.md
do_done := $(do_dir)/done
push_done := $(o)/push/done
check_dir := $(o)/check
check_done := $(check_dir)/done
actions := $(check_dir)/actions.json
act_done := $(o)/act.json

.DELETE_ON_ERROR:

# LOOP: set by the work target (1, 2, 3) to give each convergence
# attempt its own session database. defaults to 1 for manual runs.
LOOP ?= 1

# --- pick ---
# preflight (labels, pr-limit) then fetch issues, pick one, mark doing

$(issue): $(work_tl) $(cosmic)
	@mkdir -p $(@D)
	@echo "==> pick"
	@$(work_tl) labels > /dev/null
	@$(work_tl) pr-limit > /dev/null
	@$(work_tl) issues > $(o)/pick/issues.json
	@$(work_tl) issue > $@
	@$(work_tl) doing > /dev/null

.PHONY: pick
pick: $(issue)

# --- clone ---

branch = $(shell jq -r .branch $(issue) 2>/dev/null)
repo_sha := $(repo_dir)/sha
repo_branch := $(repo_dir)/branch

$(repo_sha): $(issue)
	@if [ ! -d $(repo_dir)/.git ]; then \
		echo "==> clone $(REPO)"; \
		gh repo clone $(REPO) $(repo_dir); \
	fi
	@echo "==> fetch"
	@git -C $(repo_dir) fetch origin
	@echo "==> checkout $(branch)"
	@git -C $(repo_dir) checkout -B $(branch) $(default_branch)
	@git -C $(repo_dir) rev-parse HEAD > $(repo_sha)
	@echo $(branch) > $(repo_branch)

.PHONY: clone
clone: $(repo_sha)

# --- plan ---

.PHONY: plan
plan: $(plan)

$(plan): $(repo_sha) $(issue) $(ah)
	@echo "==> plan"
	@mkdir -p $(plan_dir)
	@timeout 180 $(ah) -n \
		--sandbox \
		--skill plan \
		--must-produce $(plan) \
		--max-tokens 100000 \
		--db $(plan_dir)/session-$(LOOP).db \
		--unveil $(repo_dir):rwcx \
		--unveil $(plan_dir):rwc \
		--unveil .:r \
		< $(issue)

# --- do ---

$(feedback): $(plan)
	@mkdir -p $(@D)
	@touch $@

.PHONY: do
do: $(do_done)

$(do_done): $(repo_sha) $(plan) $(feedback) $(issue) $(ah)
	@echo "==> do"
	@mkdir -p $(do_dir)
	@if ! git -C $(repo_dir) diff --quiet $(default_branch)..HEAD 2>/dev/null; then \
		echo "  (retrying: resetting branch to $(default_branch))"; \
		git -C $(repo_dir) reset --hard $(default_branch); \
	fi
	@timeout 300 $(ah) -n \
		--sandbox \
		--skill do \
		--must-produce $(do_dir)/do.md \
		--max-tokens 200000 \
		--db $(do_dir)/session-$(LOOP).db \
		--unveil $(repo_dir):rwcx \
		--unveil $(do_dir):rwc \
		--unveil $(plan_dir):r \
		--unveil .:r \
		< $(issue)
	@touch $@

# --- push ---

$(push_done): $(do_done)
	@echo "==> push"
	@mkdir -p $(@D)
	@git -C $(repo_dir) remote set-url origin https://x-access-token:$(GH_TOKEN)@github.com/$(REPO).git
	@git -C $(repo_dir) push --force-with-lease -u origin HEAD
	@touch $@

# --- check ---

.PHONY: check
check: $(check_done)

$(check_done): $(push_done) $(plan) $(issue) $(ah)
	@echo "==> check"
	@mkdir -p $(check_dir)
	@timeout 180 $(ah) -n \
		--sandbox \
		--skill check \
		--must-produce $(actions) \
		--max-tokens 100000 \
		--db $(check_dir)/session-$(LOOP).db \
		--unveil $(repo_dir):rx \
		--unveil $(check_dir):rwc \
		--unveil $(do_dir):rwc \
		--unveil $(plan_dir):r \
		--unveil .:r \
		< $(issue)
	@touch $@

# --- act ---

$(act_done): $(check_done) $(issue) $(work_tl) $(cosmic)
	@mkdir -p $(@D)
	@echo "==> act"
	@$(work_tl) act > $@

# --- work: convergence loop ---

# work: converge on act_done, retrying up to 3 times.
# each attempt rebuilds the full chain (do -> push -> check -> act).
# earlier attempts tolerate failure; only the last must succeed.
# when check writes feedback.md, do_done becomes stale and re-runs.
.PHONY: work
converge := $(MAKE) REPO=$(REPO) $(act_done)
work:
	-@LOOP=1 $(converge)
	-@LOOP=2 $(converge)
	@LOOP=3 $(converge)
