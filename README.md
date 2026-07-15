# shellcheck-readability

Shell readability checks that sit beside ShellCheck.

ShellCheck should own correctness, portability, quoting, and shell semantics. This project focuses on reviewability: control-flow depth, operator-heavy expressions, long functions, function-first script shape, defaulted function args, repeated comparisons, direct shell smoke tests, and patterns that make scripts harder to scan.

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
comment-matchers = []
comment-prefix-identifiers = []
comment-suffix-identifiers = []
```

Selectors use the same model as the other legibility tools: `select`, `ignore`, rule codes, rule names, and `LEG`.

## Implemented Rules

Only implemented rules are listed here. Each rule links to its do / don't diff example.

| Code | Rule | Summary |
| --- | --- | --- |
| [`LEG001`](#max-expression-operators-diff) | `max-expression-operators` | Limit `&&`, `||`, and pipeline-heavy shell expressions. |
| [`LEG002`](#hoist-if-operators-diff) | `hoist-if-operators` | Prefer named checks before operator-heavy conditions. |
| [`LEG003`](#max-control-flow-depth-diff) | `max-control-flow-depth` | Limit nested control flow. |
| [`LEG005`](#no-quadratic-patterns-diff) | `no-quadratic-patterns` | Flag nested loops. |
| [`LEG009`](#prefer-early-return-diff) | `prefer-early-return` | Avoid `else` after a branch exits. |
| [`LEG010`](#prefer-guard-clauses-diff) | `prefer-guard-clauses` | Prefer guard clauses inside functions. |
| [`LEG016`](#require-executable-shebang-diff) | `require-executable-shebang` | Require executable shell entries to have a shebang. |
| [`LEG017`](#no-direct-shell-bin-smoke-diff) | `no-direct-shell-bin-smoke` | Prefer installed-command smoke tests over direct shell entry files. |
| [`LEG024`](#prefer-object-lookup-diff) | `prefer-object-lookup` | Prefer `case` or lookup-style flow over repeated equality checks. |
| [`LEG025`](#require-filename-matches-dirname-diff) | `require-filename-matches-dirname` | Require files in named subdirectories to match the directory name. |
| [`LEG026`](#no-mixed-filename-casing-diff) | `no-mixed-filename-casing` | Avoid filenames that mix casing conventions. |
| [`LEG034`](#prefer-case-over-long-if-chain-diff) | `prefer-case-over-long-if-chain` | Prefer `case` over long `elif` chains comparing the same value. |
| [`LEG035`](#no-bool-literal-args-diff) | `no-bool-literal-args` | Avoid boolean literal arguments. |
| [`LEG038`](#max-function-lines-diff) | `max-function-lines` | Keep shell functions within a focused line budget. |
| [`LEG039`](#prefer-functions-diff) | `prefer-functions` | Prefer named functions over top-level script logic. |
| [`LEG040`](#use-defaults-in-functions-diff) | `use-defaults-in-functions` | Use defaulted or guarded positional args in functions. |
| [`LEG041`](#no-unmatched-comments-diff) | `no-unmatched-comments` | Require comments to match configured ownership markers. |

---

<a id="max-expression-operators"></a>

### `max-expression-operators`

Limit readable operators inside a single command expression.

#### options

- `max-expression-operators`: allowed expression operators. Default: `4`.

<a id="max-expression-operators-diff"></a>

#### do / don't

```diff
- build && test && package && publish && notify
+ build
+ test
+ package
+ publish
+ notify
```

---

<a id="hoist-if-operators"></a>

### `hoist-if-operators`

Prefer a named check before an operator-heavy `if`, `elif`, `while`, or `until` condition.

#### options

- `max-if-operators`: allowed condition operators. Default: `0`.

<a id="hoist-if-operators-diff"></a>

#### do / don't

```diff
- if [[ -n "$user" && -n "$email" ]]; then
+ user_has_contact() {
+   [[ -n "$user" && -n "$email" ]]
+ }
+
+ if user_has_contact; then
    send_invite "$user"
  fi
