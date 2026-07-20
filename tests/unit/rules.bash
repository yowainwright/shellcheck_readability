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
# shellcheck source=../../lib/config.bash
source "$ROOT_DIR/lib/config.bash"
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
  test_version_metadata
  test_core_rules
  test_function_rules
  test_comment_rules
  test_config_formats
  printf '%s\n' "ok"
}

test_config_formats() {
  test_config_fixture "rc" ".shellcheck-readabilityrc" "17"
  test_config_fixture "yaml" ".shellcheck-readability.yml" "18"
  test_config_fixture "toml" "shellcheck-readability.toml" "19"
  test_yaml_config_list_values
  test_inline_yaml_list_values
}

test_config_fixture() {
  local format="${1:-}"
  local filename="${2:-}"
  local expected_max="${3:-}"
  local dir path resolved
  reset_test_state
  dir="$ROOT_DIR/tests/fixtures/config/$format"
  path="$dir/$filename"
  resolved="$(config_in_dir "$dir")"
  assert_equal "$path" "$resolved"
  read_config_file "$path"
  assert_equal "$expected_max" "$MAX_FUNCTION_LINES"
  assert_equal "LEG LEG041" "${SELECT[*]}"
}

test_yaml_config_list_values() {
  local path
  reset_test_state
  path="$ROOT_DIR/tests/fixtures/config/yaml/.shellcheck-readability.yml"
  read_config_file "$path"
  assert_equal "2" "${#COMMENT_MATCHERS[@]}"
  assert_equal '^ticket,[0-9]+$' "${COMMENT_MATCHERS[0]}"
  assert_equal '^issue#[0-9]+$' "${COMMENT_MATCHERS[1]}"
}

test_inline_yaml_list_values() {
  local path
  reset_test_state
  path="$ROOT_DIR/tests/fixtures/config/yaml/inline-lists.yml"
  read_config_file "$path"
  assert_equal "2" "${#COMMENT_MATCHERS[@]}"
  assert_equal '^foo,(bar|baz)$' "${COMMENT_MATCHERS[0]}"
  assert_equal '^issue#[0-9]+$' "${COMMENT_MATCHERS[1]}"
}

test_version_metadata() {
  local reported
  reported="$("$ROOT_DIR/bin/shellcheck-readability" --version)"
  assert_equal "0.2.0" "$reported"
}

test_core_rules() {
  test_hoist_if_operators
  test_max_expression_operators
  test_bool_literal_args
  test_direct_shell_bin_smoke
  test_max_function_lines
  test_prefer_functions
  test_prefer_functions_allows_dispatch
}

test_function_rules() {
  test_use_defaults_in_functions
  test_use_defaults_in_functions_allows_defaults
  test_use_defaults_in_functions_reports_separate_assignment
  test_use_defaults_in_functions_reports_transformed_arg
  test_use_defaults_in_functions_reports_single_line_function
  test_use_defaults_in_functions_reports_opening_line_binding
  test_use_defaults_in_functions_reports_declare_binding
  test_use_defaults_in_functions_reports_typeset_binding
  test_use_defaults_in_functions_allows_global_declare
  test_use_defaults_in_functions_allows_assign_default
  test_use_defaults_in_functions_reports_command_list_assignment
  test_split_function_declaration_reports_arg_binding
  test_inline_function_does_not_leak_function_state
}

test_comment_rules() {
  test_comment_ownership_rules
  test_comment_attribution_rules
}

test_comment_ownership_rules() {
  test_no_unmatched_comments
  test_no_unmatched_comments_allows_prefix_identifier
  test_no_unmatched_comments_allows_suffix_identifier
  test_no_unmatched_comments_allows_exact_suffix_identifier
  test_no_unmatched_comments_allows_matcher
  test_no_unmatched_comments_rejects_partial_identifiers
  test_no_unmatched_comments_ignores_directives
  test_no_unmatched_comments_skips_quoted_hashes
  test_comment_rules_are_opt_in
  test_comment_rule_names_select_explicitly
  test_comment_rules_cache_disabled_state
}

test_comment_attribution_rules() {
  test_no_automated_comment_attribution
  test_no_automated_comment_attribution_detects_author
  test_no_automated_comment_attribution_allows_references
  test_no_automated_comment_attribution_allows_mid_phrase_identifiers
  test_no_automated_comment_attribution_detects_article_signature
  test_no_automated_comment_attribution_detects_trailing_prose
  test_no_automated_comment_attribution_supports_custom_identifiers
  test_no_automated_comment_attribution_allows_empty_identifiers
  test_no_automated_comment_attribution_ignores_directives
  test_no_automated_comment_attribution_skips_quoted_hashes
  test_scan_line_runs_comment_policy
  test_scan_line_skips_heredoc_payload
  test_scan_line_skips_tab_stripped_heredoc_payload
  test_scan_line_closes_escaped_heredoc
  test_scan_line_detects_quoted_command_substitution_heredoc
  test_scan_line_preserves_multiline_quote_state
}

