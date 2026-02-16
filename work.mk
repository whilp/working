# work.mk: work targets
#
# usage: REPO=owner/repo make pick
#
# phases:
#   pick    select an issue to work on

REPO ?=
export PATH := $(CURDIR)/$(o)/bin:$(PATH)

# --- pick ---

pick := $(o)/pick
issue := $(pick)/issue.json

.PHONY: pick
pick: $(issue)

$(issue): $(ah) $(cosmic)
	@echo "==> pick"
	@mkdir -p $(@D)
	@REPO=$(REPO) $(ah) -n \
		--skill pick \
		--must-produce $(issue) \
		--max-tokens 50000 \
		--db $(pick)/session.db \
		-t "list_issues=skills/pick/tools/list-issues.tl" \
		-t "bash="
