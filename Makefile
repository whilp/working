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

# sources
tl_all := $(wildcard skills/*/tools/*.tl)
tl_tests := $(wildcard skills/*/tools/test_*.tl)
tl_srcs := $(filter-out $(tl_tests),$(tl_all))

TL_PATH := /zip/.lua/?.tl;/zip/.lua/?/init.tl;/zip/.lua/types/?.d.tl;/zip/.lua/types/?/init.d.tl
TL_PATH_TEST := ?.tl;?/init.tl;$(TL_PATH)

# type checking
all_type_checks := $(patsubst %,$(o)/%.teal.ok,$(tl_srcs))

$(o)/%.tl.teal.ok: %.tl $(cosmic)
	@mkdir -p $(@D)
	@if TL_PATH='$(TL_PATH)' $(cosmic) --check-types "$<" >/dev/null 2>$@.err; then \
		echo "pass" > $@; \
	else \
		echo "FAIL" > $@; \
		cat $@.err >> $@; \
	fi; \
	rm -f $@.err

.PHONY: check-types
check-types: $(all_type_checks)
	@fail=0; total=0; \
	for f in $(all_type_checks); do \
		total=$$((total + 1)); \
		src=$$(echo "$$f" | sed 's|^$(o)/||; s|\.teal\.ok$$||'); \
		if grep -q "^pass" "$$f"; then \
			echo "  ✓ $$src"; \
		else \
			echo "  ✗ $$src"; sed -n '2,$$p' "$$f" | sed 's/^/    /'; \
			fail=$$((fail + 1)); \
		fi; \
	done; \
	echo ""; echo "types: $$total checked, $$fail failed"; \
	[ $$fail -eq 0 ]

# format checking
all_fmt_checks := $(patsubst %,$(o)/%.fmt.ok,$(tl_srcs))

$(o)/%.tl.fmt.ok: %.tl $(cosmic)
	@mkdir -p $(@D)
	@if diff -q <(cat "$<") <($(cosmic) --format "$<") >/dev/null 2>&1; then \
		echo "pass" > $@; \
	else \
		echo "FAIL" > $@; \
		diff -u "$<" <($(cosmic) --format "$<") >> $@ 2>/dev/null || true; \
	fi

.PHONY: check-format
check-format: $(all_fmt_checks)
	@fail=0; total=0; \
	for f in $(all_fmt_checks); do \
		total=$$((total + 1)); \
		src=$$(echo "$$f" | sed 's|^$(o)/||; s|\.fmt\.ok$$||'); \
		if grep -q "^pass" "$$f"; then \
			echo "  ✓ $$src"; \
		else \
			echo "  ✗ $$src"; \
			fail=$$((fail + 1)); \
		fi; \
	done; \
	echo ""; echo "format: $$total checked, $$fail failed"; \
	[ $$fail -eq 0 ]

# ci: type checks + format checks + tests
.PHONY: ci
ci: check-types check-format test

# tests
all_test_checks := $(patsubst %,$(o)/%.test.ok,$(tl_tests))

$(o)/%.tl.test.ok: %.tl $(cosmic)
	@mkdir -p $(@D)
	@d=$$(mktemp -d); \
	if TL_PATH='$(TL_PATH_TEST)' TEST_TMPDIR=$$d $(cosmic) "$<" >$$d/out 2>&1; then \
		echo "pass" > $@; \
	else \
		echo "FAIL" > $@; \
		cat $$d/out >> $@ 2>/dev/null || true; \
	fi; \
	rm -rf $$d

.PHONY: test
test: $(all_test_checks)
	@fail=0; total=0; \
	for f in $(all_test_checks); do \
		total=$$((total + 1)); \
		src=$$(echo "$$f" | sed 's|^$(o)/||; s|\.test\.ok$$||'); \
		if grep -q "^pass" "$$f"; then \
			echo "  ✓ $$src"; \
		else \
			echo "  ✗ $$src"; sed -n '2,$$p' "$$f" | sed 's/^/    /'; \
			fail=$$((fail + 1)); \
		fi; \
	done; \
	echo ""; echo "tests: $$total run, $$fail failed"; \
	[ $$fail -eq 0 ]

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
