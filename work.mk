# work.mk: work targets
#
# implements the PDCA work loop as make targets:
#   unstick -> pick -> clone -> build -> plan -> do -> push -> check -> act
#
# unstick resets issues stuck in "doing" for >24h back to "todo" so the
# work loop can pick them up again. runs before pick as a deterministic script.
#
# pick prefers PRs with review feedback or failing CI checks over new issues.
# when a PR with CHANGES_REQUESTED or failing checks is found, pick selects
# it and the rest of the pipeline addresses the feedback. otherwise, pick
# selects a new issue.
#
# build runs `make ci` in the target repo after clone. this fetches build
# dependencies (cosmic, etc.) and produces build artifacts under o/repo/o/.
# sandboxed phases (plan, do, check) can then run `make ci` without network
# access since deps are already satisfied.
#
# convergence: check writes o/do/feedback.md when verdict is needs-fixes.
# since do depends on feedback.md, the next make run re-executes do -> push -> check.
# the caller runs `make work` which loops until convergence or a retry limit.

REPO ?=

export PATH := $(CURDIR)/$(o)/bin:$(PATH)
export WORK_REPO := $(REPO)

run_ah := lib/work/run-ah.sh

# target repo clone
repo_dir := $(o)/repo
default_branch = $(or $(shell git -C $(repo_dir) symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/||'),origin/main)

# named targets
unstick_dir := $(o)/unstick
unstick_done := $(unstick_dir)/unstick.json
pick_dir := $(o)/pick
issue := $(pick_dir)/issue.json
build_log := $(o)/build/log.txt
plan_dir := $(o)/plan
ci_log := $(plan_dir)/ci-log.txt
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

# --- unstick ---
# reset issues stuck in "doing" for >24h back to "todo".
# runs before pick so stale issues become available again.

$(unstick_done): $(cosmic)
	@mkdir -p $(unstick_dir)
	@echo "==> unstick"
	@$(cosmic) lib/work/unstick.tl $(unstick_done)

.PHONY: unstick
unstick: $(unstick_done)

# --- pick ---
# preflight (labels, pr-limit), check for PRs with feedback, fetch issues, pick one, mark doing

$(issue): $(unstick_done) $(ah) $(cosmic)
	@mkdir -p $(pick_dir)
	@echo "==> pick"
	@$(run_ah) 120 $(ah) -n \
		-m sonnet \
		--skill pick \
		--must-produce $(issue) \
		--max-tokens 50000 \
		--db $(pick_dir)/session.db \
		--tool "ensure_labels=skills/pick/tools/ensure-labels.tl" \
		--tool "get_prs_with_feedback=skills/pick/tools/get-prs-with-feedback.tl" \
		--tool "count_open_prs=skills/pick/tools/count-open-prs.tl" \
		--tool "list_issues=skills/pick/tools/list-issues.tl" \
		--tool "set_issue_labels=tools/set-issue-labels.tl" \
		--tool "bash=" \
		<<< ""

.PHONY: pick
pick: $(issue)

# --- clone ---

# work item type and branch from issue.json
item_type = $(shell jq -r '.type // "issue"' $(issue) 2>/dev/null)
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
	@if [ "$(item_type)" = "pr" ]; then \
		echo "==> checkout existing PR branch $(branch)"; \
		git -C $(repo_dir) checkout $(branch); \
		git -C $(repo_dir) pull origin $(branch); \
		git -C $(repo_dir) rev-parse HEAD > $(repo_dir)/remote-sha; \
		echo "==> rebase on $(default_branch)"; \
		git -C $(repo_dir) rebase $(default_branch) || { \
			echo "==> rebase conflict, aborting and resetting to $(default_branch)"; \
			git -C $(repo_dir) rebase --abort; \
			git -C $(repo_dir) reset --hard $(default_branch); \
		}; \
	else \
		echo "==> checkout new branch $(branch)"; \
		git -C $(repo_dir) checkout -B $(branch) $(default_branch); \
	fi
	@git -C $(repo_dir) rev-parse HEAD > $@

.PHONY: clone
clone: $(repo_ready)

# --- build ---
# run make ci in the target repo before entering sandbox. this fetches build
# dependencies and caches them under o/repo/o/. the output is recorded so
# plan/do/check can read it. failures are not fatal — the log is informational.

$(build_log): $(repo_ready)
	@mkdir -p $(@D)
	@echo "==> build"
	@cd $(repo_dir) && make ci >$(CURDIR)/$(build_log) 2>&1 && \
	 echo 0 > $(CURDIR)/$(build_log).exit || \
	 echo $$? > $(CURDIR)/$(build_log).exit
	@echo "  exit=$$(cat $(build_log).exit)"

.PHONY: build
build: $(build_log)

# --- ci-log ---

$(ci_log): $(build_log) $(repo_ready) $(issue) $(cosmic)
	@mkdir -p $(plan_dir)
	@if [ "$(item_type)" = "pr" ]; then \
		echo "==> ci-log"; \
		sha=$$(cat $(repo_dir)/remote-sha); \
		$(cosmic) skills/plan/lib/get-ci-log.tl "$$sha" $(ci_log); \
	else \
		touch $@; \
	fi

.PHONY: ci-log
ci-log: $(ci_log)

# --- plan ---

.PHONY: plan
plan: $(plan)

$(plan): $(ci_log) $(repo_ready) $(issue) $(ah)
	@echo "==> plan"
	@mkdir -p $(plan_dir)
	@$(run_ah) 300 $(ah) -n \
		-m sonnet \
		--sandbox \
		--skill plan \
		--must-produce $(plan) \
		--max-tokens 100000 \
		--db $(plan_dir)/session-$(LOOP).db \
		--unveil $(repo_dir):rx \
		--unveil $(plan_dir):rwc \
		--unveil $(o)/build:r \
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
	@if [ "$(item_type)" != "pr" ] && ! git -C $(repo_dir) diff --quiet $(default_branch)..HEAD 2>/dev/null; then \
		echo "  (retrying: resetting branch to $(default_branch))"; \
		git -C $(repo_dir) reset --hard $(default_branch); \
	fi
	@$(run_ah) 300 $(ah) -n \
		-m sonnet \
		--sandbox \
		--skill do \
		--must-produce $(do_dir)/do.md \
		--max-tokens 200000 \
		--db $(do_dir)/session-$(LOOP).db \
		--unveil $(repo_dir):rwcx \
		--unveil $(do_dir):rwc \
		--unveil $(plan_dir):r \
		--unveil $(o)/build:r \
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
	@$(run_ah) 420 $(ah) -n \
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
		--unveil $(o)/build:r \
		--unveil .:r \
		< $(issue)
	@touch $@

# --- act ---

$(act_done): $(check_done) $(issue) $(cosmic)
	@echo "==> act"
	@$(cosmic) lib/work/act.tl $(issue) $(actions) $(act_done)

# --- work: convergence loop ---

.PHONY: work
converge := $(MAKE) "REPO=$(REPO)" $(act_done)
work: $(issue)
	@error=$$(jq -r '.error // empty' $(issue)); \
	if [ "$$error" = "pr_limit" ] || [ "$$error" = "no_issues" ]; then \
		echo "==> skip: $$error"; \
		exit 0; \
	elif [ -n "$$error" ]; then \
		echo "==> error: $$error"; \
		exit 1; \
	fi; \
	$(MAKE) "REPO=$(REPO)" $(plan) || exit $$?; \
	LOOP=1 $(converge) || true; \
	LOOP=2 $(converge)

# --- triage ---
# standalone target: review open issues, close stale ones, split oversized ones.
# requires REPO and a cloned repo. not part of the main work chain.

triage_dir := $(o)/triage
triage_done := $(triage_dir)/triage.json

# triage needs the repo cloned and on the default branch.
# use a phony target to always ensure correct state.
triage_repo_ready := $(triage_dir)/.repo-ready

$(triage_repo_ready):
	@if [ ! -d $(repo_dir)/.git ]; then \
		echo "==> clone $(REPO)"; \
		gh repo clone $(REPO) $(repo_dir); \
	fi
	@echo "==> fetch and checkout default branch for triage"
	@git -C $(repo_dir) fetch origin
	@git -C $(repo_dir) checkout $(default_branch:origin/%=%)
	@git -C $(repo_dir) pull origin $(default_branch:origin/%=%)
	@mkdir -p $(triage_dir)
	@touch $@

.PHONY: triage
triage: $(triage_done)

$(triage_done): $(triage_repo_ready) $(ah) $(cosmic)
	@echo "==> triage"
	@mkdir -p $(triage_dir)
	@$(run_ah) 300 $(ah) -n \
		-m sonnet \
		--skill triage \
		--must-produce $(triage_done) \
		--max-tokens 100000 \
		--db $(triage_dir)/session.db \
		--tool "list_issues=skills/pick/tools/list-issues.tl" \
		--tool "ensure_labels=skills/pick/tools/ensure-labels.tl" \
		--tool "close_issue=skills/triage/tools/close-issue.tl" \
		--tool "create_issue=skills/triage/tools/create-issue.tl" \
		--tool "comment_issue=tools/comment-issue.tl" \
		--tool "set_issue_labels=tools/set-issue-labels.tl" \
		--tool "grep_repo=skills/triage/tools/grep-repo.tl" \
		--tool "bash=" \
		<<< ""

# --- docs ---
# standalone target: audit and update documentation files.
# requires REPO and a cloned repo. not part of the main work chain.

docs_dir := $(o)/docs
docs_done := $(docs_dir)/docs.md

# docs needs the repo cloned and on the default branch.
docs_repo_ready := $(docs_dir)/.repo-ready

$(docs_repo_ready):
	@if [ ! -d $(repo_dir)/.git ]; then \
		echo "==> clone $(REPO)"; \
		gh repo clone $(REPO) $(repo_dir); \
	fi
	@echo "==> fetch and checkout default branch for docs"
	@git -C $(repo_dir) fetch origin
	@git -C $(repo_dir) checkout $(default_branch:origin/%=%)
	@git -C $(repo_dir) pull origin $(default_branch:origin/%=%)
	@mkdir -p $(docs_dir)
	@touch $@

.PHONY: docs
docs: $(docs_done)

$(docs_done): $(docs_repo_ready) $(ah)
	@echo "==> docs"
	@mkdir -p $(docs_dir)
	@$(run_ah) 300 $(ah) -n \
		-m sonnet \
		--sandbox \
		--skill docs \
		--must-produce $(docs_done) \
		--max-tokens 100000 \
		--db $(docs_dir)/session.db \
		--unveil $(repo_dir):rwc \
		--unveil $(docs_dir):rwc \
		--unveil .:r \
		<<< ""

# --- tests ---
# standalone target: audit and improve tests.
# requires REPO and a cloned repo. not part of the main work chain.

tests_dir := $(o)/tests
tests_done := $(tests_dir)/tests.json

# tests needs the repo cloned and on the default branch.
tests_repo_ready := $(tests_dir)/.repo-ready

$(tests_repo_ready):
	@if [ ! -d $(repo_dir)/.git ]; then \
		echo "==> clone $(REPO)"; \
		gh repo clone $(REPO) $(repo_dir); \
	fi
	@echo "==> fetch and checkout default branch for tests"
	@git -C $(repo_dir) fetch origin
	@git -C $(repo_dir) checkout $(default_branch:origin/%=%)
	@git -C $(repo_dir) pull origin $(default_branch:origin/%=%)
	@mkdir -p $(tests_dir)
	@touch $@

.PHONY: tests
tests: $(tests_done)

$(tests_done): $(tests_repo_ready) $(ah)
	@echo "==> tests"
	@mkdir -p $(tests_dir)
	@$(run_ah) 300 $(ah) -n \
		-m sonnet \
		--sandbox \
		--skill tests \
		--must-produce $(tests_done) \
		--max-tokens 100000 \
		--db $(tests_dir)/session.db \
		--unveil $(repo_dir):rwcx \
		--unveil $(tests_dir):rwc \
		--unveil .:r \
		<<< ""

# --- bump ---
# standalone target: check for new releases of ah and cosmic, update deps.
# always targets whilp/working. not part of the main work chain.

bump_dir := $(o)/bump
bump_done := $(bump_dir)/bump.json

# bump needs the repo cloned and on the default branch.
bump_repo_ready := $(bump_dir)/.repo-ready

$(bump_repo_ready):
	@if [ ! -d $(repo_dir)/.git ]; then \
		echo "==> clone $(REPO)"; \
		gh repo clone $(REPO) $(repo_dir); \
	fi
	@echo "==> fetch and checkout default branch for bump"
	@git -C $(repo_dir) fetch origin
	@git -C $(repo_dir) checkout $(default_branch:origin/%=%)
	@git -C $(repo_dir) pull origin $(default_branch:origin/%=%)
	@mkdir -p $(bump_dir)
	@touch $@

.PHONY: bump
bump: $(bump_done)

bump_branch := bump/$(shell date -u +%Y-%m-%d)

$(bump_done): $(bump_repo_ready) $(ah) $(cosmic)
	@echo "==> bump"
	@mkdir -p $(bump_dir)
	@git -C $(repo_dir) checkout -B $(bump_branch)
	@$(run_ah) 120 $(ah) -n \
		-m sonnet \
		--sandbox \
		--skill bump \
		--must-produce $(bump_done) \
		--max-tokens 50000 \
		--db $(bump_dir)/session.db \
		--unveil $(repo_dir):rwc \
		--unveil $(bump_dir):rwc \
		--unveil .:r \
		--tool "get_latest_release=skills/bump/tools/get-latest-release.tl" \
		--tool "update_dep=skills/bump/tools/update-dep.tl" \
		--tool "bash=" \
		<<< ""
	@if git -C $(repo_dir) diff --quiet HEAD; then \
		echo "==> bump: no changes"; \
	else \
		echo "==> bump: pushing changes"; \
		git -C $(repo_dir) remote set-url origin https://x-access-token:$$GH_TOKEN@github.com/$(REPO).git; \
		git -C $(repo_dir) push --force-with-lease -u origin $(bump_branch); \
		gh pr create --repo $(REPO) --head $(bump_branch) --title "bump: update dependencies" --body "automated dependency update" || true; \
	fi
