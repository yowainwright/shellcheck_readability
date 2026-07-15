lint_files() {
  local file
  for file in "${FILES[@]}"; do
    lint_file "$file"
  done
}

lint_file() {
  local path="${1:-}"
  reset_scan_state "$path"
  check_file_rules "$path"
  scan_file_lines "$path"
}

reset_scan_state() {
  SCAN_PATH="${1:-}"
  SCAN_LINE_NUMBER="0"
  CONTROL_FLOW_DEPTH="0"
  LOOP_DEPTH="0"
  IF_DEPTH="0"
  IN_FUNCTION="0"
  FUNCTION_START_LINE="0"
  PENDING_FUNCTION_DECLARATION="0"
  PENDING_FUNCTION_START_LINE="0"
  PREFER_FUNCTIONS_REPORTED="0"
  FUNCTION_NAMES=()
  IF_THEN_EXIT=()
  IF_COMPARE_NAME=()
  IF_COMPARE_COUNT=()
  IF_COMPARE_REPORTED=()
}

check_file_rules() {
  local path="${1:-}"
  check_require_executable_shebang "$path" "1" ""
  check_require_filename_matches_dirname "$path" "1" ""
  check_no_mixed_filename_casing "$path" "1" ""
}

scan_file_lines() {
  local path="${1:-}"
  local line
  local -a lines
  mapfile -t lines < "$path"
  for line in "${lines[@]}"; do
    SCAN_LINE_NUMBER=$((SCAN_LINE_NUMBER + 1))
    scan_line "$path" "$SCAN_LINE_NUMBER" "$line"
  done
}

scan_line() {
  local path="${1:-}"
  local line_number="${2:-}"
  local raw_line="${3:-}"
  local line
  CURRENT_LINE_TEXT="$raw_line"
  check_no_unmatched_comments "$path" "$line_number" "$raw_line"
  line="$(normalized_code_line "$raw_line")"
  [[ -z "$line" ]] && return
  run_line_checks "$path" "$line_number" "$line"
}

normalized_code_line() {
  local line="${1:-}"
  line="$(strip_comment "$line")"
  trim "$line"
}

run_line_checks() {
  local path="${1:-}"
  local line_number="${2:-}"
  local line="${3:-}"
  close_completed_blocks "$line"
  run_stateless_line_checks "$path" "$line_number" "$line"
  update_state_from_line "$path" "$line_number" "$line"
}

run_stateless_line_checks() {
  local path="${1:-}"
  local line_number="${2:-}"
  local line="${3:-}"
  check_max_expression_operators "$path" "$line_number" "$line"
  check_prefer_object_lookup "$path" "$line_number" "$line"
  check_no_direct_shell_bin_smoke "$path" "$line_number" "$line"
  check_no_bool_literal_args "$path" "$line_number" "$line"
  check_prefer_functions "$path" "$line_number" "$line"
  check_use_defaults_in_functions "$path" "$line_number" "$line"
}

update_state_from_line() {
  local path="${1:-}"
  local line_number="${2:-}"
  local line="${3:-}"
  update_function_state "$path" "$line_number" "$line"
  update_if_state "$path" "$line_number" "$line"
  update_loop_state "$path" "$line_number" "$line"
  update_case_state "$path" "$line_number" "$line"
  update_exit_state "$line"
}

close_completed_blocks() {
  local line="${1:-}"
  case "$line" in
    fi*) close_if_block ;;
    done*) close_loop_block ;;
    esac*) close_control_flow ;;
  esac
}

close_if_block() {
  (( IF_DEPTH > 0 )) && IF_DEPTH=$((IF_DEPTH - 1))
  close_control_flow
}

close_loop_block() {
  (( LOOP_DEPTH > 0 )) && LOOP_DEPTH=$((LOOP_DEPTH - 1))
  close_control_flow
}

close_control_flow() {
  (( CONTROL_FLOW_DEPTH > 0 )) && CONTROL_FLOW_DEPTH=$((CONTROL_FLOW_DEPTH - 1))
}

update_function_state() {
  local path="${1:-$SCAN_PATH}"
  local line_number="${2:-$SCAN_LINE_NUMBER}"
  local line="${3:-}"
  maybe_open_function "$path" "$line_number" "$line"
  maybe_close_function "$path" "$line_number" "$line"
}

maybe_open_function() {
  local path="${1:-}"
  local line_number="${2:-}"
  local line="${3:-}"
  [[ "$IN_FUNCTION" == "0" ]] || return
  maybe_open_pending_function "$path" "$line_number" "$line" && return
  is_function_open "$line" || maybe_remember_pending_function "$line_number" "$line"
  is_function_open "$line" || return
  remember_function_name "$line"
  handle_inline_function "$path" "$line_number" "$line" && return
  IN_FUNCTION="1"
  FUNCTION_START_LINE="$line_number"
}

maybe_open_pending_function() {
  local path="${1:-}"
  local line_number="${2:-}"
  local line="${3:-}"
  [[ "$PENDING_FUNCTION_DECLARATION" == "1" ]] || return 1
  ensure_pending_function_brace_line "$line" || return 1
  handle_pending_inline_function "$path" "$line_number" "$line" && return
  IN_FUNCTION="1"
  FUNCTION_START_LINE="$PENDING_FUNCTION_START_LINE"
  clear_pending_function
}

