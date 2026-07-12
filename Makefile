SHELL := bash
UNIT_TEST := tests/unit/rules.bash
E2E_TEST := tests/e2e/docker.bash
E2E_CONTAINER_TEST := tests/e2e/run-in-container.bash
E2E_WRAPPER := tests/e2e/shellcheck-readability-wrapper
E2E_FILES := $(E2E_TEST) $(E2E_CONTAINER_TEST) $(E2E_WRAPPER)
SHELLCHECK_FILES := bin/shellcheck-readability lib/*.bash $(UNIT_TEST) $(E2E_FILES)
SELF_LINT_TARGETS := bin lib tests

.PHONY: check e2e lint self-lint test unit

check: lint unit e2e self-lint

lint:
	shellcheck -x -S warning $(SHELLCHECK_FILES)

self-lint:
	bin/shellcheck-readability check $(SELF_LINT_TARGETS) --exit-zero

test: unit e2e

unit:
	bash $(UNIT_TEST)

e2e:
	bash $(E2E_TEST)
