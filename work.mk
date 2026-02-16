# work.mk: work targets
#
# usage: REPO=owner/repo make pick
#
# phases:
#   pick    select an issue to work on
#   clone   clone target repo and check out work branch
#   plan    research the codebase and write a plan

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
