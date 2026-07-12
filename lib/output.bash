write_diagnostics() {
  [[ "$OUTPUT_FORMAT" == "json" ]] && write_json_diagnostics
  [[ "$OUTPUT_FORMAT" == "json" ]] && return
  write_text_diagnostics
}

write_text_diagnostics() {
  local index
  for index in "${!DIAG_CODES[@]}"; do
    write_text_diagnostic "$index"
  done
}

write_text_diagnostic() {
  local index="$1"
  printf '%s:%s:%s: %s %s\n' \
    "${DIAG_PATHS[$index]}" \
    "${DIAG_LINES[$index]}" \
    "${DIAG_COLUMNS[$index]}" \
    "${DIAG_CODES[$index]}" \
    "${DIAG_MESSAGES[$index]}"
}

write_json_diagnostics() {
  local index separator
  printf '[\n'
  separator=""
  for index in "${!DIAG_CODES[@]}"; do
    write_json_diagnostic "$index" "$separator"
    separator=$',\n'
  done
  printf '\n]\n'
}

write_json_diagnostic() {
  local index="$1"
  local separator="$2"
  printf '%s  {' "$separator"
  write_json_fields "$index"
  printf '}'
}

write_json_fields() {
  local index="$1"
  printf '"path":"%s",' "$(json_escape "${DIAG_PATHS[$index]}")"
  printf '"line":%s,' "${DIAG_LINES[$index]}"
  printf '"column":%s,' "${DIAG_COLUMNS[$index]}"
  printf '"code":"%s",' "${DIAG_CODES[$index]}"
  printf '"rule":"%s",' "$(json_escape "${DIAG_RULES[$index]}")"
  printf '"message":"%s"' "$(json_escape "${DIAG_MESSAGES[$index]}")"
}
