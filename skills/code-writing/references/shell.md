# Shell

Shell is the right language for orchestrating processes, wiring tools together and short installers. When the logic needs real data structures, parsing or more than a screenful of branching, it belongs in one of the other languages.

## Bash version

Where a script runs decides the bash it may use.

- **Runs on a developer's machine, or might** — dev scripts, installers, git hooks, task-runner tasks, anything a README tells someone to run: bash 3.2-compatible. macOS ships `/bin/bash` 3.2, and `#!/usr/bin/env bash` resolves to it unless the developer installed a newer bash; git hooks, GUI tools and launchd jobs often run with a minimal `PATH` and get 3.2 regardless.
- **Runs only where the image controls bash** — Linux CI steps, container entrypoints: bash 5, guarded at the top so a local run fails with a clear message instead of a syntax error:

  ```bash
  if ((BASH_VERSINFO[0] < 5)); then
    echo "tool: needs bash 5 (found $BASH_VERSION); run it in CI or install a newer bash" >&2
    exit 1
  fi
  ```

- **Unsure** counts as a developer's machine, and so does a CI script that has a local test.

A developer-machine script that wants more than 3.2 offers should be written in another language. Where bash 5 is guaranteed, use what it adds instead of the older workaround: `mapfile -t arr < <(cmd)`, associative arrays, `[[ -v var ]]`, `${v@Q}`, `local -`, `shopt -s inherit_errexit`, `wait -n`, `$EPOCHSECONDS`.

## Toolchain

- `shellcheck` lints every tracked shell file, including extensionless scripts, found by shebang rather than a hand-kept list, so a new script is covered without editing anything. Block on warnings and errors:

  ```bash
  git ls-files -z | while IFS= read -r -d '' f; do
    case "$f" in
      *.sh) printf '%s\0' "$f" ;;
      *) head -1 "$f" 2>/dev/null | grep -Eq '^#!.*(/| )(ba|da|k)?sh([[:space:]]|$)' && printf '%s\0' "$f" ;;
    esac
  done | xargs -0 shellcheck --severity=warning
  ```

- Point shellcheck at sourced files (`# shellcheck source=lib/common.sh`, or `source-path=SCRIPTDIR` in `.shellcheckrc`) rather than disabling SC1091.
- `shfmt` formats with the repo's settings (`-i 2` where there are none), run on each written file.

## Layout

- Executables start `#!/usr/bin/env bash` and carry no extension; a library meant to be sourced ends in `.sh` and sets no shell options, so it does not change its caller's shell. `#!/bin/sh` only for a strictly POSIX script.
- `--help` prints usage, prerequisites and exit statuses.
- Code lives in functions, with `main "$@"` as the last line. A script a test sources guards its entry point: `(return 0 2>/dev/null) && return`, then strict mode, then `main "$@"`, so strict mode stays out of the test that sources it.
- The script's own directory comes from `"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`, never `$0` or the working directory.
- Long options are parsed with a `while (($#)); do case "$1" in … esac; done` loop; `getopts` has no long options.
- Function variables are `local`, declared on one line and assigned on the next when the value comes from a command.
- Errors go through one `die` helper.

## Strictness

- **Linear scripts** use `set -euo pipefail`; **checkers and test runners** that must report every failure use `set -uo pipefail` and exit from a failure count.
- **A hook or observer that must never block** what it observes traps its own errors, exits 0, and records the degradation where someone will see it.
- A guard never relies on `set -e`: test the command and return explicitly. A failure that is acceptable is tested (`if ! cmd; then …`), not hidden by `|| true`.
- Optional variables are read as `${VAR:-}` under `set -u`.

## Errors and exit status

