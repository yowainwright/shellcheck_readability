LIST_ARRAY_NAME=""
LIST_ITEM=""
LIST_IN_SINGLE_QUOTE="0"
LIST_IN_DOUBLE_QUOTE="0"
LIST_ESCAPED="0"

trim() {
  local value="${1:-}"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s\n' "$value"
}

strip_comment() {
  local line="${1:-}"
  printf '%s\n' "${line%%#*}"
}

clean_scalar() {
  local value="${1:-}"
  value="$(trim "$value")"
  value="${value//\"/}"
  value="${value//\'/}"
  printf '%s\n' "$value"
}

csv_to_array() {
  local array_name="${1:-}"
  local raw="${2:-}"
  local value index
  reset_list_parser "$array_name"
  value="$(trim "$raw")"
  value="${value#[}"
  value="${value%]}"
  for ((index = 0; index < ${#value}; index++)); do
    consume_list_character "${value:index:1}"
  done
  append_list_item
}

reset_list_parser() {
  LIST_ARRAY_NAME="${1:-}"
  LIST_ITEM=""
  LIST_IN_SINGLE_QUOTE="0"
  LIST_IN_DOUBLE_QUOTE="0"
  LIST_ESCAPED="0"
}

consume_list_character() {
  local char="${1:-}"
  list_escaped_character "$char" && return
  list_escape_starts "$char" && return
  list_single_quote_toggles "$char" && return
  list_double_quote_toggles "$char" && return
  list_separator_consumed "$char" && return
  LIST_ITEM+="$char"
}

list_escaped_character() {
  local char="${1:-}"
  [[ "$LIST_ESCAPED" == "1" ]] || return 1
  LIST_ITEM+="$char"
  LIST_ESCAPED="0"
}

list_escape_starts() {
  local char="${1:-}"
  [[ "$char" == "\\" ]] || return 1
  [[ "$LIST_IN_DOUBLE_QUOTE" == "1" ]] || return 1
  LIST_ITEM+="$char"
  LIST_ESCAPED="1"
}

list_single_quote_toggles() {
  [[ "${1:-}" == "'" ]] || return 1
  [[ "$LIST_IN_DOUBLE_QUOTE" == "0" ]] || return 1
  LIST_IN_SINGLE_QUOTE=$((1 - LIST_IN_SINGLE_QUOTE))
}

list_double_quote_toggles() {
  [[ "${1:-}" == '"' ]] || return 1
  [[ "$LIST_IN_SINGLE_QUOTE" == "0" ]] || return 1
  LIST_IN_DOUBLE_QUOTE=$((1 - LIST_IN_DOUBLE_QUOTE))
}

list_separator_consumed() {
  [[ "${1:-}" == "," ]] || return 1
  [[ "$LIST_IN_SINGLE_QUOTE$LIST_IN_DOUBLE_QUOTE" == "00" ]] || return 1
  append_list_item
}

append_list_item() {
  local value
  local -n target_ref="$LIST_ARRAY_NAME"
  value="$(trim "$LIST_ITEM")"
  LIST_ITEM=""
  [[ -z "$value" ]] && return
  target_ref+=("$value")
}

count_occurrences() {
  local text="${1:-}"
  local needle="${2:-}"
  local count="0"
  while [[ "$text" == *"$needle"* ]]; do
    text="${text#*"$needle"}"
    count=$((count + 1))
  done
  printf '%s\n' "$count"
}

json_escape() {
  local value="${1:-}"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  printf '%s\n' "$value"
}

first_word() {
  local line="${1:-}"
  local first
  read -r first _ <<< "$line"
  printf '%s\n' "$first"
}

path_matches_any() {
  local path="${1:-}"
  local array_name="${2:-}"
  local pattern
  local -n patterns_ref="$array_name"
  path="${path#./}"
  for pattern in "${patterns_ref[@]}"; do
    # shellcheck disable=SC2053
    [[ "$path" == $pattern ]] && return 0
  done
  return 1
}
