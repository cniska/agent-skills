#!/usr/bin/env bash
set -uo pipefail

logs=""
pids=()
cleanup() { [ -z "$logs" ] || rm -rf "$logs"; }
stop() {
  local pid
  for pid in ${pids[@]+"${pids[@]}"}; do
    kill -TERM -- -"$pid" 2>/dev/null
  done
  exit "$1"
}

die() {
  printf 'test-shell.sh: %s\n' "$1" >&2
  exit 1
}

usage() {
  printf '%s\n' \
    'Usage: test-shell.sh' \
    'Runs every *.test.sh under the current directory, outside node_modules and .claude, at once.' \
    'Prints each file'"'"'s output whole, in sorted order, under its name.' \
    'Exits 0 when every file passes, 1 naming each failing file on stderr, 2 on a usage error.'
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

  local files=() file
  while IFS= read -r -d '' file; do
    files+=("$file")
  done < <(find . -name '*.test.sh' -not -path './node_modules/*' -not -path './.claude/*' -print0 | LC_ALL=C sort -z)
  [ "${#files[@]}" -gt 0 ] || die "no *.test.sh files under $(pwd)"

  logs="$(mktemp -d)" || die "cannot create a temp directory"
  trap cleanup EXIT
  trap 'stop 130' INT
  trap 'stop 143' TERM

  local i
  set -m
  for i in "${!files[@]}"; do
    bash "${files[$i]}" </dev/null >"$logs/$i" 2>&1 &
    pids+=("$!")
  done
  set +m

  local failed=() status
  for i in "${!files[@]}"; do
    wait "${pids[$i]}"
    status=$?
    printf '== %s ==\n' "${files[$i]}"
    cat "$logs/$i"
    [ "$status" -eq 0 ] || failed+=("${files[$i]}")
  done

  [ "${#failed[@]}" -gt 0 ] || return 0
  for file in "${failed[@]}"; do
    printf 'test-shell.sh: failed: %s\n' "$file" >&2
  done
  return 1
}

main "$@"
