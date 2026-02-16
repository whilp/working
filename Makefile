.SECONDARY:
SHELL := /bin/bash
.SHELLFLAGS := -o pipefail -ec
.DEFAULT_GOAL := help

MAKEFLAGS += --no-print-directory
MAKEFLAGS += --no-builtin-rules
MAKEFLAGS += --no-builtin-variables
MAKEFLAGS += --output-sync
export COSMIC_NO_WELCOME = 1

o := o

TMP ?= /tmp
export TMPDIR := $(TMP)

# cosmic dependency
cosmic_version := 2026-02-14-1ae054b
cosmic_url := https://github.com/whilp/cosmic/releases/download/$(cosmic_version)/cosmic-lua
cosmic_sha := cbac27fdbd8798b59715624ce897bf4775954efb077962bb94817f2458f976ba
cosmic := $(o)/bin/cosmic

.PHONY: cosmic
cosmic: $(cosmic)
$(cosmic):
	@mkdir -p $(@D)
	@echo "==> fetching cosmic $(cosmic_version)"
	@curl -fsSL -o $@ $(cosmic_url)
	@echo "$(cosmic_sha)  $@" | sha256sum -c - >/dev/null
	@chmod +x $@

# ah dependency
ah_version := 2026-02-16-9361ef4
ah_url := https://github.com/whilp/ah/releases/download/$(ah_version)/ah
ah_sha := 7e3e11ef9b5225d005c4d76a1ca9f7e440400f4da87d1a0d2f929c30314059dd
ah := $(o)/bin/ah

.PHONY: ah
ah: $(ah)
$(ah):
	@mkdir -p $(@D)
	@echo "==> fetching ah $(ah_version)"
	@curl -fsSL -o $@ $(ah_url)
	@echo "$(ah_sha)  $@" | sha256sum -c - >/dev/null
	@chmod +x $@

.PHONY: help
help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  work                Run full work loop (pick -> plan -> do -> check -> act)"
	@echo "  pick                Pick an issue (REPO=owner/repo)"
	@echo "  clone               Clone repo and checkout work branch"
	@echo "  plan                Research codebase and write a plan"
	@echo "  do                  Execute the plan"
	@echo "  check               Review execution and render verdict"
	@echo "  clean               Remove all build artifacts"

include work.mk

.PHONY: clean
clean:
	@rm -rf $(o)
