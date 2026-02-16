# work.mk: work targets
#
# implements the PDCA work loop as make targets:
#   pick -> clone -> plan -> do -> push -> check -> act
#
# convergence: check writes o/do/feedback.md when verdict is needs-fixes.
# since do depends on feedback.md, the next make run re-executes do -> push -> check.
# the caller runs `make work` which loops until convergence or a retry limit.

REPO ?=

export PATH := $(CURDIR)/$(o)/bin:$(PATH)

# target repo clone
repo_dir := $(o)/repo
default_branch = $(or $(shell git -C $(repo_dir) symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/||'),origin/main)

# named targets
pick_dir := $(o)/pick
issue := $(pick_dir)/issue.json
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
# preflight (labels, pr-limit), fetch issues, pick one, mark doing

$(issue): $(ah) $(cosmic)
	@mkdir -p $(pick_dir)
	@echo "==> pick"
	@timeout 60 $(ah) -n \
		-m sonnet \
		--skill pick \
		--must-produce $(issue) \
		--max-tokens 50000 \
		--db $(pick_dir)/session.db \
		--tool "ensure_labels=skills/pick/tools/ensure-labels.tl" \
		--tool "count_open_prs=skills/pick/tools/count-open-prs.tl" \
		--tool "list_issues=skills/pick/tools/list-issues.tl" \
		--tool "set_issue_labels=skills/pick/tools/set-issue-labels.tl" \
		--tool "bash=" \
		<<< "REPO=$(REPO)"

.PHONY: pick
pick: $(issue)

# --- clone ---

branch = $(shell jq -r '.branch // empty' $(issue) 2>/dev/null)
repo_ready := $(repo_dir)/sha

$(repo_ready): $(issue)
	@test -n "$(branch)" || { echo "error: no branch in $(issue)"; exit 1; }
	@if [ ! -d $(repo_dir)/.git ]; then \
		echo "==> clone $(REPO)"; \
		gh repo clone $(REPO) $(repo_dir); \
	fi
	@echo "==> fetch"
	@git -C $(repo_dir) fetch origin
	@echo "==> checkout $(branch)"
	@git -C $(repo_dir) checkout -B $(branch) $(default_branch)
	@git -C $(repo_dir) rev-parse HEAD > $@

.PHONY: clone
clone: $(repo_ready)

# --- plan ---

.PHONY: plan
plan: $(plan)

$(plan): $(repo_ready) $(issue) $(ah)
	@echo "==> plan"
	@mkdir -p $(plan_dir)
	@timeout 180 $(ah) -n \
		-m opus \
		--sandbox \
		--skill plan \
		--must-produce $(plan) \
		--max-tokens 100000 \
		--db $(plan_dir)/session-$(LOOP).db \
		--unveil $(repo_dir):rx \
		--unveil $(plan_dir):rwc \
		--unveil .:r \
		< $(issue)

# --- do ---

$(feedback): $(plan)
	@mkdir -p $(@D)
	@touch $@

.PHONY: do
do: $(do_done)

$(do_done): $(repo_ready) $(plan) $(feedback) $(issue) $(ah)
	@echo "==> do"
	@mkdir -p $(do_dir)
	@if ! git -C $(repo_dir) diff --quiet $(default_branch)..HEAD 2>/dev/null; then \
		echo "  (retrying: resetting branch to $(default_branch))"; \
		git -C $(repo_dir) reset --hard $(default_branch); \
	fi
	@timeout 300 $(ah) -n \
		-m opus \
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
	@test -n "$(GH_TOKEN)" || { echo "error: GH_TOKEN not set"; exit 1; }
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
		-m sonnet \
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

act_dir := $(o)/act

$(act_done): $(check_done) $(issue) $(ah) $(cosmic)
	@mkdir -p $(act_dir)
	@echo "==> act"
	@timeout 60 $(ah) -n \
		-m sonnet \
		--skill act \
		--must-produce $(act_done) \
		--max-tokens 50000 \
		--db $(act_dir)/session-$(LOOP).db \
		--tool "comment_issue=skills/act/tools/comment-issue.tl" \
		--tool "create_pr=skills/act/tools/create-pr.tl" \
		--tool "set_issue_labels=skills/act/tools/set-issue-labels.tl" \
		--tool "bash=" \
		<<< "REPO=$(REPO) ISSUE_FILE=$(issue) ACTIONS_FILE=$(actions)"

# --- work: convergence loop ---

# work: converge on act_done, retrying up to 3 times.
# each attempt rebuilds the full chain (do -> push -> check -> act).
# earlier attempts tolerate failure; only the last must succeed.
# when check writes feedback.md, do_done becomes stale and re-runs.
.PHONY: work
converge := $(MAKE) "REPO=$(REPO)" $(act_done)
work:
	-@LOOP=1 $(converge)
	-@LOOP=2 $(converge)
	@LOOP=3 $(converge)