ensure_pending_function_brace_line() {
  local line="${1:-}"
  pending_function_brace_line "$line" && return 0
  clear_pending_function
  return 1
}

handle_pending_inline_function() {
  local path="${1:-}"
  local line_number="${2:-}"
  local line="${3:-}"
  inline_brace_line "$line" || return 1
  check_max_function_lines "$path" "$PENDING_FUNCTION_START_LINE" "$line_number"
  clear_pending_function
}

clear_pending_function() {
  PENDING_FUNCTION_DECLARATION="0"
  PENDING_FUNCTION_START_LINE="0"
}

maybe_close_function() {
  local path="${1:-}"
  local line_number="${2:-}"
  local line="${3:-}"
  [[ "$IN_FUNCTION" == "1" ]] || return
  [[ "$line" == "}"* ]] || return
  check_max_function_lines "$path" "$FUNCTION_START_LINE" "$line_number"
  IN_FUNCTION="0"
}

is_function_open() {
  local line="${1:-}"
  [[ "$line" =~ ^(function[[:space:]]+)?[A-Za-z_][A-Za-z0-9_:-]*[[:space:]]*(\(\))?[[:space:]]*\{ ]]
}

maybe_remember_pending_function() {
  local line_number="${1:-}"
  local line="${2:-}"
  local name
  name="$(function_declaration_name "$line")"
  [[ -z "$name" ]] && return
  FUNCTION_NAMES+=("$name")
  PENDING_FUNCTION_DECLARATION="1"
  PENDING_FUNCTION_START_LINE="$line_number"
}

function_declaration_name() {
  local line="${1:-}"
  function_keyword_declaration_name "$line" && return
  compact_function_declaration_name "$line"
}

function_keyword_declaration_name() {
  local line="${1:-}"
  local keyword name extra
  read -r keyword name extra <<< "$line"
  [[ "$keyword" == "function" ]] || return 1
  [[ -z "$extra" ]] || return 1
  name="${name%%()*}"
  shell_identifier "$name" || return 1
  printf '%s\n' "$name"
}

compact_function_declaration_name() {
  local line="${1:-}"
  local name="${line%%()*}"
  [[ "$name" != "$line" ]] || return 1
  [[ "$line" == "$name()" ]] || return 1
  shell_identifier "$name" || return 1
  printf '%s\n' "$name"
}

remember_function_name() {
  local line="${1:-}"
  local name
  name="$(function_name_from_open "$line")"
  [[ -n "$name" ]] && FUNCTION_NAMES+=("$name")
}

function_name_from_open() {
  local line="${1:-}"
  function_keyword_name "$line" && return
  compact_function_name "$line" && return
  spaced_function_name "$line"
}

function_keyword_name() {
  local line="${1:-}"
  local keyword name
  read -r keyword name _ <<< "$line"
  [[ "$keyword" == "function" ]] || return 1
  name="${name%%()*}"
  printf '%s\n' "$name"
}

compact_function_name() {
  local line="${1:-}"
  local name="${line%%()*}"
  [[ "$name" != "$line" ]] || return 1
  shell_identifier "$name" || return 1
  printf '%s\n' "$name"
}

spaced_function_name() {
  local line="${1:-}"
  local name
  read -r name _ <<< "$line"
  shell_identifier "$name" || return 1
  printf '%s\n' "$name"
}

shell_identifier() {
  local value="${1:-}"
  [[ "$value" =~ ^[A-Za-z_][A-Za-z0-9_:-]*$ ]]
}

update_if_state() {
  local path="${1:-$SCAN_PATH}"
  local line_number="${2:-$SCAN_LINE_NUMBER}"
  local line="${3:-}"
  handle_else_line "$path" "$line_number" "$line" && return
  handle_elif_line "$path" "$line_number" "$line" && return
  handle_if_line "$path" "$line_number" "$line"
}

handle_else_line() {
  local path="${1:-}"
  local line_number="${2:-}"
  local line="${3:-}"
  [[ "$line" == else* ]] || return 1
  check_prefer_early_return "$path" "$line_number" "$line"
  mark_current_if_else
}

handle_elif_line() {
  local path="${1:-}"
  local line_number="${2:-}"
  local line="${3:-}"
  [[ "$line" == elif* ]] || return 1
  check_hoist_if_operators "$path" "$line_number" "$line"
  check_prefer_case_over_long_if_chain "$path" "$line_number" "$line"
}

handle_if_line() {
  local path="${1:-}"
  local line_number="${2:-}"
  local line="${3:-}"
  [[ "$line" == if[[:space:]]* ]] || return
  check_hoist_if_operators "$path" "$line_number" "$line"
  check_prefer_guard_clauses "$path" "$line_number" "$line"
  open_if_block "$path" "$line_number" "$line"
}

open_if_block() {
  local path="${1:-}"
  local line_number="${2:-}"
  local line="${3:-}"
  open_control_flow "$path" "$line_number"
  IF_DEPTH=$((IF_DEPTH + 1))
  IF_THEN_EXIT[IF_DEPTH]="0"
  IF_COMPARE_NAME[IF_DEPTH]="$(comparison_left_name "$line")"
  IF_COMPARE_COUNT[IF_DEPTH]="1"
  IF_COMPARE_REPORTED[IF_DEPTH]="0"
}

mark_current_if_else() {
  (( IF_DEPTH > 0 )) && IF_THEN_EXIT[IF_DEPTH]="else"
}

update_loop_state() {
  local path="${1:-$SCAN_PATH}"
  local line_number="${2:-$SCAN_LINE_NUMBER}"
  local line="${3:-}"
  is_loop_line "$line" || return
  check_loop_condition "$path" "$line_number" "$line"
  check_no_quadratic_patterns "$path" "$line_number" "$line"
  LOOP_DEPTH=$((LOOP_DEPTH + 1))
  open_control_flow "$path" "$line_number"
}

is_loop_line() {
  local line="${1:-}"
  [[ "$line" == for[[:space:]]* ]] && return 0
  [[ "$line" == while[[:space:]]* ]] && return 0
  [[ "$line" == until[[:space:]]* ]]
}

check_loop_condition() {
  local path="${1:-}"
  local line_number="${2:-}"
  local line="${3:-}"
  [[ "$line" == for[[:space:]]* ]] && return
  check_hoist_if_operators "$path" "$line_number" "$line"
}

update_case_state() {
  local path="${1:-$SCAN_PATH}"
  local line_number="${2:-$SCAN_LINE_NUMBER}"
  local line="${3:-}"
  [[ "$line" == case[[:space:]]* ]] || return
  open_control_flow "$path" "$line_number"
}

open_control_flow() {
  local path="${1:-}"
  local line_number="${2:-}"
  CONTROL_FLOW_DEPTH=$((CONTROL_FLOW_DEPTH + 1))
  check_max_control_flow_depth "$path" "$line_number" "$CONTROL_FLOW_DEPTH"
}

update_exit_state() {
  local line="${1:-}"
  (( IF_DEPTH == 0 )) && return
  [[ "${IF_THEN_EXIT[$IF_DEPTH]}" == "else" ]] && return
  command_exits "$line" && IF_THEN_EXIT[IF_DEPTH]="1"
}

command_exits() {
  local line="${1:-}"
  [[ "$line" =~ ^(return|exit|break|continue)([[:space:]]|$) ]]
}

check_max_expression_operators() {
  local path="${1:-$SCAN_PATH}"
  local line_number="${2:-$SCAN_LINE_NUMBER}"
  local expression="${3:-$CURRENT_LINE_TEXT}"
  line_starts_control "$expression" && return
  local count
  count="$(count_expression_operators "$expression")"
  (( count <= MAX_EXPRESSION_OPERATORS )) && return
  report_max_expression_operators "$path" "$line_number" "$count"
}

report_max_expression_operators() {
  local path="${1:-}"
  local line_number="${2:-}"
  local count="${3:-}"
  local message
  message="Expression has $count readability operators (max $MAX_EXPRESSION_OPERATORS). Extract named commands or values."
  add_diag "$path" "$line_number" "1" "LEG001" "$message"
}

check_hoist_if_operators() {
  local path="${1:-$SCAN_PATH}"
  local line_number="${2:-$SCAN_LINE_NUMBER}"
  local line="${3:-$CURRENT_LINE_TEXT}"
  local condition count
  condition="$(condition_text "$line")"
  count="$(count_condition_operators "$condition")"
  (( count <= MAX_CONDITION_OPERATORS )) && return
  report_hoist_if_operators "$path" "$line_number" "$count"
}

report_hoist_if_operators() {
  local path="${1:-}"
  local line_number="${2:-}"
  local count="${3:-}"
  local message
  message="Condition has $count readability operators (max $MAX_CONDITION_OPERATORS). Hoist it into a named check."
  add_diag "$path" "$line_number" "1" "LEG002" "$message"
}

check_max_control_flow_depth() {
  local path="${1:-$SCAN_PATH}"
  local line_number="${2:-$SCAN_LINE_NUMBER}"
  local depth="${3:-$CONTROL_FLOW_DEPTH}"
  (( depth <= MAX_CONTROL_FLOW_DEPTH )) && return
  local message
  message="Control-flow depth is $depth (max $MAX_CONTROL_FLOW_DEPTH). Prefer guard clauses or extracted functions."
  add_diag "$path" "$line_number" "1" "LEG003" "$message"
}

check_no_quadratic_patterns() {
  local path="${1:-$SCAN_PATH}"
  local line_number="${2:-$SCAN_LINE_NUMBER}"
  local line="${3:-$CURRENT_LINE_TEXT}"
  (( LOOP_DEPTH > 0 )) || return
  local message
  message="Nested loop detected. Consider a lookup, case statement, or extracted function."
  add_diag "$path" "$line_number" "1" "LEG005" "$message"
}

check_prefer_early_return() {
  local path="${1:-$SCAN_PATH}"
  local line_number="${2:-$SCAN_LINE_NUMBER}"
  local line="${3:-$CURRENT_LINE_TEXT}"
  [[ "$line" == else* ]] || return
  (( IF_DEPTH > 0 )) || return
  [[ "${IF_THEN_EXIT[$IF_DEPTH]}" == "1" ]] || return
  local message
  message="Avoid else after a branch exits. Return or continue early and keep the follow-up path unindented."
  add_diag "$path" "$line_number" "1" "LEG009" "$message"
}

check_prefer_guard_clauses() {
  local path="${1:-$SCAN_PATH}"
  local line_number="${2:-$SCAN_LINE_NUMBER}"
  local line="${3:-$CURRENT_LINE_TEXT}"
  [[ "$IN_FUNCTION" == "1" ]] || return
  [[ "$line" == if[[:space:]]* ]] || return
  [[ "$line" == *"then"* ]] || return
  local message
  message="Prefer a guard clause before the main path instead of wrapping function logic in an if block."
  add_diag "$path" "$line_number" "1" "LEG010" "$message"
}

check_require_executable_shebang() {
  local path="${1:-$SCAN_PATH}"
  local line_number="${2:-1}"
  path_matches_any "$path" EXECUTABLE_ENTRY_PATTERNS || return
  file_has_allowed_shebang "$path" && return
  add_diag "$path" "$line_number" "1" "LEG016" "Executable shell entry file has no accepted shebang."
}

check_no_direct_shell_bin_smoke() {
  local path="${1:-$SCAN_PATH}"
  local line_number="${2:-$SCAN_LINE_NUMBER}"
  local line="${3:-$CURRENT_LINE_TEXT}"
  local shell entry
  shell="$(first_word "$line")"
  shell_runtime_allowed "$shell" || return
  entry="$(direct_entry_from_line "$line")"
  [[ -z "$entry" ]] && return
  report_no_direct_shell_bin_smoke "$path" "$line_number" "$shell" "$entry"
}

report_no_direct_shell_bin_smoke() {
  local path="${1:-}"
  local line_number="${2:-}"
  local shell="${3:-}"
  local entry="${4:-}"
  local message
  message="Smoke tests should execute the installed command, not \`$shell $entry\`, so packaging and shebangs are exercised."
  add_diag "$path" "$line_number" "1" "LEG017" "$message"
}

check_prefer_object_lookup() {
  local path="${1:-$SCAN_PATH}"
  local line_number="${2:-$SCAN_LINE_NUMBER}"
  local line="${3:-$CURRENT_LINE_TEXT}"
  local count name
  name="$(comparison_left_name "$line")"
  [[ -z "$name" ]] && return
  count="$(count_occurrences "$line" "$name")"
  (( count < MIN_OBJECT_LOOKUP_CHAIN_LENGTH )) && return
  local message
  message="Replace repeated $name equality checks with a case statement or lookup."
  add_diag "$path" "$line_number" "1" "LEG024" "$message"
}

check_require_filename_matches_dirname() {
  local path="${1:-$SCAN_PATH}"
  local line_number="${2:-1}"
  local file parent base depth
  depth="$(path_parent_depth "$path")"
  (( depth < MIN_DIRNAME_MATCH_DEPTH )) && return
  parent="$(basename "$(dirname "$path")")"
  file="$(filename_without_extension "$path")"
  base="${file%%.*}"
  filename_base_allowed "$base" "$parent" && return
  report_filename_mismatch "$path" "$line_number" "$file" "$parent"
}

report_filename_mismatch() {
  local path="${1:-}"
  local line_number="${2:-}"
  local file="${3:-}"
  local parent="${4:-}"
  local message
  message="Filename \"$file\" does not match parent directory \"$parent\"."
  add_diag "$path" "$line_number" "1" "LEG025" "$message"
}

check_no_mixed_filename_casing() {
  local path="${1:-$SCAN_PATH}"
  local line_number="${2:-1}"
  local name
  name="$(filename_base "$path")"
  filename_casing_mixed "$name" || return
  local message
  message="Filename \"$name\" mixes casing conventions. Use one casing convention."
  add_diag "$path" "$line_number" "1" "LEG026" "$message"
}

check_prefer_case_over_long_if_chain() {
  local path="${1:-$SCAN_PATH}"
  local line_number="${2:-$SCAN_LINE_NUMBER}"
  local line="${3:-$CURRENT_LINE_TEXT}"
  track_if_chain_comparison "$path" "$line_number" "$line"
}

check_no_bool_literal_args() {
  local path="${1:-$SCAN_PATH}"
  local line_number="${2:-$SCAN_LINE_NUMBER}"
  local line="${3:-$CURRENT_LINE_TEXT}"
  has_bool_literal_arg "$line" || return
  local message
  message="Avoid boolean literal arguments. Name the option before passing it."
  add_diag "$path" "$line_number" "1" "LEG035" "$message"
}

check_max_function_lines() {
  local path="${1:-$SCAN_PATH}"
  local start_line="${2:-$FUNCTION_START_LINE}"
  local end_line="${3:-$SCAN_LINE_NUMBER}"
  local lines
  lines=$((end_line - start_line + 1))
  (( lines <= MAX_FUNCTION_LINES )) && return
  local message
  message="Function has $lines lines (max $MAX_FUNCTION_LINES). Extract focused helper functions."
  add_diag "$path" "$start_line" "1" "LEG038" "$message"
}

check_prefer_functions() {
  local path="${1:-$SCAN_PATH}"
  local line_number="${2:-$SCAN_LINE_NUMBER}"
  local line="${3:-$CURRENT_LINE_TEXT}"
  [[ "$PREFER_FUNCTIONS_REPORTED" == "0" ]] || return
  [[ "$IN_FUNCTION" == "0" ]] || return
  (( CONTROL_FLOW_DEPTH == 0 )) || return
  top_level_line_allowed "$line" && return
  local message
  message="Move top-level script logic into named functions and keep only setup plus function dispatch at the top level."
  add_diag "$path" "$line_number" "1" "LEG039" "$message"
  PREFER_FUNCTIONS_REPORTED="1"
}

check_use_defaults_in_functions() {
  local path="${1:-$SCAN_PATH}"
  local line_number="${2:-$SCAN_LINE_NUMBER}"
  local line="${3:-$CURRENT_LINE_TEXT}"
  local scoped_line
  scoped_line="$(function_scoped_line "$line")" || return
  has_unguarded_arg_assignment "$scoped_line" || return
  local message
  message="Use a default or required-argument expansion when binding positional parameters inside functions."
  add_diag "$path" "$line_number" "1" "LEG040" "$message"
}

check_no_unmatched_comments() {
  local path="${1:-$SCAN_PATH}"
  local line_number="${2:-$SCAN_LINE_NUMBER}"
  local line="${3:-$CURRENT_LINE_TEXT}"
  local index body
  index="$(shell_comment_index "$line")" || return
  body="${line:$((index + 1))}"
  shell_comment_ignored "$index" "$body" && return
  comment_allowed "$body" && return
  report_no_unmatched_comment "$path" "$line_number" "$index"
}

report_no_unmatched_comment() {
  local path="${1:-}"
  local line_number="${2:-}"
  local index="${3:-0}"
  local column message
  column=$((index + 1))
  message="Comment does not match a configured ownership matcher, prefix, or suffix."
  add_diag "$path" "$line_number" "$column" "LEG041" "$message"
}

function_scoped_line() {
  local line="${1:-}"
  [[ "$IN_FUNCTION" == "1" ]] && printf '%s\n' "$line" && return
  [[ "$PENDING_FUNCTION_DECLARATION" == "1" ]] && brace_opening_body "$line" && return
  function_opening_body "$line"
}

function_opening_body() {
  local line="${1:-}"
  is_function_open "$line" || return 1
  brace_opening_body "$line"
}

brace_opening_body() {
  local line="${1:-}"
  [[ "$line" == *"{"* ]] || return 1
  line="${line#*\{}"
  [[ "$line" == *"}"* ]] && line="${line%\}*}"
  printf '%s\n' "$line"
}

handle_inline_function() {
  local path="${1:-}"
  local line_number="${2:-}"
  local line="${3:-}"
  inline_function_line "$line" || return 1
  check_max_function_lines "$path" "$line_number" "$line_number"
}

inline_function_line() {
  local line="${1:-}"
  is_function_open "$line" || return 1
  [[ "$line" == *"{"*"}"* ]]
}

inline_brace_line() {
  local line="${1:-}"
  [[ "$line" == "{"*"}"* ]]
}

top_level_line_allowed() {
  local line="${1:-}"
  [[ -z "$line" ]] && return 0
  pending_function_brace_line "$line" && return 0
  is_function_open "$line" && return 0
  function_declaration_name "$line" >/dev/null && return 0
  top_level_declaration_line "$line" && return 0
  top_level_block_close "$line" && return 0
  top_level_function_dispatch "$line"
}

pending_function_brace_line() {
  local line="${1:-}"
  [[ "$PENDING_FUNCTION_DECLARATION" == "1" ]] || return 1
  [[ "$line" == "{"* ]]
}

top_level_declaration_line() {
  local line="${1:-}"
  local word
  simple_assignment_line "$line" && return 0
  word="$(first_word "$line")"
  case "$word" in
    set) return 0 ;;
    shopt) return 0 ;;
    trap) return 0 ;;
    source) return 0 ;;
    .) return 0 ;;
    export) return 0 ;;
    readonly) return 0 ;;
    declare) return 0 ;;
    typeset) return 0 ;;
  esac
  return 1
}

