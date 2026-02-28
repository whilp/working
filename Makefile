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

# dependencies
include deps/cosmic.mk
include deps/ah.mk

cosmic := $(o)/bin/cosmic

$(cosmic): deps/cosmic.mk
	@rm -f $@
	@mkdir -p $(@D)
	@echo "==> fetching $(cosmic_url)"
	@curl -fsSL -o $@ $(cosmic_url)
	@echo "$(cosmic_sha)  $@" | sha256sum -c - >/dev/null
	@chmod +x $@

ah := $(o)/bin/ah
ah_raw := $(o)/bin/.ah-raw

$(ah_raw): deps/ah.mk
	@rm -f $@
	@mkdir -p $(@D)
	@echo "==> fetching $(ah_url)"
	@curl -fsSL -o $@ $(ah_url)
	@echo "$(ah_sha)  $@" | sha256sum -c - >/dev/null
	@chmod +x $@

embed/env.d/20-claude:
ifdef CI
	@touch $@
else ifdef CLAUDE_CODE_OAUTH_TOKEN
	@echo "CLAUDE_CODE_OAUTH_TOKEN=$(CLAUDE_CODE_OAUTH_TOKEN)" > $@
else
	@echo "error: $@ not found — create it with your env vars" >&2; exit 1
endif

$(ah): $(ah_raw) embed/env.d/20-claude
	@echo "==> embedding env.d into ah"
	@$(ah_raw) -o $@ embed embed

.PHONY: ah cosmic
ah: $(ah)
cosmic: $(cosmic)

# sources
tl_all := $(wildcard tools/*.tl) $(wildcard skills/*/tools/*.tl) $(wildcard skills/*/lib/*.tl) $(wildcard lib/*/*.tl)
tl_tests := $(wildcard test/tools/test_*.tl) $(wildcard skills/*/tests/test_*.tl) $(wildcard lib/*/test_*.tl)
tl_srcs := $(filter-out $(tl_tests),$(tl_all))

TL_PATH := /zip/.tl/?.tl;/zip/.tl/?/init.tl;/zip/.lua/types/?.d.tl;/zip/.lua/types/?/init.d.tl
TL_PATH_TEST := ?.tl;?/init.tl;$(TL_PATH)

# type checking
all_type_checks := $(patsubst %,$(o)/%.types,$(tl_srcs))

$(o)/%.tl.types: %.tl $(cosmic)
	@mkdir -p $(@D)
	-@TL_PATH='$(TL_PATH)' $(cosmic) --test $@ $(cosmic) --check-types $<

.PHONY: check-types
check-types: $(all_type_checks)
	@$(cosmic) --report $(all_type_checks)

# format checking
all_fmt_checks := $(patsubst %,$(o)/%.fmt,$(tl_srcs))

$(o)/%.tl.fmt: %.tl $(cosmic)
	@mkdir -p $(@D)
	-@$(cosmic) --test $@ diff -u $< <($(cosmic) --format $<)

.PHONY: check-format
check-format: $(all_fmt_checks)
	@$(cosmic) --report $(all_fmt_checks)

# length checking (file length ratchet)
all_files := $(shell git ls-files | while read f; do [ -f "$$f" ] && echo "$$f"; done)
all_length_checks := $(patsubst %,$(o)/%.lint,$(all_files))

$(o)/%.lint: % lib/build/lint.tl $(cosmic)
	@mkdir -p $(@D)
	-@$(cosmic) --test $@ $(cosmic) lib/build/lint.tl $<

.PHONY: check-length
check-length: $(all_length_checks)
	@$(cosmic) --report $(all_length_checks)

# ci: type checks + format checks + length checks + tests
.PHONY: ci
ci: check-types check-format check-length test

# tests
all_test_results := $(patsubst %.tl,$(o)/%.test,$(tl_tests))

$(o)/%.test: %.tl $(cosmic)
	@mkdir -p $(@D)
	@TL_PATH='$(TL_PATH_TEST)' WORK_REPO= $(cosmic) --test $@ $(cosmic) $<

.PHONY: test
test: $(all_test_results)
	@$(cosmic) --report $(all_test_results)

.PHONY: help
help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  ci                  Run type checks, format checks, and tests"
	@echo "  test                Run tests"
	@echo "  check-types         Run teal type checker on all .tl files"
	@echo "  check-format        Check formatting on all .tl files"
	@echo "  check-length        File length lint check (500-line default)"
	@echo "  work                Run full work loop (pick -> plan -> do -> check -> act)"
	@echo "  unstick             Reset stale doing issues to todo (REPO=owner/repo)"
	@echo "  pick                Pick a work item: PR with feedback or issue (REPO=owner/repo)"
	@echo "  clone               Clone repo and checkout work branch"
	@echo "  plan                Research codebase and write a plan"
	@echo "  do                  Execute the plan"
	@echo "  check               Review execution and render verdict"
	@echo "  triage              Review open issues and close stale ones (REPO=owner/repo)"
	@echo "  docs                Audit and update documentation files (REPO=owner/repo)"
	@echo "  tests               Audit and improve tests (REPO=owner/repo)"
	@echo "  bump                Check for dependency updates and open PR (REPO=owner/repo)"
	@echo "  reflect             Run reflect loop (fetch -> analyze -> publish)"
	@echo "  fetch               Fetch workflow run logs and artifacts"
	@echo "  analyze             Analyze fetched data into reflection.md"
	@echo "  publish             Commit reflection.md and open PR"
	@echo "  ah                  Fetch ah binary"
	@echo "  cosmic              Fetch cosmic binary"
	@echo "  clean               Remove all build artifacts"

include work.mk
include reflect.mk

.PHONY: clean
clean:
	@rm -rf $(o)
