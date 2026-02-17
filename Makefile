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
cosmic := $(o)/bin/cosmic
cosmic_stamp := $(o)/stamps/cosmic

.PHONY: cosmic
cosmic: $(cosmic)
$(cosmic): $(cosmic_stamp)
$(cosmic_stamp): deps/cosmic.url deps/cosmic.sha256
	@rm -f $(cosmic)
	@mkdir -p $(@D) $(dir $(cosmic))
	@echo "==> fetching cosmic $$(cat deps/cosmic.url)"
	@curl -fsSL -o $(cosmic) $$(cat deps/cosmic.url)
	@echo "$$(cat deps/cosmic.sha256)  $(cosmic)" | sha256sum -c - >/dev/null
	@chmod +x $(cosmic)
	@echo $$(cat deps/cosmic.url) > $@

# ah dependency
ah := $(o)/bin/ah
ah_stamp := $(o)/stamps/ah

.PHONY: ah
ah: $(ah)
$(ah): $(ah_stamp)
$(ah_stamp): deps/ah.url deps/ah.sha256
	@rm -f $(ah)
	@mkdir -p $(@D) $(dir $(ah))
	@echo "==> fetching ah $$(cat deps/ah.url)"
	@curl -fsSL -o $(ah) $$(cat deps/ah.url)
	@echo "$$(cat deps/ah.sha256)  $(ah)" | sha256sum -c - >/dev/null
	@chmod +x $(ah)
	@echo $$(cat deps/ah.url) > $@

# sources
tl_all := $(wildcard skills/*/tools/*.tl)
tl_tests := $(wildcard skills/*/tools/test_*.tl)
tl_srcs := $(filter-out $(tl_tests),$(tl_all))

TL_PATH := /zip/.lua/?.tl;/zip/.lua/?/init.tl;/zip/.lua/types/?.d.tl;/zip/.lua/types/?/init.d.tl
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

# ci: type checks + format checks + tests
.PHONY: ci
ci: check-types check-format test

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
	@echo "  work                Run full work loop (pick -> plan -> do -> check -> act)"
	@echo "  pick                Pick a work item: PR with feedback or issue (REPO=owner/repo)"
	@echo "  clone               Clone repo and checkout work branch"
	@echo "  plan                Research codebase and write a plan"
	@echo "  do                  Execute the plan"
	@echo "  check               Review execution and render verdict"
	@echo "  reflect             Run reflect loop (fetch -> analyze -> publish)"
	@echo "  fetch               Fetch workflow run logs and artifacts"
	@echo "  analyze             Analyze fetched data into reflection.md"
	@echo "  publish             Commit reflection.md and open PR"
	@echo "  clean               Remove all build artifacts"

include work.mk
include reflect.mk

.PHONY: clean
clean:
	@rm -rf $(o)