simple_assignment_line() {
  local line="${1:-}"
  local name="${line%%=*}"
  [[ "$name" != "$line" ]] || return 1
  name="${name%+}"
  name="${name%%[*}"
  shell_identifier "$name"
}

top_level_block_close() {
  case "${1:-}" in
    "}"*) return 0 ;;
    fi*) return 0 ;;
    done*) return 0 ;;
    "esac"*) return 0 ;;
  esac
  return 1
}

top_level_function_dispatch() {
  local line="${1:-}"
  local command
  command="$(first_word "$line")"
  function_name_seen "$command"
}

function_name_seen() {
  local name="${1:-}"
  local function_name
  [[ "$name" == "main" ]] && return 0
  for function_name in "${FUNCTION_NAMES[@]}"; do
    [[ "$function_name" == "$name" ]] && return 0
  done
  return 1
}

has_unguarded_arg_assignment() {
  local line="${1:-}"
  local segment
  local -a segments
  IFS=';' read -r -a segments <<< "$line"
  for segment in "${segments[@]}"; do
    segment="$(trim "$segment")"
    assignment_segment_uses_unguarded_arg "$segment" && return 0
  done
  return 1
}

assignment_segment_uses_unguarded_arg() {
  local segment="${1:-}"
  binding_assignment_segment "$segment" || return 1
  has_unguarded_positional_expansion "$segment"
}

