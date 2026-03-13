# autowork.mk: autowork loop targets
#
# implements the autowork loop for autonomously improving ah:
#   baseline -> propose -> apply -> eval -> decide
#
# baseline: run eval suite on current ah, record initial score.
# propose: agent proposes a single focused change to ah.
# apply: apply changes to a fresh checkout, gate on make ci.
# eval: run ah on each eval task, judge results, aggregate.
# decide: compare to best score, keep or discard.
#
# the eval harness (eval/tasks, eval/judge.md) is immutable — changes
# to it require human review.

AH_REPO ?= whilp/ah

export PATH := $(CURDIR)/$(o)/bin:$(PATH)

# directories
autowork_dir := $(o)/autowork
propose_dir := $(autowork_dir)/propose
eval_results_dir := $(autowork_dir)/eval
decide_dir := $(autowork_dir)/decide
ah_repo_dir := $(autowork_dir)/repo

# named targets
eval_summary := $(eval_results_dir)/summary.json
proposal := $(propose_dir)/proposal.md
apply_done := $(autowork_dir)/apply-done
eval_done := $(eval_results_dir)/done
decision := $(decide_dir)/decision.json
results_log := $(autowork_dir)/results.tsv

# eval task set
eval_task_dirs := $(wildcard eval/tasks/*/prompt.md)

# --- clone ah ---

ah_repo_ready := $(ah_repo_dir)/sha

$(ah_repo_ready):
	@if [ ! -d $(ah_repo_dir)/.git ]; then \
		echo "==> autowork: clone $(AH_REPO)"; \
		gh repo clone $(AH_REPO) $(ah_repo_dir); \
	fi
	@git -C $(ah_repo_dir) fetch origin
	@git -C $(ah_repo_dir) checkout main
	@git -C $(ah_repo_dir) pull origin main
	@git -C $(ah_repo_dir) rev-parse HEAD > $@

# --- eval ---
# run the eval suite: for each task, run ah then judge, then aggregate.
# tasks live in eval/tasks/<name>/. each has prompt.md, expect.md,
# and optionally repo.bundle and config.json.

$(eval_done): $(ah_repo_ready) $(ah) $(cosmic)
	@echo "==> autowork: eval"
	@mkdir -p $(eval_results_dir)
	@if [ -z "$(eval_task_dirs)" ]; then \
		echo "  no eval tasks found in eval/tasks/"; \
		echo '{"pass_rate":0,"mean_quality":0,"mean_composite":0,"task_count":0}' > $(eval_summary); \
	else \
		for task_prompt in $(eval_task_dirs); do \
			task_dir=$$(dirname $$task_prompt); \
			task_name=$$(basename $$task_dir); \
			result_dir=$(eval_results_dir)/results/$$task_name; \
			echo "  task: $$task_name"; \
			$(cosmic) lib/eval/run-task.tl $$task_dir $(ah) $$result_dir || true; \
			$(cosmic) lib/eval/judge-task.tl $$task_dir $$result_dir $(ah) $$result_dir/score.json || true; \
		done; \
		$(cosmic) lib/eval/aggregate.tl $(eval_results_dir)/results $(eval_summary); \
	fi
	@touch $@

.PHONY: eval
eval: $(eval_done)

# --- baseline ---
# run eval on unmodified ah and record the baseline score.

baseline_done := $(autowork_dir)/baseline-done

$(baseline_done): $(eval_done) $(cosmic)
	@echo "==> autowork: baseline"
	@commit=$$(cat $(ah_repo_dir)/sha | head -c 7); \
	if [ -f $(eval_summary) ]; then \
		composite=$$(jq -r '.mean_composite // 0' $(eval_summary)); \
		pass_rate=$$(jq -r '.pass_rate // 0' $(eval_summary)); \
		mean_quality=$$(jq -r '.mean_quality // 0' $(eval_summary)); \
		mean_tokens=$$(jq -r '.mean_tokens // 0' $(eval_summary)); \
		echo "  baseline: composite=$$composite pass_rate=$$pass_rate"; \
		printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
			"$$commit" "$$composite" "$$pass_rate" "$$mean_quality" "$$mean_tokens" "baseline" "current ah main" \
			>> $(results_log); \
	fi
	@touch $@

.PHONY: baseline
baseline: $(baseline_done)

# --- propose ---
# agent proposes a single focused change to ah.

autowork_branch := autowork/$(shell date -u +%Y-%m-%d-%H%M)

$(proposal): $(baseline_done) $(ah)
	@echo "==> autowork: propose"
	@mkdir -p $(propose_dir)
	@git -C $(ah_repo_dir) checkout -B $(autowork_branch)
	@$(run_ah) 300 $(ah) -n \
		-m sonnet \
		--skill autowork \
		--must-produce $(proposal) \
		--max-tokens 100000 \
		--db $(propose_dir)/session.db \
		--tool "get_eval_results=skills/autowork/tools/get-eval-results.tl" \
		--tool "bash=" \
		--unveil $(ah_repo_dir):rwcx \
		--unveil $(propose_dir):rwc \
		--unveil $(eval_results_dir):r \
		--unveil $(autowork_dir):r \
		--unveil .:r \
		<<< ""

.PHONY: propose
propose: $(proposal)

# --- apply ---
# validate proposed changes pass make ci.

$(apply_done): $(proposal)
	@echo "==> autowork: apply"
	@if git -C $(ah_repo_dir) diff --quiet HEAD; then \
		echo "  no changes proposed, skipping"; \
		exit 1; \
	fi
	@echo "  running make ci in modified ah"
	@cd $(ah_repo_dir) && make ci
	@touch $@

.PHONY: apply
apply: $(apply_done)

# --- decide ---
# compare eval score to baseline and keep or discard.

$(decision): $(apply_done) $(cosmic)
	@echo "==> autowork: decide"
	@mkdir -p $(decide_dir)
	@echo "  re-evaluating with proposed changes"
	@rm -f $(eval_done)
	@$(MAKE) $(eval_done)
	@if [ -f $(eval_summary) ]; then \
		new_composite=$$(jq -r '.mean_composite // 0' $(eval_summary)); \
		best_composite=$$(tail -1 $(results_log) | cut -f2); \
		echo "  new=$$new_composite best=$$best_composite"; \
		diff_lines=$$(git -C $(ah_repo_dir) diff main --stat | tail -1 | grep -oP '\d+ insertion|d+ deletion' | head -1 || echo "0"); \
		commit=$$(git -C $(ah_repo_dir) rev-parse --short HEAD); \
		desc=$$(head -1 $(proposal) | sed 's/^# //'); \
		$(cosmic) lib/eval/decide-experiment.tl \
			"$$new_composite" "$$best_composite" "$$diff_lines" \
			"$$commit" "$$desc" \
			$(results_log) $(decision); \
	fi

.PHONY: decide
decide: $(decision)

# --- autowork: full loop ---

.PHONY: autowork
autowork: $(decision)
	@verdict=$$(jq -r '.verdict // "unknown"' $(decision) 2>/dev/null || echo "unknown"); \
	echo "==> autowork: $$verdict"; \
	if [ "$$verdict" = "keep" ]; then \
		echo "  pushing to $(autowork_branch)"; \
		git -C $(ah_repo_dir) remote set-url origin https://x-access-token:$$GH_TOKEN@github.com/$(AH_REPO).git; \
		git -C $(ah_repo_dir) push --force-with-lease -u origin $(autowork_branch); \
	else \
		echo "  discarding changes"; \
		git -C $(ah_repo_dir) checkout main; \
		git -C $(ah_repo_dir) branch -D $(autowork_branch) 2>/dev/null || true; \
	fi
