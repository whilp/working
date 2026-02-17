# reflect.mk: reflection targets
#
# implements the reflect loop as make targets:
#   fetch -> analyze (per-run) -> summarize -> publish
#
# fetch: download workflow run logs and artifacts for a date range.
# analyze: one sandboxed agent per run, producing a short analysis.
# summarize: one sandboxed agent reads all analyses, produces reflection.md.
# publish: commit reflection.md to note/YYYY-MM-DD/ and open a PR.
#
# all runs come from whilp/working (this repo).

REFLECT_REPO := whilp/working

export PATH := $(CURDIR)/$(o)/bin:$(PATH)

# date range: default to yesterday
DATE ?= $(shell date -u -d 'yesterday' +%Y-%m-%d 2>/dev/null || date -u -v-1d +%Y-%m-%d)
SINCE ?= $(DATE)
UNTIL ?= $(DATE)

# branch for publishing
reflect_branch := reflect/$(DATE)

# directories
fetch_dir := $(o)/reflect/fetch
analyze_dir := $(o)/reflect/analyze
summarize_dir := $(o)/reflect/summarize
publish_repo := $(o)/reflect/repo

# named targets
fetch_done := $(fetch_dir)/fetch-done
reflection := $(summarize_dir)/reflection.md
publish_done := $(o)/reflect/publish-done

.DELETE_ON_ERROR:

# --- fetch ---

$(fetch_done): $(ah) $(cosmic)
	@mkdir -p $(fetch_dir)
	@echo "==> reflect: fetch runs $(SINCE)..$(UNTIL)"
	# WORK_REPO is set inline, not globally — a global export would clobber
	# work.mk's WORK_REPO := $(REPO) since reflect.mk is included second.
	@WORK_REPO=$(REFLECT_REPO) timeout 300 $(ah) -n \
		-m sonnet \
		--skill reflect \
		--must-produce $(fetch_done) \
		--max-tokens 50000 \
		--db $(fetch_dir)/session.db \
		--tool "get_workflow_runs=skills/reflect/tools/get-workflow-runs.tl" \
		--tool "bash=" \
		<<< "PHASE=fetch SINCE=$(SINCE) UNTIL=$(UNTIL) OUTPUT_DIR=$(fetch_dir)"

.PHONY: fetch
fetch: $(fetch_done)

# --- analyze: one agent per run ---
# after fetch, read manifest.json and launch a sandboxed agent for each run.
# each produces analyze_dir/<run-id>.md.

analyze_done := $(analyze_dir)/done

$(analyze_done): $(fetch_done) $(ah) $(cosmic)
	@mkdir -p $(analyze_dir)
	@echo "==> reflect: analyze runs"
	@$(cosmic) skills/reflect/tools/analyze-runs.tl $(fetch_dir) $(analyze_dir) $(ah) || true
	@touch $@

.PHONY: analyze
analyze: $(analyze_done)

# --- summarize ---

$(reflection): $(analyze_done) $(ah)
	@mkdir -p $(summarize_dir)
	@echo "==> reflect: summarize"
	@timeout 120 $(ah) -n \
		-m sonnet \
		--sandbox \
		--skill reflect \
		--must-produce $(reflection) \
		--max-tokens 50000 \
		--db $(summarize_dir)/session.db \
		--unveil $(analyze_dir):r \
		--unveil $(summarize_dir):rwc \
		--unveil .:r \
		<<< "PHASE=summarize ANALYSIS_DIR=$(analyze_dir) DATE=$(DATE) OUTPUT_FILE=$(reflection)"

.PHONY: summarize
summarize: $(reflection)

# --- publish ---

$(publish_done): $(reflection)
	@echo "==> reflect: publish"
	@test -n "$(GH_TOKEN)" || { echo "error: GH_TOKEN not set"; exit 1; }
	@if [ ! -d $(publish_repo)/.git ]; then \
		echo "  cloning $(REFLECT_REPO)"; \
		gh repo clone $(REFLECT_REPO) $(publish_repo); \
	fi
	@git -C $(publish_repo) fetch origin
	@git -C $(publish_repo) checkout -B $(reflect_branch) origin/main
	@mkdir -p $(publish_repo)/note/$(DATE)
	@cp $(reflection) $(publish_repo)/note/$(DATE)/reflection.md
	@git -C $(publish_repo) add note/$(DATE)/reflection.md
	@git -C $(publish_repo) commit -m "reflect: add $(DATE) reflection"
	@git -C $(publish_repo) remote set-url origin https://x-access-token:$(GH_TOKEN)@github.com/$(REFLECT_REPO).git
	@git -C $(publish_repo) push --force-with-lease -u origin $(reflect_branch)
	@gh pr create \
		--repo $(REFLECT_REPO) \
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