binding_assignment_segment() {
  local segment="${1:-}"
  declaration_assignment_segment "$segment" && return 0
  simple_assignment_line "$segment"
}

declaration_assignment_segment() {
  local segment="${1:-}"
  local command
  command="$(first_word "$segment")"
  [[ "$segment" == *=* ]] || return 1
  [[ "$command" == "local" ]]
}

has_unguarded_positional_expansion() {
  local text="${1:-}"
  bare_positional_expansion "$text" && return 0
  braced_positional_expansion_unguarded "$text"
}

bare_positional_expansion() {
  local text="${1:-}"
  [[ "$text" =~ (^|[^\\])\$[1-9][0-9]* ]]
}

braced_positional_expansion_unguarded() {
  local text="${1:-}"
  local match suffix
  while [[ "$text" =~ \$\{([1-9][0-9]*)([^}]*)\} ]]; do
    match="${BASH_REMATCH[0]}"
    suffix="${BASH_REMATCH[2]}"
    positional_suffix_guarded "$suffix" || return 0
    text="${text#*"$match"}"
  done
  return 1
}

positional_suffix_guarded() {
  case "${1:-}" in
    :-*) return 0 ;;
    -*) return 0 ;;
    :\?*) return 0 ;;
    \?*) return 0 ;;
  esac
  return 1
}

