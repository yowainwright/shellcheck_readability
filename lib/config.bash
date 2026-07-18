# shellcheck shell=bash
# shellcheck disable=SC2034

load_config() {
  local path
  path="$(resolve_config_path)"
  [[ -z "$path" ]] && return
  read_config_file "$path"
}

resolve_config_path() {
  [[ -n "$CONFIG_PATH" ]] && printf '%s\n' "$CONFIG_PATH" && return
  search_config_upward
}

search_config_upward() {
  local dir
  dir="$PWD"
  while [[ "$dir" != "/" ]]; do
    config_in_dir "$dir" && return
    dir="$(dirname "$dir")"
  done
}

config_in_dir() {
  local dir="${1:-}"
  print_existing "$dir/shellcheck-readability.toml" && return 0
  print_existing "$dir/.shellcheck-readability.toml" && return 0
  print_existing "$dir/pyproject.toml"
}

print_existing() {
  [[ -f "${1:-}" ]] || return 1
  printf '%s\n' "${1:-}"
}

read_config_file() {
  local path="${1:-}"
  local in_section
  in_section="$(initial_config_section "$path")"
  read_config_lines "$path" "$in_section"
}

initial_config_section() {
  local path="${1:-}"
  [[ "$(basename "$path")" == "pyproject.toml" ]] && printf '%s\n' "0" && return
  printf '%s\n' "1"
}

read_config_lines() {
  local path="${1:-}"
  local in_section="${2:-}"
  local line
  local -a lines
  mapfile -t lines < "$path"
  for line in "${lines[@]}"; do
    process_config_line "$line" "$in_section"
    in_section="$CONFIG_IN_SECTION"
  done
}

process_config_line() {
  local line="${1:-}"
  CONFIG_IN_SECTION="${2:-}"
  line="$(strip_comment "$line")"
  line="$(trim "$line")"
  [[ -z "$line" ]] && return
  process_config_content "$line"
}

process_config_content() {
  local line="${1:-}"
  [[ "$line" == \[*\] ]] || apply_config_content_assignment "$line"
  [[ "$line" == \[*\] ]] || return
  update_config_section "$line"
}

apply_config_content_assignment() {
  local line="${1:-}"
  [[ "$CONFIG_IN_SECTION" == "1" ]] && apply_config_assignment "$line"
}

update_config_section() {
  CONFIG_IN_SECTION="0"
  [[ "${1:-}" == "[tool.shellcheck-readability]" ]] && CONFIG_IN_SECTION="1"
}

apply_config_assignment() {
  local line="${1:-}"
  local key value
  key="$(trim "${line%%=*}")"
  value="$(trim "${line#*=}")"
  apply_config_value "$key" "$value"
}

apply_config_value() {
  local key="${1:-}"
  local value="${2:-}"
  apply_core_config_value "$key" "$value" && return
  apply_shell_config_value "$key" "$value" && return
  apply_comment_config_value "$key" "$value"
}

apply_core_config_value() {
  local key="${1:-}"
  local value="${2:-}"
  case "$key" in
    select) reset_array_from_csv SELECT "$value" ;;
    ignore) reset_array_from_csv IGNORE "$value" ;;
    exclude) reset_array_from_csv EXCLUDE "$value" ;;
    max-expression-operators) MAX_EXPRESSION_OPERATORS="$(clean_scalar "$value")" ;;
    max-if-operators) MAX_CONDITION_OPERATORS="$(clean_scalar "$value")" ;;
    max-control-flow-depth) MAX_CONTROL_FLOW_DEPTH="$(clean_scalar "$value")" ;;
    max-function-lines) MAX_FUNCTION_LINES="$(clean_scalar "$value")" ;;
    min-case-chain-length) MIN_CASE_CHAIN_LENGTH="$(clean_scalar "$value")" ;;
    min-object-lookup-chain-length) MIN_OBJECT_LOOKUP_CHAIN_LENGTH="$(clean_scalar "$value")" ;;
    min-dirname-match-depth) MIN_DIRNAME_MATCH_DEPTH="$(clean_scalar "$value")" ;;
    *) return 1 ;;
  esac
}

apply_shell_config_value() {
  local key="${1:-}"
  local value="${2:-}"
  case "$key" in
    executable-entry-patterns) reset_array_from_csv EXECUTABLE_ENTRY_PATTERNS "$value" ;;
    direct-shell-entry-patterns) reset_array_from_csv DIRECT_SHELL_ENTRY_PATTERNS "$value" ;;
    executable-runtimes) reset_array_from_csv EXECUTABLE_RUNTIMES "$value" ;;
    *) return 1 ;;
  esac
}

apply_comment_config_value() {
  local key="${1:-}"
  local value="${2:-}"
  case "$key" in
    comment-matchers) reset_array_from_csv COMMENT_MATCHERS "$value" ;;
    comment-prefix-identifiers) reset_array_from_csv COMMENT_PREFIX_IDENTIFIERS "$value" ;;
    comment-suffix-identifiers) reset_array_from_csv COMMENT_SUFFIX_IDENTIFIERS "$value" ;;
    automated-comment-identifiers) reset_array_from_csv AUTOMATED_COMMENT_IDENTIFIERS "$value" ;;
    *) return 1 ;;
  esac
}

reset_array_from_csv() {
  local array_name="${1:-}"
  local value="${2:-}"
  eval "$array_name=()"
  csv_to_array "$array_name" "$value"
}