reset_test_state() {
  reset_test_config
  init_defaults
  reset_test_diagnostics
  CURRENT_LINE_TEXT=""
  invalidate_comment_rule_state
  reset_scan_state "example.sh"
}

reset_test_config() {
  SELECT=()
  IGNORE=()
  EXCLUDE=()
  EXECUTABLE_ENTRY_PATTERNS=()
  DIRECT_SHELL_ENTRY_PATTERNS=()
  EXECUTABLE_RUNTIMES=()
  COMMENT_MATCHERS=()
  COMMENT_PREFIX_IDENTIFIERS=()
  COMMENT_SUFFIX_IDENTIFIERS=()
  AUTOMATED_COMMENT_IDENTIFIERS=()
}

reset_test_diagnostics() {
  DIAG_CODES=()
  DIAG_PATHS=()
  DIAG_LINES=()
  DIAG_COLUMNS=()
  DIAG_RULES=()
  DIAG_MESSAGES=()
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

test_use_defaults_in_functions_reports_declare_binding() {
  reset_test_state
  IN_FUNCTION="1"
  check_use_defaults_in_functions "example.sh" "7" 'declare target="$1"'
  assert_has_code "LEG040"
}

test_use_defaults_in_functions_reports_typeset_binding() {
  reset_test_state
  IN_FUNCTION="1"
  check_use_defaults_in_functions "example.sh" "7" 'typeset target="$1"'
  assert_has_code "LEG040"
}

test_use_defaults_in_functions_allows_global_declare() {
  reset_test_state
  IN_FUNCTION="1"
  check_use_defaults_in_functions "example.sh" "7" 'declare -g target="$1"'
  assert_no_diagnostics
}

test_use_defaults_in_functions_allows_assign_default() {
  reset_test_state
  IN_FUNCTION="1"
  check_use_defaults_in_functions "example.sh" "7" 'local target="${1:=staging}"'
  check_use_defaults_in_functions "example.sh" "8" 'local mode="${1=dev}"'
  assert_no_diagnostics
}

test_use_defaults_in_functions_reports_command_list_assignment() {
  reset_test_state
  IN_FUNCTION="1"
  check_use_defaults_in_functions "example.sh" "7" 'prepare && target="$1"' # noqa: LEG040
  assert_has_code "LEG040"
}

test_split_function_declaration_reports_arg_binding() {
  reset_test_state
  scan_line "example.sh" "1" "deploy()"
  assert_no_diagnostics
  scan_line "example.sh" "2" "{"
  assert_no_diagnostics
  scan_line "example.sh" "3" 'local target="$1"'
  assert_has_code "LEG040"
}

test_inline_function_does_not_leak_function_state() {
  reset_test_state
  update_function_state "example.sh" "3" 'deploy() { local target="${1:-staging}"; }'
  [[ "$IN_FUNCTION" == "0" ]] || fail "expected inline function to stay closed"
}

test_no_unmatched_comments() {
  reset_test_state
  SELECT=("LEG041")
  check_no_unmatched_comments "example.sh" "4" "# explain this branch"
  assert_has_code "LEG041"
}

test_no_unmatched_comments_allows_prefix_identifier() {
  reset_test_state
  SELECT=("LEG041")
  COMMENT_PREFIX_IDENTIFIERS+=("HUMAN")
  check_no_unmatched_comments "example.sh" "4" "# HUMAN: legacy API order"
  assert_no_diagnostics
}

test_no_unmatched_comments_allows_suffix_identifier() {
  reset_test_state
  SELECT=("LEG041")
  COMMENT_SUFFIX_IDENTIFIERS+=("@owned")
  check_no_unmatched_comments "example.sh" "4" 'deploy "$target" # preserve order @owned'
  assert_no_diagnostics
}

test_no_unmatched_comments_allows_exact_suffix_identifier() {
  reset_test_state
  SELECT=("LEG041")
  COMMENT_SUFFIX_IDENTIFIERS+=("@owned")
  check_no_unmatched_comments "example.sh" "4" "# @owned"
  assert_no_diagnostics
}

test_no_unmatched_comments_allows_matcher() {
  reset_test_state
  SELECT=("LEG041")
  COMMENT_MATCHERS+=("ENG-[0-9]+")
  check_no_unmatched_comments "example.sh" "4" "# ENG-482 tracks this branch"
  assert_no_diagnostics
}

test_no_unmatched_comments_rejects_partial_identifiers() {
  reset_test_state
  SELECT=("LEG041")
  COMMENT_PREFIX_IDENTIFIERS+=("HUMAN")
  COMMENT_SUFFIX_IDENTIFIERS+=("@owned")
  check_no_unmatched_comments "example.sh" "4" "# HUMANIZED generated not@owned"
  assert_has_code "LEG041"
}

test_no_unmatched_comments_ignores_directives() {
  reset_test_state
  SELECT=("LEG041")
  check_no_unmatched_comments "example.sh" "1" "#!/usr/bin/env bash"
  check_no_unmatched_comments "example.sh" "2" "# shellcheck disable=SC1091"
  check_no_unmatched_comments "example.sh" "3" "# noqa: LEG041"
  assert_no_diagnostics
}

test_no_unmatched_comments_skips_quoted_hashes() {
  reset_test_state
  SELECT=("LEG041")
  check_no_unmatched_comments "example.sh" "7" "printf '%s\n' '#!/usr/bin/env bash'"
  assert_no_diagnostics
}

test_comment_rules_are_opt_in() {
  local identifier signature selector
  identifier="code""x"
  signature="# Generated by $identifier."
  for selector in LEG all; do
    reset_test_state
    SELECT=("$selector")
    check_no_unmatched_comments "example.sh" "4" "# explain this branch"
    check_no_automated_comment_attribution "example.sh" "5" "$signature"
    assert_no_diagnostics
  done
}

test_comment_rule_names_select_explicitly() {
  reset_test_state
  SELECT=("no-unmatched-comments")
  check_no_unmatched_comments "example.sh" "4" "# explain this branch"
  assert_has_code "LEG041"
}

test_comment_rules_cache_disabled_state() {
  reset_test_state
  prepare_comment_rule_state
  assert_equal "0" "$COMMENT_RULES_ENABLED"
  assert_equal "0" "$NO_UNMATCHED_COMMENTS_ENABLED"
  assert_equal "0" "$NO_AUTOMATED_COMMENT_ATTRIBUTION_ENABLED"
}

test_no_automated_comment_attribution() {
  reset_test_state
  local identifier signature
  identifier="code""x"
  signature="# Generated by $identifier."
  SELECT=("LEG042")
  check_no_automated_comment_attribution "example.sh" "4" "$signature"
  assert_has_code "LEG042"
}

test_no_automated_comment_attribution_detects_author() {
  reset_test_state
  local identifier signature
  identifier="open""ai"
  signature="# @AUTHOR: $identifier"
  SELECT=("LEG042")
  check_no_automated_comment_attribution "example.sh" "4" "$signature"
  assert_has_code "LEG042"
}

test_no_automated_comment_attribution_allows_references() {
  reset_test_state
  SELECT=("LEG042")
  check_no_automated_comment_attribution "example.sh" "4" "# Send the request to OpenAI."
  check_no_automated_comment_attribution "example.sh" "5" "# Parse the AI response."
  assert_no_diagnostics
}

test_no_automated_comment_attribution_allows_mid_phrase_identifiers() {
  reset_test_state
  local identifier author_reference pipeline_reference
  identifier="a""i"
  author_reference="# Written by an $identifier engineer."
  pipeline_reference="# Generated by ${identifier}-assisted tooling."
  SELECT=("LEG042")
  check_no_automated_comment_attribution "example.sh" "4" "$author_reference"
  check_no_automated_comment_attribution "example.sh" "5" "$pipeline_reference"
  assert_no_diagnostics
}

test_no_automated_comment_attribution_detects_article_signature() {
  reset_test_state
  local identifier signature
  identifier="a""i"
  signature="# Generated by an $identifier."
  SELECT=("LEG042")
  check_no_automated_comment_attribution "example.sh" "4" "$signature"
  assert_has_code "LEG042"
}

test_no_automated_comment_attribution_detects_trailing_prose() {
  reset_test_state
  local identifier signature
  identifier="code""x"
  signature="# Generated by $identifier; do not edit."
  SELECT=("LEG042")
  check_no_automated_comment_attribution "example.sh" "4" "$signature"
  assert_has_code "LEG042"
}

test_no_automated_comment_attribution_supports_custom_identifiers() {
  reset_test_state
  local identifier signature
  identifier="robot"
  signature="# ${identifier}-authored."
  SELECT=("LEG042")
  apply_comment_config_value "automated-comment-identifiers" "[\"$identifier\"]"
  check_no_automated_comment_attribution "example.sh" "4" "$signature"
  assert_has_code "LEG042"
}

test_no_automated_comment_attribution_allows_empty_identifiers() {
  reset_test_state
  local identifier signature
  identifier="code""x"
  signature="# Generated by $identifier."
  SELECT=("LEG042")
  apply_comment_config_value "automated-comment-identifiers" "[]"
  check_no_automated_comment_attribution "example.sh" "4" "$signature"
  assert_no_diagnostics
}

test_no_automated_comment_attribution_ignores_directives() {
  reset_test_state
  SELECT=("LEG042")
  check_no_automated_comment_attribution "example.sh" "1" "#!/usr/bin/env bash"
  check_no_automated_comment_attribution "example.sh" "2" "# shellcheck disable=SC1091"
  check_no_automated_comment_attribution "example.sh" "3" "# noqa: LEG042"
  assert_no_diagnostics
}

test_no_automated_comment_attribution_skips_quoted_hashes() {
  reset_test_state
  local identifier signature line
  identifier="code""x"
  signature="# Generated by $identifier."
  line="printf '%s\n' '$signature'"
  SELECT=("LEG042")
  check_no_automated_comment_attribution "example.sh" "7" "$line"
  assert_no_diagnostics
}

test_scan_line_runs_comment_policy() {
  reset_test_state
  local identifier signature
  identifier="code""x"
  signature="# Generated by $identifier."
  SELECT=("LEG041" "LEG042")
  scan_line "example.sh" "4" "$signature"
  assert_has_code "LEG041"
  assert_has_code "LEG042"
}

test_scan_line_skips_heredoc_payload() {
  reset_test_state
  local identifier signature
  identifier="code""x"
  signature="# Generated by $identifier."
  SELECT=("LEG041" "LEG042")
  scan_line "example.sh" "1" "cat <<'SCRIPT'"
  scan_line "example.sh" "2" "$signature"
  scan_line "example.sh" "3" "SCRIPT"
  assert_no_diagnostics
  scan_line "example.sh" "4" "$signature"
  assert_has_code "LEG041"
  assert_has_code "LEG042"
}

test_scan_line_skips_tab_stripped_heredoc_payload() {
  reset_test_state
  local identifier signature
  identifier="code""x"
  signature="# Generated by $identifier."
  SELECT=("LEG041" "LEG042")
  scan_line "example.sh" "1" "cat <<-'SCRIPT'"
  scan_line "example.sh" "2" "$signature"
  scan_line "example.sh" "3" $'\tSCRIPT'
  assert_no_diagnostics
}

test_scan_line_closes_escaped_heredoc() {
  reset_test_state
  local identifier signature
  identifier="code""x"
  signature="# Generated by $identifier."
  SELECT=("LEG042")
  scan_line "example.sh" "1" "cat <<\\EOF"
  scan_line "example.sh" "2" "$signature"
  scan_line "example.sh" "3" "EOF"
  assert_no_diagnostics
  scan_line "example.sh" "4" "$signature"
  assert_has_code "LEG042"
}

test_scan_line_detects_quoted_command_substitution_heredoc() {
  reset_test_state
  local identifier signature
  identifier="code""x"
  signature="# Generated by $identifier."
  SELECT=("LEG042")
  scan_line "example.sh" "1" "value=\"\$(cat <<'EOF'"
  scan_line "example.sh" "2" "$signature"
  scan_line "example.sh" "3" "EOF"
  scan_line "example.sh" "4" ')"'
  assert_no_diagnostics
}

test_scan_line_preserves_multiline_quote_state() {
  reset_test_state
  local identifier signature
  identifier="code""x"
  signature="# Generated by $identifier."
  SELECT=("LEG042")
  scan_line "example.sh" "1" 'value="first line'
  scan_line "example.sh" "2" "$signature"
  scan_line "example.sh" "3" 'last line"'
  assert_no_diagnostics
  scan_line "example.sh" "4" "$signature"
  assert_has_code "LEG042"
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

assert_equal() {
  local expected="${1:-}"
  local actual="${2:-}"
  [[ "$actual" == "$expected" ]] && return
  printf 'expected %s, got %s\n' "$expected" "$actual" >&2
  exit 1
}

fail() {
  printf '%s\n' "${1:-}" >&2
  exit 1
}

main "$@"
