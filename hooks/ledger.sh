#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/ledger-path.sh"

readonly FETCH_DEADLINE_SECONDS=5
readonly KILLED_STATUS=143

fetch_within_deadline() {
  GIT_TERMINAL_PROMPT=0 git -C "$1" fetch --quiet >/dev/null 2>&1 </dev/null &
  local fetch="$!"
  { sleep "$FETCH_DEADLINE_SECONDS" && kill "$fetch"; } >/dev/null 2>&1 </dev/null &
  local watchdog="$!" status=0
  wait "$fetch" 2>/dev/null || status=$?
  kill "$watchdog" 2>/dev/null || true
  wait "$watchdog" 2>/dev/null || true
  return "$status"
}

behind_count() {
  git -C "$1" rev-list --count 'HEAD..@{upstream}' 2>/dev/null || printf 'an unknown number of'
}

not_pulled() {
  printf 'Ledger not pulled: %s\n\n' "$1"
}

pull_ledger() {
  local dir name
  dir="$(dirname -- "$1")"
  name="$(basename -- "$1")"
  git -C "$dir" ls-files --error-unmatch -- "$name" >/dev/null 2>&1 || return 0
  local upstream
  if ! upstream="$(git -C "$dir" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null)"; then
    not_pulled "its branch tracks no remote branch, so the remote may hold a newer ledger."
    return 0
  fi
  local status=0
  fetch_within_deadline "$dir" || status=$?
  if ((status == KILLED_STATUS)); then
    not_pulled "fetching $upstream took over ${FETCH_DEADLINE_SECONDS}s; it is at least $(behind_count "$dir") commits behind as of the last fetch."
    return 0
  fi
  if ((status != 0)); then
    not_pulled "could not fetch $upstream (offline or unreachable); it is at least $(behind_count "$dir") commits behind as of the last fetch."
    return 0
  fi
  local behind
  behind="$(behind_count "$dir")"
  if [ "$behind" = 0 ]; then
    return 0
  fi
  if [ -n "$(git -C "$dir" status --porcelain --untracked-files=no 2>/dev/null)" ]; then
    not_pulled "its repo has uncommitted changes; it is $behind commits behind $upstream."
    return 0
  fi
  if ! git -C "$dir" merge --ff-only --quiet '@{upstream}' >/dev/null 2>&1; then
    not_pulled "its branch has diverged from $upstream; it is $behind commits behind."
  fi
}

main() {
  local ledger
  ledger="$(ledger_path)"
  if [ -f "$ledger" ]; then
    pull_ledger "$ledger"
    cat -- "$ledger"
  fi
}

main "$@"
