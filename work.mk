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
abs_repo := $(CURDIR)/$(repo_dir)
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

plan_skill := skills/plan/SKILL.md

.PHONY: plan
plan: $(plan)

$(plan): $(repo_sha) $(issue) $(ah)
	@echo "==> plan"
	@mkdir -p $(plan_dir)
	@cd $(repo_dir) && $(CURDIR)/$(ah) -n \
		--sandbox \
		--must-produce $(abs_repo)/plan.md \
		--max-tokens 100000 \
		--db $(CURDIR)/$(plan_dir)/session.db \
		--unveil $(abs_repo):rwc \
		<<< "$$(cat $(CURDIR)/$(plan_skill))"$$'\n---\n'"$$(cat $(CURDIR)/$(issue))"
	@mv $(repo_dir)/plan.md $@