shell_comment_index() {
  local line="${1:-}"
  local index char in_single="0" in_double="0" escaped="0"
  for ((index = 0; index < ${#line}; index++)); do
    char="${line:index:1}"
    [[ "$escaped" == "1" ]] && escaped="0" && continue
    comment_escape_starts "$char" "$in_single" && escaped="1" && continue
    single_quote_opens "$char" "$in_double" && in_single="$(toggle_flag "$in_single")" && continue
    double_quote_opens "$char" "$in_single" && in_double="$(toggle_flag "$in_double")" && continue
    shell_comment_at "$line" "$index" "$char" "$in_single" "$in_double" && return
  done
  return 1
}

comment_escape_starts() {
  [[ "${1:-}" == "\\" ]] || return 1
  [[ "${2:-}" == "0" ]]
}

single_quote_opens() {
  [[ "${1:-}" == "'" ]] || return 1
  [[ "${2:-}" == "0" ]]
}

double_quote_opens() {
  [[ "${1:-}" == '"' ]] || return 1
  [[ "${2:-}" == "0" ]]
}

shell_comment_at() {
  local line="${1:-}"
  local index="${2:-0}"
  local char="${3:-}"
  local in_single="${4:-0}"
  local in_double="${5:-0}"
  [[ "$char" == "#" ]] || return 1
  [[ "$in_single$in_double" == "00" ]] || return 1
  comment_start_allowed "$line" "$index" || return 1
  printf '%s\n' "$index"
}

toggle_flag() {
  [[ "${1:-}" == "1" ]] && printf '%s\n' "0" && return
  printf '%s\n' "1"
}

comment_start_allowed() {
  local line="${1:-}"
  local index="${2:-0}"
  local previous
  (( index == 0 )) && return 0
  previous="${line:$((index - 1)):1}"
  [[ "$previous" =~ [[:space:]] ]] && return 0
  comment_starts_after_operator "$previous"
}

comment_starts_after_operator() {
  case "${1:-}" in
    ";"|"|"|"&") return 0 ;;
  esac
  return 1
}

shell_comment_ignored() {
  local index="${1:-0}"
  local body
  body="$(trim "${2:-}")"
  (( index == 0 )) && [[ "$body" == "!"* ]] && return 0
  shell_comment_directive "$body"
}

shell_comment_directive() {
  local body="${1:-}"
  body="${body,,}"
  [[ "$body" == shellcheck* ]] && return 0
  [[ "$body" == noqa* ]]
}

comment_allowed() {
  local body
  body="$(trim "${1:-}")"
  comment_matches_any_regex "$body" && return 0
  comment_has_prefix_identifier "$body" && return 0
  comment_has_suffix_identifier "$body"
}

comment_matches_any_regex() {
  local body="${1:-}"
  local matcher
  for matcher in "${COMMENT_MATCHERS[@]}"; do
    comment_matches_regex "$body" "$matcher" && return 0
  done
  return 1
}

comment_matches_regex() {
  local body="${1:-}"
  local matcher
  matcher="$(trim "${2:-}")"
  [[ -n "$matcher" ]] || return 1
  [[ "${body,,}" =~ ${matcher,,} ]]
}

comment_has_prefix_identifier() {
  local body="${1:-}"
  local identifier
  for identifier in "${COMMENT_PREFIX_IDENTIFIERS[@]}"; do
    comment_prefix_matches "$body" "$identifier" && return 0
  done
  return 1
}

comment_prefix_matches() {
  local body identifier remainder
  body="$(trim "${1:-}")"
  identifier="$(trim "${2:-}")"
  [[ -n "$identifier" ]] || return 1
  body="${body,,}"
  identifier="${identifier,,}"
  [[ "$body" == "$identifier"* ]] || return 1
  identifier_ends_word "$identifier" || return 0
  remainder="${body:${#identifier}:1}"
  identifier_boundary_char "$remainder"
}

comment_has_suffix_identifier() {
  local body="${1:-}"
  local identifier
  for identifier in "${COMMENT_SUFFIX_IDENTIFIERS[@]}"; do
    comment_suffix_matches "$body" "$identifier" && return 0
  done
  return 1
}

comment_suffix_matches() {
  local body identifier offset previous
  body="$(trim "${1:-}")"
  identifier="$(trim "${2:-}")"
  [[ -n "$identifier" ]] || return 1
  body="${body,,}"
  identifier="${identifier,,}"
  [[ "$body" == *"$identifier" ]] || return 1
  offset=$((${#body} - ${#identifier}))
  (( offset == 0 )) && return 0
  previous="${body:$((offset - 1)):1}"
  identifier_boundary_char "$previous"
}

identifier_ends_word() {
  local value="${1:-}"
  local last
  last="${value:$((${#value} - 1)):1}"
  [[ "$last" =~ [A-Za-z0-9_] ]]
}

identifier_boundary_char() {
  local char="${1:-}"
  [[ -z "$char" ]] && return 0
  [[ ! "$char" =~ [A-Za-z0-9_] ]]
}

condition_text() {
  local line="${1:-}"
  line="${line#if }"
  line="${line#elif }"
  line="${line#while }"
  line="${line#until }"
  line="${line%; then*}"
  line="${line%; do*}"
  printf '%s\n' "$line"
}

count_condition_operators() {
  local text="${1:-}"
  local count="0"
  count=$((count + $(count_occurrences "$text" "&&")))
  count=$((count + $(count_occurrences "$text" "||")))
  count=$((count + $(count_occurrences " $text " " -a ")))
  count=$((count + $(count_occurrences " $text " " -o ")))
  count=$((count + $(count_occurrences " $text " " ! ")))
  printf '%s\n' "$count"
}

count_expression_operators() {
  local line="${1:-}"
  local pipe_line count
  pipe_line="${line//||/}"
  pipe_line="${pipe_line//|&/}"
  count="0"
  count=$((count + $(count_occurrences "$line" "&&")))
  count=$((count + $(count_occurrences "$line" "||")))
  count=$((count + $(count_occurrences "$pipe_line" "|")))
  printf '%s\n' "$count"
}

line_starts_control() {
  local line="${1:-}"
  local word
  word="$(first_word "$line")"
  control_word "$word"
}

control_word() {
  case "${1:-}" in
    if) return 0 ;;
    elif) return 0 ;;
    while) return 0 ;;
    until) return 0 ;;
    for) return 0 ;;
    case) return 0 ;;
    else) return 0 ;;
    fi) return 0 ;;
    done) return 0 ;;
    "esac") return 0 ;;
  esac
  return 1
}