```

---

<a id="max-control-flow-depth"></a>

### `max-control-flow-depth`

Limit nested branches and loops so the main path stays easy to scan.

#### options

- `max-control-flow-depth`: allowed nested control-flow depth. Default: `3`.

<a id="max-control-flow-depth-diff"></a>

#### do / don't

```diff
- if [[ -n "$repo" ]]; then
-   if git diff --quiet; then
-     if [[ "$target" == "release" ]]; then
-       publish_release
-     fi
-   fi
- fi
+ [[ -n "$repo" ]] || exit 1
+ git diff --quiet || exit 1
+ [[ "$target" == "release" ]] || exit 0
+ publish_release
```

---

<a id="no-quadratic-patterns"></a>

### `no-quadratic-patterns`

Flag nested loops that are likely to become repeated scans.

#### options

None.

<a id="no-quadratic-patterns-diff"></a>

#### do / don't

```diff
- for user in "${users[@]}"; do
-   for owner in "${owners[@]}"; do
-     [[ "$user" == "$owner" ]] && print_owner "$user"
-   done
- done
+ declare -A owner_lookup=()
+ for owner in "${owners[@]}"; do
+   owner_lookup["$owner"]="1"
+ done
+ for user in "${users[@]}"; do
+   [[ -n "${owner_lookup[$user]:-}" ]] && print_owner "$user"
+ done
```

---

<a id="prefer-early-return"></a>

### `prefer-early-return`

Avoid an `else` branch after the previous branch already exits.

#### options

None.

<a id="prefer-early-return-diff"></a>

#### do / don't

```diff
  if [[ -z "$config" ]]; then
    return 1
- else
-   load_config "$config"
  fi
+ load_config "$config"
```

---

<a id="prefer-guard-clauses"></a>

### `prefer-guard-clauses`

Prefer guard clauses over wrapping a whole function body in one branch.

#### options

None.

<a id="prefer-guard-clauses-diff"></a>

#### do / don't

```diff
  deploy() {
-   if [[ -n "$target" ]]; then
-     build
-     upload "$target"
-   fi
+   [[ -n "$target" ]] || return 1
+   build
+   upload "$target"
  }
```

---

<a id="require-executable-shebang"></a>

### `require-executable-shebang`

Require configured executable entry files to start with an accepted shell shebang.

#### options

- `executable-entry-patterns`: paths treated as executable shell entries.
- `executable-runtimes`: accepted shebang runtimes. Default includes Bash, sh, zsh, and ksh.

<a id="require-executable-shebang-diff"></a>

#### do / don't

```diff
+ #!/usr/bin/env bash
+
  set -u
  main "$@"
