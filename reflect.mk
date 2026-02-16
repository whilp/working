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

# named targets
fetch_done := $(fetch_dir)/fetch-done
reflection := $(summarize_dir)/reflection.md
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

# --- analyze: one agent per run ---
# after fetch, read manifest.json and launch a sandboxed agent for each run.
# each produces analyze_dir/<run-id>.md.

analyze_done := $(analyze_dir)/done

$(analyze_done): $(fetch_done) $(ah)
	@mkdir -p $(analyze_dir)
	@echo "==> reflect: analyze runs"
	@python3 -c "\
	import json, subprocess, sys, os; \
	manifest = json.load(open('$(fetch_dir)/manifest.json')); \
	runs = [r for r in manifest if r.get('log_file')]; \
	print(f'  {len(runs)} runs to analyze'); \
	failed = 0; \
	for r in runs: \
	    rid = str(r['databaseId']); \
	    out = '$(analyze_dir)/' + rid + '.md'; \
	    run_dir = '$(fetch_dir)/' + rid; \
	    meta = json.dumps(r); \
	    stdin = f'PHASE=analyze-run RUN_DIR={run_dir} RUN_META={meta} OUTPUT_FILE={out}'; \
	    print(f'  -> {rid}: {r.get(\"workflowName\",\"?\")} ({r.get(\"conclusion\",\"?\")})'); \
	    ret = subprocess.run([ \
	        '$(ah)', '-n', '-m', 'sonnet', \
	        '--sandbox', \
	        '--skill', 'reflect', \
	        '--must-produce', out, \
	        '--max-tokens', '30000', \
	        '--db', '$(analyze_dir)/session-' + rid + '.db', \
	        '--unveil', run_dir + ':r', \
	        '--unveil', '$(analyze_dir):rwc', \
	        '--unveil', '.:r', \
	    ], input=stdin.encode(), timeout=120); \
	    if ret.returncode != 0: \
	        print(f'  !! {rid} failed (exit {ret.returncode})'); \
	        failed += 1; \
	print(f'  done: {len(runs) - failed}/{len(runs)} succeeded'); \
	" || true
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
	@git checkout -B $(reflect_branch)
	@mkdir -p note/$(DATE)
	@cp $(reflection) note/$(DATE)/reflection.md
	@git add note/$(DATE)/reflection.md
	@git commit -m "reflect: add $(DATE) reflection"
	@git config --unset-all http.https://github.com/.extraheader || true
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