comparison_left_name() {
  local line="${1:-}"
  local condition
  condition="$(condition_text "$line")"
  comparison_left_name_from_condition "$condition"
}

comparison_left_name_from_condition() {
  local condition="${1:-}"
  local opener left operator
  read -r opener left operator _ <<< "$condition"
  comparison_opener_supported "$opener" || return
  comparison_operator_supported "$operator" || return
  printf '%s\n' "$left"
}

comparison_opener_supported() {
  case "${1:-}" in
    "[[") return 0 ;;
    "[") return 0 ;;
    "test") return 0 ;;
  esac
  return 1
}

comparison_operator_supported() {
  case "${1:-}" in
    "==") return 0 ;;
    "=") return 0 ;;
    "-eq") return 0 ;;
    "-ne") return 0 ;;
    "-lt") return 0 ;;
    "-le") return 0 ;;
    "-gt") return 0 ;;
    "-ge") return 0 ;;
  esac
  return 1
}

track_if_chain_comparison() {
  local path="${1:-$SCAN_PATH}"
  local line_number="${2:-$SCAN_LINE_NUMBER}"
  local line="${3:-$CURRENT_LINE_TEXT}"
  (( IF_DEPTH > 0 )) || return
  update_if_chain_count "$path" "$line_number" "$line"
}

