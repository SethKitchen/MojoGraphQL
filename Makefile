# Copyright (c) 2026 Seth Kitchen, PE
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Noncommercial use is free; commercial use requires a paid license.
# See LICENSE, LICENSE-COMMERCIAL.md and THIRD-PARTY-NOTICES.md.

# Development tasks for MojoGraphQL. Run `make help` for the list.
#
# The tools are Mojo programs in tools/, built into .cache/bin/ on first
# use. Nothing here needs Python.
#
# `PKG=<name>` limits a task to one package. For `test`, `lint` and
# `coverage` that is the package and every package that depends on it, so a
# change is checked wherever it can break something. For `package` it is the
# package and what it depends on: what a user installs.

MOJO := .venv/bin/mojo
# -I . puts the repository root on the import path, so
# `from gql_language.parser import parse` resolves.
MOJOFLAGS := -I .
JOBS ?= $(shell nproc 2> /dev/null || sysctl -n hw.logicalcpu 2> /dev/null || echo 4)
# The time limit for one test, in seconds. A slower test means a slow
# library: make the library faster, do not change the test.
TEST_TIMEOUT := 5
BIN := .cache/bin

# Build a tool from tools/<name>.mojo when it is missing or older than its
# source. Used inside $(shell), so it runs while the Makefile is read.
tool = $(shell [ $(BIN)/$(1) -nt tools/$(1).mojo ] || { mkdir -p $(BIN) && \
         $(MOJO) build $(MOJOFLAGS) -o $(BIN)/$(1) tools/$(1).mojo > /dev/null 2>&1; }; \
         echo $(BIN)/$(1))
PACKAGES := $(call tool,packages)
RUN_SUITE := $(call tool,run_suite)

PKG ?=
ifeq ($(strip $(PKG)),)
SELECTED := $(shell $(PACKAGES) list)
CLOSURE := $(SELECTED)
else
SELECTED := $(shell $(PACKAGES) dependents $(PKG))
CLOSURE := $(shell $(PACKAGES) closure $(PKG))
endif

