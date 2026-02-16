# work.mk: work targets
#
# usage: REPO=owner/repo make pick
#
# phases:
#   pick    select an issue to work on
#   clone   clone target repo and check out work branch
#   plan    research the codebase and write a plan
#   do      execute the plan
#   check   review execution against the plan

REPO ?=
export PATH := $(CURDIR)/$(o)/bin:$(PATH)

# target repo clone
repo_dir := $(o)/repo
default_branch = $(shell git -C $(repo_dir) symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/||')

# --- pick ---

pick := $(o)/pick
issue := $(pick)/issue.json

.PHONY: pick
pick: $(issue)

$(issue): $(ah) $(cosmic)
	@echo "==> pick"
	@mkdir -p $(@D)
	@$(ah) -n \
		--must-produce $(issue) \
		--max-tokens 50000 \
		--db $(pick)/session.db \
		--tool "list_issues=skills/pick/tools/list-issues.tl" \
		--tool "bash=" \
		--skill pick \
		<<< "REPO=$(REPO)"

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

plan_dir := $(o)/plan
plan := $(plan_dir)/plan.md

.PHONY: plan
plan: $(plan)

$(plan): $(repo_sha) $(issue) $(ah)
	@echo "==> plan"
	@mkdir -p $(plan_dir)
	@$(ah) -n \
		--sandbox \
		--skill plan \
		--must-produce $(plan) \
		--max-tokens 100000 \
		--db $(plan_dir)/session.db \
		--unveil $(repo_dir):rwcx \
		--unveil $(plan_dir):rwc \
		--unveil .:r \
		< $(issue)

# --- do ---

do_dir := $(o)/do
do_done := $(do_dir)/do.md
feedback := $(do_dir)/feedback.md

.PHONY: do
do: $(do_done)

$(feedback): $(plan)
	@mkdir -p $(@D)
	@touch $@

$(do_done): $(repo_sha) $(plan) $(feedback) $(issue) $(ah)
	@echo "==> do"
	@mkdir -p $(do_dir)
	@$(ah) -n \
		--sandbox \
		--skill do \
		--must-produce $(do_done) \
		--max-tokens 200000 \
		--db $(do_dir)/session.db \
		--unveil $(repo_dir):rwcx \
		--unveil $(do_dir):rwc \
		--unveil $(plan_dir):r \
		--unveil .:r \
		< $(issue)

# --- push ---

push_done := $(o)/push/done

$(push_done): $(do_done)
	@echo "==> push"
	@mkdir -p $(@D)
	@git -C $(repo_dir) remote set-url origin https://x-access-token:$(GH_TOKEN)@github.com/$(REPO).git
	@git -C $(repo_dir) push --force-with-lease -u origin HEAD
	@touch $@

# --- check ---

check_dir := $(o)/check
check_done := $(check_dir)/check.md
actions := $(check_dir)/actions.json

.PHONY: check
check: $(check_done)

$(check_done): $(push_done) $(plan) $(issue) $(ah)
	@echo "==> check"
	@mkdir -p $(check_dir)
	@$(ah) -n \
		--sandbox \
		--skill check \
		--must-produce $(actions) \
		--max-tokens 100000 \
		--db $(check_dir)/session.db \
		--unveil $(repo_dir):rx \
		--unveil $(check_dir):rwc \
		--unveil $(do_dir):rwc \
		--unveil $(plan_dir):r \
		--unveil .:r \
		< $(issue)
