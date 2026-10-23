#!/usr/bin/env bash
set -uo pipefail

die() {
  printf 'lint-shell.sh: %s\n' "$1" >&2
  exit 1
}

usage() {
  printf '%s\n' \
    'Usage: lint-shell.sh' \
    'Runs shellcheck at warning severity over every tracked shell file in the current repository:' \
    'each *.sh file, and each file whose first line is a sh, bash, dash or ksh shebang.' \
    'Needs git and shellcheck.' \
    'Exits 0 when every file passes, shellcheck'"'"'s own status when one fails, 1 when no shell file is tracked, 2 on a usage error.'
}

shell_files() {
  local file
  git ls-files -z | while IFS= read -r -d '' file; do
    case "$file" in
      *.sh) printf '%s\0' "$file" ;;
      *) head -1 "$file" 2>/dev/null | grep -Eq '^#!.*(/| )(ba|da|k)?sh([[:space:]]|$)' && printf '%s\0' "$file" ;;
    esac
  done
}

main() {
  case "${1:-}" in
    -h | --help)
      usage
      return 0
      ;;
  esac
  if [ "$#" -gt 0 ]; then
    usage >&2
    exit 2
  fi
  shellcheck --version >/dev/null 2>&1 || die "shellcheck is not on PATH; run mise install"
  git rev-parse --show-toplevel >/dev/null 2>&1 || die "git found no repository at $(pwd); run it inside the repository"

  local files=() file
  while IFS= read -r -d '' file; do
    files+=("$file")
  done < <(shell_files)
  [ "${#files[@]}" -gt 0 ] || die "no tracked shell file under $(pwd)"
  shellcheck --severity=warning "${files[@]}"
}

main "$@"