LIB_SOURCES := $(shell $(PACKAGES) sources $(SELECTED))
TESTS := $(shell $(PACKAGES) tests $(SELECTED))
# `make coverage PKG=x ONLY=1` measures x alone, without its dependents.
ifeq ($(strip $(ONLY)),)
COV_SOURCES := $(LIB_SOURCES)
COV_TESTS := $(TESTS)
else
COV_SOURCES := $(shell $(PACKAGES) sources $(PKG))
COV_TESTS := $(shell $(PACKAGES) tests $(PKG))
endif
BENCHES := $(shell $(PACKAGES) benches $(SELECTED))
ALL_FILES := $(shell $(PACKAGES) files)
TOOL_SOURCES := $(wildcard coverage/*.mojo) $(wildcard tools/*.mojo)
FORMATTED := $(ALL_FILES) $(TOOL_SOURCES) \
             $(shell find tests bench bin -name '*.mojo' 2> /dev/null)
DOCS := README.md CONTRIBUTING.md $(wildcard docs/wiki/*.md)
COV_DIR := coverage/build/$(or $(PKG),all)

# Every Mojo invocation prints a harmless Crashpad warning. Capture the
# output, keep the exit status in $$rc, and drop that line.
define run
out=$$($(1) 2>&1); rc=$$?; printf '%s\n' "$$out" | sed '/Crashpad/d'
endef

.PHONY: help check test lint fmt fmt-check packages-check docs-check \
        coverage bench bench-check package scorchql forge clean

help:
	@echo "MojoGraphQL tasks ($(words $(SELECTED)) packages selected)"
	@echo
	@echo "  make check           format, package graph, lint, tests, docs"
	@echo "  make test            build and run the test suites"
	@echo "  make lint            docstrings and warnings, as errors"
	@echo "  make coverage        line, branch, condition and MC/DC; 100% or fail"
	@echo "  make bench           Mojo against the upstream libraries"
	@echo "  make bench-check     fail when Mojo is not the fastest"
	@echo "  make package         one precompiled .mojoc per package, into dist/"
	@echo "  make scorchql        the ScorchQL gateway, its demo and seamstress, into dist/"
	@echo "  make forge           the Forge control plane, into dist/"
	@echo "  make fmt             reformat the sources"
	@echo "  make packages-check  enforce the package graph in packages.toml"
	@echo "  make docs-check      check the documentation writing rules"
	@echo
	@echo "Add PKG=<name> to work on one package, such as PKG=gql_language."

check: fmt-check packages-check lint test docs-check

packages-check:
	@$(PACKAGES) check

# Suites build and run at once: each pays a fixed compile cost.
test:
	@[ -z "$(strip $(TESTS))" ] || printf '%s\n' $(TESTS) | xargs -P $(JOBS) -I {} \
	  $(RUN_SUITE) $(MOJO) $(TEST_TIMEOUT) {} $(MOJOFLAGS) \
	  || { echo "Some suites FAILED."; exit 1; }
	@echo "All $(words $(TESTS)) suites passed."

# `mojo doc` with every warning as an error, missing docstrings included,
# checks each library module. Building the benchmarks type-checks them.
lint:
	@printf '%s\n' $(LIB_SOURCES) | xargs -P $(JOBS) -I {} \
	  sh -c '$(call run,$(MOJO) doc $(MOJOFLAGS) --Werror \
	    --diagnose-missing-doc-strings -o /dev/null "$$1"); exit $$rc' _ {} \
	  || { echo "lint failed."; exit 1; }
	@[ -z "$(strip $(BENCHES))" ] || printf '%s\n' $(BENCHES) | xargs -P $(JOBS) -I {} \
	  sh -c '$(call run,$(MOJO) build $(MOJOFLAGS) --Werror -o /dev/null "$$1"); exit $$rc' _ {} \
	  || { echo "lint failed."; exit 1; }
	@[ -n "$(strip $(PKG))" ] || printf '%s\n' $(PROGRAMS) | xargs -P $(JOBS) -I {} \
	  sh -c '$(call run,$(MOJO) build $(MOJOFLAGS) --Werror -o /dev/null "$$1"); exit $$rc' _ {} \
	  || { echo "lint failed."; exit 1; }
	@echo "No warnings: $(words $(LIB_SOURCES)) modules, $(words $(BENCHES)) benchmarks."

fmt:
	@$(call run,$(MOJO) format -q $(FORMATTED)); exit $$rc

fmt-check:
	@tmp=$$(mktemp -d); trap 'rm -rf "$$tmp"' 0; \
	for f in $(FORMATTED); do mkdir -p "$$tmp/$$(dirname $$f)"; cp "$$f" "$$tmp/$$f"; done; \
	(cd "$$tmp" && $(call run,$(CURDIR)/$(MOJO) format -q $(FORMATTED)); exit $$rc) || exit 1; \
	fail=0; \
	for f in $(FORMATTED); do \
	  cmp -s "$$f" "$$tmp/$$f" || { echo "needs formatting: $$f"; fail=1; }; \
	done; \
	if [ $$fail -ne 0 ]; then echo "Run 'make fmt'."; exit 1; fi; \
	echo "All $(words $(FORMATTED)) files formatted."

docs-check:
	@$(call run,$(MOJO) run $(MOJOFLAGS) tools/doc_lint.mojo $(DOCS)); exit $$rc

# Instrument the selected libraries, run the suites against the copies, and
# report. Mojo 1.2 resolves a module beside the file being compiled before
# any -I path, so the suites run from inside $(COV_DIR), beside the
# instrumented copies. Every other package file and the coverage runtime are
# copied there unchanged.
coverage:
	@rm -rf $(COV_DIR) && mkdir -p $(COV_DIR)/hits
	@for f in $(ALL_FILES) $(wildcard coverage/*.mojo) $(shell find tests -name '*.mojo'); do \
	  mkdir -p "$(COV_DIR)/$$(dirname $$f)"; cp "$$f" "$(COV_DIR)/$$f"; done
	@$(call run,$(MOJO) run $(MOJOFLAGS) coverage/build_cli.mojo $(COV_DIR) $(COV_SOURCES)); \
	  exit $$rc
	@printf '%s\n' $(COV_TESTS) | xargs -P $(JOBS) -I {} sh -c \
	  'name=$$(echo "$$1" | tr / _); cd $(COV_DIR) && \
	   $(abspath $(MOJO)) run -I . "$$1" > /dev/null 2> "hits/$$name.txt" \
	   || { echo "$$1 failed under instrumentation"; exit 1; }' _ {} \
	  || { echo "Coverage not measured."; exit 1; }
	@$(call run,$(MOJO) run $(MOJOFLAGS) coverage/report_cli.mojo \
	  $(COV_DIR)/manifest.txt $(COV_DIR)/hits/*.txt); exit $$rc

bench:
	@$(call run,$(MOJO) run $(MOJOFLAGS) tools/bench.mojo $(MOJO) $(SELECTED)); exit $$rc

bench-check:
	@$(call run,$(MOJO) run $(MOJOFLAGS) tools/bench.mojo --check $(MOJO) $(SELECTED)); exit $$rc

package:
	@mkdir -p dist
	@for p in $(CLOSURE); do \
	  $(call run,$(MOJO) precompile $(MOJOFLAGS) $$p -o dist/$$p.mojoc); \
	  [ $$rc -eq 0 ] || exit 1; echo "dist/$$p.mojoc"; \
	done

# The ScorchQL programs: the gateway and the demo subgraphs. A program in
# bin/ is not a package, so it can join packages that do not depend on each
# other.
PROGRAMS := $(wildcard bin/*.mojo)

scorchql:
	@mkdir -p dist
	@$(call run,$(MOJO) build $(MOJOFLAGS) -o dist/scorchql bin/scorchql.mojo); \
	  [ $$rc -eq 0 ] || exit 1; echo "dist/scorchql"
	@$(call run,$(MOJO) build $(MOJOFLAGS) -o dist/scorchql-demo bin/scorchql_demo.mojo); \
	  [ $$rc -eq 0 ] || exit 1; echo "dist/scorchql-demo"
	@$(call run,$(MOJO) build $(MOJOFLAGS) -o dist/seamstress bench/gql_seamstress/_seamstress.mojo); \
	  [ $$rc -eq 0 ] || exit 1; echo "dist/seamstress"

forge:
	@mkdir -p dist
	@$(call run,$(MOJO) build $(MOJOFLAGS) -o dist/forge bin/forge.mojo); \
	  [ $$rc -eq 0 ] || exit 1; echo "dist/forge"

clean:
	@rm -rf coverage/build .cache dist