update_if_chain_count() {
  local path="${1:-}"
  local line_number="${2:-}"
  local line="${3:-}"
  local next_name current_name
  next_name="$(comparison_left_name "$line")"
  current_name="${IF_COMPARE_NAME[$IF_DEPTH]}"
  [[ -z "$next_name" ]] && return
  [[ "$next_name" != "$current_name" ]] && return
  IF_COMPARE_COUNT[IF_DEPTH]=$((IF_COMPARE_COUNT[IF_DEPTH] + 1))
  maybe_report_if_chain "$path" "$line_number"
}

maybe_report_if_chain() {
  local path="${1:-}"
  local line_number="${2:-}"
  local count
  count="${IF_COMPARE_COUNT[$IF_DEPTH]}"
  (( count < MIN_CASE_CHAIN_LENGTH )) && return
  [[ "${IF_COMPARE_REPORTED[$IF_DEPTH]}" == "1" ]] && return
  report_if_chain "$path" "$line_number" "$count"
}

report_if_chain() {
  local path="${1:-}"
  local line_number="${2:-}"
  local count="${3:-}"
  local name message
  name="${IF_COMPARE_NAME[$IF_DEPTH]}"
  message="If chain compares $name $count times. Prefer a case statement."
  add_diag "$path" "$line_number" "1" "LEG034" "$message"
  IF_COMPARE_REPORTED[IF_DEPTH]="1"
}

