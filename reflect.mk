# reflect.mk: reflection targets
#
# implements the reflect loop as make targets:
#   fetch -> analyze -> publish
#
# fetch: download workflow run logs and artifacts for a date range.
# analyze: sandboxed analysis producing reflection.md.
# publish: commit reflection.md to note/YYYY-MM-DD/ and open a PR.

REPO ?=

export PATH := $(CURDIR)/$(o)/bin:$(PATH)

# date range: default to yesterday
DATE ?= $(shell date -u -d 'yesterday' +%Y-%m-%d 2>/dev/null || date -u -v-1d +%Y-%m-%d)
SINCE ?= $(DATE)
UNTIL ?= $(DATE)

# target repo clone
reflect_repo_dir := $(o)/reflect/repo
reflect_default_branch = $(or $(shell git -C $(reflect_repo_dir) symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/||'),origin/main)
reflect_branch := reflect/$(DATE)

# directories
fetch_dir := $(o)/reflect/fetch
analyze_dir := $(o)/reflect/analyze
publish_dir := $(o)/reflect/publish

# named targets
fetch_done := $(fetch_dir)/fetch-done
reflection := $(analyze_dir)/reflection.md
publish_done := $(publish_dir)/done

.DELETE_ON_ERROR:

# --- clone ---

reflect_repo_ready := $(reflect_repo_dir)/sha

$(reflect_repo_ready): $(ah)
	@if [ ! -d $(reflect_repo_dir)/.git ]; then \
		echo "==> reflect: clone $(REPO)"; \
		gh repo clone $(REPO) $(reflect_repo_dir); \
	fi
	@echo "==> reflect: fetch"
	@git -C $(reflect_repo_dir) fetch origin
	@echo "==> reflect: checkout $(reflect_branch)"
	@git -C $(reflect_repo_dir) checkout -B $(reflect_branch) $(reflect_default_branch)
	@git -C $(reflect_repo_dir) rev-parse HEAD > $@

# --- fetch ---

$(fetch_done): $(ah) $(cosmic)
	@mkdir -p $(fetch_dir)
	@echo "==> reflect: fetch runs $(SINCE)..$(UNTIL)"
	@timeout 120 $(ah) -n \
		-m sonnet \
		--skill reflect-fetch \
		--must-produce $(fetch_done) \
		--max-tokens 50000 \
		--db $(fetch_dir)/session.db \
		--tool "list_workflow_runs=skills/reflect/tools/list-workflow-runs.tl" \
		--tool "bash=" \
		<<< "REPO=$(REPO) SINCE=$(SINCE) UNTIL=$(UNTIL) OUTPUT_DIR=$(fetch_dir)"

.PHONY: fetch
fetch: $(fetch_done)

# --- analyze ---

$(reflection): $(fetch_done) $(ah)
	@mkdir -p $(analyze_dir)
	@echo "==> reflect: analyze"
	@timeout 180 $(ah) -n \
		-m opus \
		--sandbox \
		--skill reflect-analyze \
		--must-produce $(reflection) \
		--max-tokens 100000 \
		--db $(analyze_dir)/session.db \
		--unveil $(fetch_dir):r \
		--unveil $(analyze_dir):rwc \
		--unveil .:r \
		<<< "REPO=$(REPO) FETCH_DIR=$(fetch_dir) OUTPUT_DIR=$(analyze_dir)"

.PHONY: analyze
analyze: $(reflection)

# --- publish ---

$(publish_done): $(reflection) $(reflect_repo_ready) $(ah)
	@mkdir -p $(publish_dir)
	@echo "==> reflect: publish"
	@timeout 60 $(ah) -n \
		-m sonnet \
		--sandbox \
		--skill reflect-publish \
		--must-produce $(publish_done) \
		--max-tokens 20000 \
		--db $(publish_dir)/session.db \
		--unveil $(reflect_repo_dir):rwcx \
		--unveil $(analyze_dir):r \
		--unveil $(publish_dir):rwc \
		--unveil .:r \
		<<< "REPO=$(REPO) REFLECTION_FILE=$(reflection) DATE=$(DATE) REPO_DIR=$(reflect_repo_dir)"
	@echo "==> reflect: push"
	@test -n "$(GH_TOKEN)" || { echo "error: GH_TOKEN not set"; exit 1; }
	@git -C $(reflect_repo_dir) remote set-url origin https://x-access-token:$(GH_TOKEN)@github.com/$(REPO).git
	@git -C $(reflect_repo_dir) push --force-with-lease -u origin HEAD
	@echo "==> reflect: create pr"
	@gh pr create \
		--repo $(REPO) \
		--head $(reflect_branch) \
		--title "reflect: $(DATE)" \
		--body "Daily reflection for $(DATE)." \
		2>&1 || true
	@touch $@

.PHONY: publish
publish: $(publish_done)

# --- reflect: full pipeline ---

.PHONY: reflect
reflect: $(publish_done)
