# shellcheck-readability

Shell readability checks that sit beside ShellCheck.

ShellCheck should own correctness, portability, quoting, and shell semantics. This project focuses on reviewability: control-flow depth, operator-heavy expressions, long functions, repeated comparisons, direct shell smoke tests, and patterns that make scripts harder to scan.

Requires Bash 4.3 or newer. ShellCheck is a development lint dependency, not a runtime dependency.

## Install

```sh
brew tap yowainwright/shellcheck_readability
brew install --HEAD shellcheck-readability
```

## Use

```sh
bin/shellcheck-readability check scripts tests
bin/shellcheck-readability check . --select LEG001,LEG002 --ignore LEG038
bin/shellcheck-readability check . --output-format json
```

## Configuration

Configuration can live in `shellcheck-readability.toml`, `.shellcheck-readability.toml`, or `[tool.shellcheck-readability]` in `pyproject.toml`.

```toml
max-expression-operators = 4
max-if-operators = 0
max-control-flow-depth = 3
max-function-lines = 20
min-case-chain-length = 3
min-object-lookup-chain-length = 3
min-dirname-match-depth = 3
```

Selectors use the same model as the other legibility tools: `select`, `ignore`, rule codes, rule names, and `LEG`.

## Rules

| Code | Rule | Summary |
| --- | --- | --- |
| `LEG001` | `max-expression-operators` | Limit `&&`, `||`, and pipeline-heavy shell expressions. |
| `LEG002` | `hoist-if-operators` | Prefer named checks before operator-heavy conditions. |
| `LEG003` | `max-control-flow-depth` | Limit nested control flow. |
| `LEG005` | `no-quadratic-patterns` | Flag nested loops. |
| `LEG009` | `prefer-early-return` | Avoid `else` after a branch exits. |
| `LEG010` | `prefer-guard-clauses` | Prefer guard clauses inside functions. |
| `LEG016` | `require-executable-shebang` | Require executable shell entries to have a shebang. |
| `LEG017` | `no-direct-shell-bin-smoke` | Prefer installed-command smoke tests over direct shell entry files. |
| `LEG024` | `prefer-object-lookup` | Prefer `case` or lookup-style flow over repeated equality checks. |
| `LEG025` | `require-filename-matches-dirname` | Require files in named subdirectories to match the directory name. |
| `LEG026` | `no-mixed-filename-casing` | Avoid filenames that mix casing conventions. |
| `LEG034` | `prefer-case-over-long-if-chain` | Prefer `case` over long `elif` chains comparing the same value. |
| `LEG035` | `no-bool-literal-args` | Avoid boolean literal arguments. |
| `LEG038` | `max-function-lines` | Keep shell functions within a focused line budget. |

## Rule Function Testing

Rule functions are named after the lint checks and accept optional values, so tests can call them directly:

```sh
check_hoist_if_operators "example.sh" "4" 'if [[ -n "$user" && -n "$email" ]]; then'
check_max_expression_operators "example.sh" "7" 'build && test && package'
check_no_bool_literal_args "example.sh" "9" 'create_user "$name" true false'
```

## Tests

```sh
make unit
make e2e
make check
```