direct_entry_from_line() {
  local line="${1:-}"
  local word
  for word in $line; do
    direct_entry_word "$word" && return
  done
}

direct_entry_word() {
  local word="${1:-}"
  [[ "$word" == -* ]] && return 1
  path_matches_any "$word" DIRECT_SHELL_ENTRY_PATTERNS || return 1
  printf '%s\n' "$word"
}

file_has_allowed_shebang() {
  local path="${1:-}"
  local first_line
  first_line="$(sed -n '1p' "$path" 2>/dev/null)"
  [[ "$first_line" == "#!"* ]] || return 1
  shell_runtime_allowed "${first_line#\#!}"
}

path_parent_depth() {
  local path="${1:-}"
  local normalized
  normalized="${path#./}"
  awk -F/ '{print NF-1}' <<< "$normalized"
}

filename_without_extension() {
  local path="${1:-}"
  local file
  file="$(basename "$path")"
  printf '%s\n' "${file%.*}"
}

filename_base() {
  local path="${1:-}"
  local name
  name="$(basename "$path")"
  name="${name#\.}"
  printf '%s\n' "${name%%.*}"
}

filename_base_allowed() {
  local base="${1:-}"
  local parent="${2:-}"
  [[ "$base" == "$parent" ]] && return 0
  filename_base_standalone "$base"
}

filename_base_standalone() {
  case "${1:-}" in
    index|constants|helpers|utils) return 0 ;;
  esac
  return 1
}

filename_casing_mixed() {
  local name="${1:-}"
  local has_hyphen has_underscore has_upper has_lower
  [[ "$name" == *-* ]] && has_hyphen="1" || has_hyphen="0"
  [[ "$name" == *_* ]] && has_underscore="1" || has_underscore="0"
  [[ "$name" =~ [A-Z] ]] && has_upper="1" || has_upper="0"
  [[ "$name" =~ [a-z] ]] && has_lower="1" || has_lower="0"
  filename_casing_flags_mixed "$has_hyphen" "$has_underscore" "$has_upper" "$has_lower"
}

filename_casing_flags_mixed() {
  local has_hyphen="${1:-}"
  local has_underscore="${2:-}"
  local has_upper="${3:-}"
  local has_lower="${4:-}"
  casing_mixes_separators "$has_hyphen" "$has_underscore" && return 0
  casing_mixes_separator_with_case "$has_hyphen" "$has_underscore" "$has_upper" "$has_lower"
}

casing_mixes_separators() {
  local has_hyphen="${1:-}"
  local has_underscore="${2:-}"
  [[ "$has_hyphen" == "1" ]] || return 1
  [[ "$has_underscore" == "1" ]]
}

casing_mixes_separator_with_case() {
  local has_hyphen="${1:-}"
  local has_underscore="${2:-}"
  local has_upper="${3:-}"
  local has_lower="${4:-}"
  [[ "$has_upper" == "1" ]] || return 1
  [[ "$has_lower" == "1" ]] || return 1
  [[ "$has_hyphen$has_underscore" != "00" ]]
}

has_bool_literal_arg() {
  local line="${1:-}"
  line_contains_word "$line" "true" && return 0
  line_contains_word "$line" "false"
}

line_contains_word() {
  local line="${1:-}"
  local word="${2:-}"
  local padded
  padded=" $line "
  [[ "$padded" == *" $word "* ]]
}

add_diag() {
  local path="${1:-}"
  local line="${2:-}"
  local column="${3:-}"
  local code="${4:-}"
  local message="${5:-}"
  rule_enabled "$code" || return
  line_ignores_code "$CURRENT_LINE_TEXT" "$code" && return
  append_diag "$path" "$line" "$column" "$code" "$message"
}

append_diag() {
  local path="${1:-}"
  local line="${2:-}"
  local column="${3:-}"
  local code="${4:-}"
  local message="${5:-}"
  DIAG_PATHS+=("$path")
  DIAG_LINES+=("$line")
  DIAG_COLUMNS+=("$column")
  DIAG_CODES+=("$code")
  DIAG_RULES+=("$(rule_name "$code")")
  DIAG_MESSAGES+=("$message")
}
