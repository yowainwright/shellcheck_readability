#!/usr/bin/env bash
# shellcheck disable=SC2034

set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# shellcheck disable=SC1091
# shellcheck source=../../lib/defaults.bash
source "$ROOT_DIR/lib/defaults.bash"
# shellcheck disable=SC1091
# shellcheck source=../../lib/util.bash
source "$ROOT_DIR/lib/util.bash"
# shellcheck disable=SC1091
# shellcheck source=../../lib/rules.bash
source "$ROOT_DIR/lib/rules.bash"
# shellcheck disable=SC1091
# shellcheck source=../../lib/files.bash
source "$ROOT_DIR/lib/files.bash"
# shellcheck disable=SC1091
# shellcheck source=../../lib/lint.bash
source "$ROOT_DIR/lib/lint.bash"

main() {
  test_hoist_if_operators
  test_max_expression_operators
  test_bool_literal_args
  test_direct_shell_bin_smoke
  test_max_function_lines
  test_prefer_functions
  test_prefer_functions_allows_dispatch
  test_use_defaults_in_functions
  test_use_defaults_in_functions_allows_defaults
  test_use_defaults_in_functions_reports_separate_assignment
  test_use_defaults_in_functions_reports_transformed_arg
  test_use_defaults_in_functions_reports_single_line_function
  test_use_defaults_in_functions_reports_opening_line_binding
  test_inline_function_does_not_leak_function_state
  printf '%s\n' "ok"
}

reset_test_state() {
  SELECT=()
  IGNORE=()
  EXCLUDE=()
  EXECUTABLE_ENTRY_PATTERNS=()
  DIRECT_SHELL_ENTRY_PATTERNS=()
  EXECUTABLE_RUNTIMES=()
  init_defaults
  DIAG_CODES=()
  DIAG_PATHS=()
  DIAG_LINES=()
  DIAG_COLUMNS=()
  DIAG_RULES=()
  DIAG_MESSAGES=()
  CURRENT_LINE_TEXT=""
  reset_scan_state "example.sh"
}

test_hoist_if_operators() {
  reset_test_state
  check_hoist_if_operators "example.sh" "4" 'if [[ -n "$user" && -n "$email" ]]; then'
  assert_has_code "LEG002"
}

test_max_expression_operators() {
  reset_test_state
  MAX_EXPRESSION_OPERATORS="1"
  check_max_expression_operators "example.sh" "7" 'build && test && package'
  assert_has_code "LEG001"
}

test_bool_literal_args() {
  reset_test_state
  check_no_bool_literal_args "example.sh" "9" 'create_user "$name" true false' # noqa: LEG035
  assert_has_code "LEG035"
}

test_direct_shell_bin_smoke() {
  reset_test_state
  check_no_direct_shell_bin_smoke "smoke.sh" "3" 'bash scripts/example.sh --help'
  assert_has_code "LEG017"
}

test_max_function_lines() {
  reset_test_state
  MAX_FUNCTION_LINES="3"
  check_max_function_lines "example.sh" "1" "5"
  assert_has_code "LEG038"
}

test_prefer_functions() {
  reset_test_state
  check_prefer_functions "example.sh" "5" "docker build ."
  assert_has_code "LEG039"
}

test_prefer_functions_allows_dispatch() {
  reset_test_state
  FUNCTION_NAMES+=("main")
  check_prefer_functions "example.sh" "12" 'main "$@"'
  assert_no_diagnostics
}

test_use_defaults_in_functions() {
  reset_test_state
  IN_FUNCTION="1"
  check_use_defaults_in_functions "example.sh" "6" 'local target="$1"'
  assert_has_code "LEG040"
}

test_use_defaults_in_functions_allows_defaults() {
  reset_test_state
  IN_FUNCTION="1"
  check_use_defaults_in_functions "example.sh" "6" 'local target="${1:-dev}"'
  assert_no_diagnostics
}

test_use_defaults_in_functions_reports_separate_assignment() {
  reset_test_state
  IN_FUNCTION="1"
  check_use_defaults_in_functions "example.sh" "7" 'target="$1"'
  assert_has_code "LEG040"
}

test_use_defaults_in_functions_reports_transformed_arg() {
  reset_test_state
  IN_FUNCTION="1"
  check_use_defaults_in_functions "example.sh" "8" 'local base="${1%.ext}"'
  assert_has_code "LEG040"
}

test_use_defaults_in_functions_reports_single_line_function() {
  reset_test_state
  check_use_defaults_in_functions "example.sh" "3" 'deploy() { local target="$1"; upload "$target"; }'
  assert_has_code "LEG040"
}

test_use_defaults_in_functions_reports_opening_line_binding() {
  reset_test_state
  check_use_defaults_in_functions "example.sh" "3" 'deploy() { local target="$1"'
  assert_has_code "LEG040"
}

test_inline_function_does_not_leak_function_state() {
  reset_test_state
  update_function_state "example.sh" "3" 'deploy() { local target="${1:-staging}"; }'
  [[ "$IN_FUNCTION" == "0" ]] || fail "expected inline function to stay closed"
}

assert_has_code() {
  local expected="${1:-}"
  local code
  for code in "${DIAG_CODES[@]}"; do
    [[ "$code" == "$expected" ]] && return
  done
  printf 'expected %s, got %s\n' "$expected" "${DIAG_CODES[*]}" >&2
  exit 1
}

assert_no_diagnostics() {
  [[ "${#DIAG_CODES[@]}" -eq 0 ]] && return
  printf 'expected no diagnostics, got %s\n' "${DIAG_CODES[*]}" >&2
  exit 1
}

fail() {
  printf '%s\n' "${1:-}" >&2
  exit 1
}

main "$@"
