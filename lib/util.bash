trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s\n' "$value"
}

strip_comment() {
  local line="$1"
  printf '%s\n' "${line%%#*}"
}

clean_scalar() {
  local value="$1"
  value="$(trim "$value")"
  value="${value//\"/}"
  value="${value//\'/}"
  printf '%s\n' "$value"
}

clean_list() {
  local value="$1"
  value="${value#[}"
  value="${value%]}"
  value="${value//\"/}"
  value="${value//\'/}"
  printf '%s\n' "$value"
}

csv_to_array() {
  local array_name="$1"
  local raw="$2"
  local cleaned
  cleaned="$(clean_list "$raw")"
  IFS=',' read -r -a __parts <<< "$cleaned"
  append_csv_parts "$array_name" "${__parts[@]}"
}

append_csv_parts() {
  local array_name="$1"
  shift
  local part
  local -n target_ref="$array_name"
  for part in "$@"; do
    part="$(trim "$part")"
    [[ -z "$part" ]] && continue
    target_ref+=("$part")
  done
}

count_occurrences() {
  local text="$1"
  local needle="$2"
  local count="0"
  while [[ "$text" == *"$needle"* ]]; do
    text="${text#*"$needle"}"
    count=$((count + 1))
  done
  printf '%s\n' "$count"
}

json_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  printf '%s\n' "$value"
}

first_word() {
  local line="$1"
  local first
  read -r first _ <<< "$line"
  printf '%s\n' "$first"
}

path_matches_any() {
  local path="$1"
  local array_name="$2"
  local pattern
  local -n patterns_ref="$array_name"
  path="${path#./}"
  for pattern in "${patterns_ref[@]}"; do
    # shellcheck disable=SC2053
    [[ "$path" == $pattern ]] && return 0
  done
  return 1
}