- Diagnostics go to stderr as `tool: message`; the result goes to stdout. When a caller or test must tell failures apart, the message carries a stable code after the tool name (`tool: checksum-mismatch: …`).
- Exit statuses follow [Command-line programs](../SKILL.md#command-line-programs).
- Required input is checked first, `: "${VAR:?VAR is required}"`, and every argument problem is reported at once.
- A prerequisite is checked by running it (`jq --version`), not only by `command -v`, and a missing one is named. Never `which`.

## Safe changes

- Check every precondition before the first mutation, so a failed run leaves the machine as it found it.
- A second run finds the work done and says so rather than redoing it or failing.
- A file is written to a temporary file in the same directory and moved into place.
- Anything that becomes a path component is validated, then canonicalized.
- Never `eval`, and never build a command string from input; pass values as quoted arguments.
- Downloads use `curl -fsSL --max-time N`, and a checksum is verified before anything downloaded runs. Never pipe a download into a shell.

## Reading other programs' output

Parse structured output with the tool built for it: `jq` for JSON, a machine-readable mode for git (`--porcelain`, `-z`, `--format`). Check the shape of what comes back, since a parsing tool can exit 0 on input it could not read. When no such tool covers the format, the job belongs in another language.

## Quoting and arguments

- Quote every expansion. Build argument lists as arrays (`args=(--flag "$value")`, `"${args[@]}"`), never as a string split later.
- Filenames are read with `while IFS= read -r` or NUL-delimited (`find -print0`, `git ls-files -z`, `xargs -0`); never parse `ls`.
- `printf` over `echo` for anything containing a variable.
- A `# shellcheck disable=` carries its reason on the directive. A repeated SC2086 suppression means an argument string should be an array.
- Scratch space is `mktemp -d` plus a cleanup trap on `EXIT`; never a fixed path under `/tmp`.

## Output and portability

- Color only when stdout is a terminal (`[[ -t 1 ]]`) and `NO_COLOR` is unset.
- `export LC_ALL=C` in scripts that process text, so sorting and character classes do not vary by machine.
- macOS ships BSD tools and Linux GNU ones: `sed -i.bak … && rm -f "$f.bak"` for in-place edits, no `date -d` or `stat -c`, no `readlink -f` on older macOS, or branch on `case "$(uname -s)"`.

## CI

- A GitHub Actions step passes inputs and expressions to its script through `env:`, never as `${{ … }}` inside `run:`, where they are pasted into the script as code.
- A script that runs both in CI and locally guards the CI-only files: `>> "${GITHUB_STEP_SUMMARY:-/dev/null}"`, `[ -n "${GITHUB_OUTPUT:-}" ]`.

## Testing

- Each script that carries logic has a companion test, named the way the repo names them (`<name>.test.sh` when starting): small `ok` / `fail` helpers, a counter that sets the exit status, and a `mktemp -d` working directory removed on exit.
- Tests stub an external command by putting a fake first on `PATH`; they never reach the network or the operator's home directory. A script that drives git is tested against throwaway repos with `HOME`, `GIT_CONFIG_GLOBAL` and `GIT_CONFIG_NOSYSTEM` pointed away from the operator's config, and `GIT_CEILING_DIRECTORIES` set so a temp dir inside another repo is not mistaken for one.
- A suite goes red, not green or skipped, when a tool it needs is missing.

## Gotchas

- bash 3.2 treats an empty array as unbound under `set -u`: write `${a[@]+"${a[@]}"}`.
- An `EXIT` trap that reads a function's `local` variable fails under `set -u`, because the function has returned when the trap fires. Keep the trap's variable global.
- `local x=$(cmd)` takes `local`'s exit status, not the command's. Declare, then assign.
- `${x^^}`, `${x,,}`, `mapfile` and associative arrays need bash 4.
- `set -e` is off inside a function called from `if`, `&&`, `||` or `!`, even for commands deep inside it.
- `$(...)` does not inherit `-e` before bash 4.4's `inherit_errexit`.
- `jq` exits 2 and 3 for its own usage and compile errors, so a script whose statuses overlap cannot tell its failure from jq's.

## Red flags

- A shell script with no shellcheck gate, or a gate that lists files by hand
- bash 4 or 5 syntax in a script a developer runs, or a bash 5 script with no version check
- `set -e` doing the work of an explicit check inside a function, or `|| true` hiding a failure
- An unquoted expansion, an argument string split into a command, or `eval`
- A `shellcheck disable` with no reason
- A script that mutates before it has checked its inputs, or that fails on a second run
- A fixed `/tmp/...` path, or scratch space with no cleanup trap
- `${{ … }}` inside a workflow's `run:` block
- A download piped into a shell, or `curl` without `-f`
- Logic that outgrew a screenful and wants a real language
