#!/usr/bin/env bash

set -u

main() {
  assert_no_shellcheck
  assert_version
  assert_text_diagnostic
  assert_json_diagnostic
  printf '%s\n' "ok"
}

assert_no_shellcheck() {
  command -v shellcheck >/dev/null 2>&1 && fail "shellcheck should not be installed"
}

assert_version() {
  [[ "$(shellcheck-legibility --version)" == "0.2.1" ]] || fail "expected version 0.2.1"
}

assert_text_diagnostic() {
  write_fixture
  run_linter "text"
  [[ "$STATUS" -eq 1 ]] || fail "expected text run to exit 1"
  [[ "$OUTPUT" == *"LEG002"* ]] || fail "expected LEG002 in text output"
}

assert_json_diagnostic() {
  write_fixture
  run_linter "json"
  [[ "$STATUS" -eq 1 ]] || fail "expected json run to exit 1"
  [[ "$OUTPUT" == *'"code":"LEG002"'* ]] || fail "expected LEG002 in json output"
}

write_fixture() {
  local condition
  mkdir -p sample/scripts
  condition='if [[ -n "$USER" && -n "$HOME" ]]; then'
  {
    printf '%s\n' '#!/usr/bin/env bash'
    printf '%s\n' "$condition"
    printf '%s\n' '  printf "%s\n" "$USER"'
    printf '%s\n' 'fi'
  } > sample/scripts/example.sh
}

run_linter() {
  local format="${1:-}"
  set +e
  OUTPUT="$(shellcheck-legibility check sample/scripts/example.sh --output-format "$format" 2>&1)"
  STATUS="$?"
  set -u
}

fail() {
  printf '%s\n' "${1:-}" >&2
  exit 1
}

main "$@"