```

---

<a id="no-direct-shell-bin-smoke"></a>

### `no-direct-shell-bin-smoke`

Prefer smoke-testing the installed command instead of invoking entry scripts directly with a shell.

#### options

- `direct-shell-entry-patterns`: direct entry paths that should not be shell-invoked in smoke tests.
- `executable-runtimes`: shell runtimes checked in commands.

<a id="no-direct-shell-bin-smoke-diff"></a>

#### do / don't

```diff
- bash bin/shellcheck-readability --version
+ shellcheck-readability --version
```

---

<a id="prefer-object-lookup"></a>

### `prefer-object-lookup`

Prefer `case` or lookup-style flow over long repeated equality checks.

#### options

- `min-object-lookup-chain-length`: repeated checks before reporting. Default: `3`.

<a id="prefer-object-lookup-diff"></a>

#### do / don't

```diff
- if [[ "$mode" == "dev" || "$mode" == "test" || "$mode" == "ci" ]]; then
-   enable_debug
- fi
+ case "$mode" in
+   dev|test|ci) enable_debug ;;
+ esac
```

---

<a id="require-filename-matches-dirname"></a>

### `require-filename-matches-dirname`

Require files in named subdirectories to match the directory name.

#### options

- `min-dirname-match-depth`: minimum parent depth before checking. Default: `3`.

<a id="require-filename-matches-dirname-diff"></a>

#### do / don't

```diff
- scripts/deploy/run.sh
+ scripts/deploy/deploy.sh
```

---

<a id="no-mixed-filename-casing"></a>

### `no-mixed-filename-casing`

Avoid filenames that mix casing conventions.

#### options

None.

<a id="no-mixed-filename-casing-diff"></a>

#### do / don't

```diff
- scripts/deployUser.sh
+ scripts/deploy-user.sh
```

---

<a id="prefer-case-over-long-if-chain"></a>

### `prefer-case-over-long-if-chain`

Prefer `case` over long `elif` chains comparing the same value.

#### options

- `min-case-chain-length`: repeated comparisons before reporting. Default: `3`.

<a id="prefer-case-over-long-if-chain-diff"></a>

#### do / don't

```diff
- if [[ "$command" == "build" ]]; then
-   build
- elif [[ "$command" == "test" ]]; then
-   test_all
- elif [[ "$command" == "publish" ]]; then
-   publish
- fi
+ case "$command" in
+   build) build ;;
+   test) test_all ;;
+   publish) publish ;;
+ esac
```

---

<a id="no-bool-literal-args"></a>

### `no-bool-literal-args`

Avoid boolean literal arguments whose meaning is only clear at the call site.

#### options

None.

<a id="no-bool-literal-args-diff"></a>

#### do / don't

```diff
- create_user "$name" true false
+ send_email="true"
+ is_admin="false"
+ create_user "$name" "$send_email" "$is_admin"
```

---

<a id="max-function-lines"></a>

### `max-function-lines`

Keep shell functions within a focused line budget.

#### options

- `max-function-lines`: maximum lines in a function. Default: `20`.

<a id="max-function-lines-diff"></a>

#### do / don't

```diff
  deploy() {
-   validate_env
-   install_dependencies
-   build_assets
-   upload_assets
-   restart_service
-   notify_release
+   prepare_release
+   publish_release
+   notify_release
  }
```

---

<a id="prefer-functions"></a>

### `prefer-functions`

Prefer named functions for script logic and keep top-level code limited to setup and dispatch.

#### options

None.

<a id="prefer-functions-diff"></a>

#### do / don't

```diff
- docker build --tag "$IMAGE_NAME" .
- docker run --rm "$IMAGE_NAME"
+ main() {
+   docker build --tag "$IMAGE_NAME" .
+   docker run --rm "$IMAGE_NAME"
+ }
+
+ main "$@"
```

---

<a id="use-defaults-in-functions"></a>

### `use-defaults-in-functions`

Use default or required-argument expansions when binding function positional parameters.

#### options

None.

<a id="use-defaults-in-functions-diff"></a>

#### do / don't

```diff
  deploy() {
-   local target="$1"
+   local target="${1:-staging}"
    upload "$target"
  }
```

---

<a id="no-unmatched-comments"></a>

### `no-unmatched-comments`

Reject comments that do not match a configured regular-expression matcher, prefix identifier, or suffix identifier.

Shebangs, ShellCheck directives, and `noqa` directives are ignored. No matcher or identifier is configured by default, so selecting this rule rejects ordinary comments.

#### options

- `comment-matchers`: case-insensitive Bash regular expressions matched anywhere in the comment body. Default: `[]`.
- `comment-prefix-identifiers`: case-insensitive literal identifiers matched at the start of the trimmed comment body. Default: `[]`.
- `comment-suffix-identifiers`: case-insensitive literal identifiers matched at the end of the trimmed comment body. Default: `[]`.

<a id="no-unmatched-comments-diff"></a>

#### do / don't

```diff
- # explain this branch
+ require_target
```

With `HUMAN` as an allowed prefix identifier:

```diff
- # preserve the legacy response order
+ # HUMAN: preserve the legacy response order
```

## Rule Function Testing

Rule functions are named after the lint checks and accept optional values, so tests can call them directly:

```sh
check_hoist_if_operators "example.sh" "4" 'if [[ -n "$user" && -n "$email" ]]; then'
check_max_expression_operators "example.sh" "7" 'build && test && package'
check_no_bool_literal_args "example.sh" "9" 'create_user "$name" true false'
check_prefer_functions "example.sh" "5" "docker build ."
check_use_defaults_in_functions "example.sh" "6" 'local target="$1"'
check_no_unmatched_comments "example.sh" "4" "# explain this branch"
```

## Tests

```sh
make unit
make e2e
make check
```
