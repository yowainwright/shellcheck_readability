# shellcheck disable=SC2034

main() {
  init_defaults
  maybe_shift_check "$@"
  set -- "${SHIFTED_ARGS[@]}"
  parse_args "$@"
  load_config
  apply_cli_overrides
  expand_targets
  lint_files
  write_diagnostics
  exit_for_diagnostics
}

maybe_shift_check() {
  SHIFTED_ARGS=("$@")
  [[ "${SHIFTED_ARGS[0]:-}" != "check" ]] && return
  SHIFTED_ARGS=("${SHIFTED_ARGS[@]:1}")
}

parse_args() {
  while [[ "$#" -gt 0 ]]; do
    parse_one_arg "$@"
    shift "$ARG_SHIFT"
  done
}

parse_one_arg() {
  ARG_SHIFT="1"
  case "$1" in
    --config) CONFIG_PATH="${2:-}"; ARG_SHIFT="2" ;;
    --config=*) CONFIG_PATH="${1#*=}" ;;
    --output-format) OUTPUT_FORMAT="${2:-}"; ARG_SHIFT="2" ;;
    --output-format=*) OUTPUT_FORMAT="${1#*=}" ;;
    --select) CLI_SELECT="${2:-}"; ARG_SHIFT="2" ;;
    --select=*) CLI_SELECT="${1#*=}" ;;
    --ignore) CLI_IGNORE="${2:-}"; ARG_SHIFT="2" ;;
    --ignore=*) CLI_IGNORE="${1#*=}" ;;
    --exit-zero) EXIT_ZERO="1" ;;
    --version) printf '%s\n' "$VERSION"; exit 0 ;;
    -h|--help) usage; exit 0 ;;
    -*) unknown_option "$1" ;;
    *) TARGETS+=("$1") ;;
  esac
}

unknown_option() {
  printf 'unknown option: %s\n' "$1" >&2
  usage >&2
  exit 2
}

usage() {
  printf '%s\n' "Usage: shellcheck-readability check [paths...] [options]"
}

apply_cli_overrides() {
  [[ -n "$CLI_SELECT" ]] && reset_array_from_csv SELECT "$CLI_SELECT"
  [[ -n "$CLI_IGNORE" ]] && reset_array_from_csv IGNORE "$CLI_IGNORE"
  validate_output_format
}

validate_output_format() {
  [[ "$OUTPUT_FORMAT" == "text" ]] && return
  [[ "$OUTPUT_FORMAT" == "json" ]] && return
  printf '%s\n' "output format must be text or json" >&2
  exit 2
}

exit_for_diagnostics() {
  [[ "${#DIAG_CODES[@]}" -eq 0 ]] && return
  [[ "$EXIT_ZERO" == "1" ]] && return
  return 1
}
