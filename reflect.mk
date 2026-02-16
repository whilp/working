# reflect.mk: reflection targets
#
# implements the reflect loop as make targets:
#   fetch -> analyze -> publish
#
# fetch: download workflow run logs and artifacts for a date range.
# analyze: sandboxed analysis producing reflection.md.
# publish: place reflection.md in note/YYYY-MM-DD/ and open a PR.
#
# all runs come from whilp/working (this repo). no matrix needed.

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

# named targets
fetch_done := $(fetch_dir)/fetch-done
reflection := $(analyze_dir)/reflection.md
publish_done := $(o)/reflect/publish-done

.DELETE_ON_ERROR:

# --- fetch ---

$(fetch_done): $(ah) $(cosmic)
	@mkdir -p $(fetch_dir)
	@echo "==> reflect: fetch runs $(SINCE)..$(UNTIL)"
	@timeout 120 $(ah) -n \
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

# --- analyze ---

$(reflection): $(fetch_done) $(ah)
	@mkdir -p $(analyze_dir)
	@echo "==> reflect: analyze"
	@timeout 180 $(ah) -n \
		-m opus \
		--sandbox \
		--skill reflect \
		--must-produce $(reflection) \
		--max-tokens 100000 \
		--db $(analyze_dir)/session.db \
		--unveil $(fetch_dir):r \
		--unveil $(analyze_dir):rwc \
		--unveil .:r \
		<<< "PHASE=analyze FETCH_DIR=$(fetch_dir) OUTPUT_DIR=$(analyze_dir)"

.PHONY: analyze
analyze: $(reflection)

# --- publish ---

$(publish_done): $(reflection)
	@echo "==> reflect: publish"
	@test -n "$(GH_TOKEN)" || { echo "error: GH_TOKEN not set"; exit 1; }
	@git checkout -B $(reflect_branch)
	@mkdir -p note/$(DATE)
	@cp $(reflection) note/$(DATE)/reflection.md
	@git add note/$(DATE)/reflection.md
	@git commit -m "reflect: add $(DATE) reflection"
	@git remote set-url origin https://x-access-token:$(GH_TOKEN)@github.com/$(REFLECT_REPO).git
	@git push --force-with-lease -u origin $(reflect_branch)
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
