#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/ledger-path.sh"
source "$HERE/deadline.sh"

readonly FETCH_DEADLINE_SECONDS=5
readonly KILLED_STATUS=143

fetch_within_deadline() {
  start_in_group env GIT_TERMINAL_PROMPT=0 git -C "$1" fetch --quiet >/dev/null 2>&1 </dev/null
  wait_for_groups_within_deadline "$FETCH_DEADLINE_SECONDS" "$!"
}

commits_between() {
  git -C "$1" rev-list --count "$2" 2>/dev/null
}

stale_since_last_fetch() {
  local behind
  if behind="$(commits_between "$1" 'HEAD..@{upstream}')"; then
    printf 'it is at least %s commits behind as of the last fetch.' "$behind"
  else
    printf 'how far behind it is is unknown.'
  fi
}

not_pulled() {
  printf '%s not pulled: %s\n\n' "$1" "$2"
}

tracked() {
  git -C "$(dirname -- "$1")" ls-files --error-unmatch -- "$(basename -- "$1")" >/dev/null 2>&1
}

pull_file() {
  local label="$2"
  tracked "$1" || return 0
  local dir
  dir="$(dirname -- "$1")"
  local upstream
  if ! upstream="$(git -C "$dir" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null)"; then
    not_pulled "$label" "its branch tracks no remote branch, so the remote may hold a newer copy."
    return 0
  fi
  local status=0
  fetch_within_deadline "$dir" || status=$?
  if ((status == KILLED_STATUS)); then
    not_pulled "$label" "fetching $upstream took over ${FETCH_DEADLINE_SECONDS}s; $(stale_since_last_fetch "$dir")"
    return 0
  fi
  if ((status != 0)); then
    not_pulled "$label" "could not fetch $upstream; $(stale_since_last_fetch "$dir")"
    return 0
  fi
  local behind ahead
  if ! behind="$(commits_between "$dir" 'HEAD..@{upstream}')" || ! ahead="$(commits_between "$dir" '@{upstream}..HEAD')"; then
    not_pulled "$label" "after fetching, git could not compare it with $upstream."
    return 0
  fi
  if ((behind == 0)); then
    return 0
  fi
  if ((ahead > 0)); then
    not_pulled "$label" "its branch has diverged from $upstream; it is $behind commits behind and $ahead ahead."
    return 0
  fi
  if [ -n "$(git -C "$dir" status --porcelain --untracked-files=no 2>/dev/null)" ]; then
    not_pulled "$label" "its repo has uncommitted changes; it is $behind commits behind $upstream."
    return 0
  fi
  if ! git -C "$dir" merge --ff-only --quiet '@{upstream}' >/dev/null 2>&1; then
    not_pulled "$label" "could not fast-forward to $upstream; it is $behind commits behind."
  fi
}

repo_root() {
  git -C "$(dirname -- "$1")" rev-parse --show-toplevel 2>/dev/null
}

pulled_with() {
  tracked "$1" || return 1
  local root
  root="$(repo_root "$2")" || return 1
  [ "$root" = "$(repo_root "$1")" ]
}

print_shared_file() {
  local ledger="$1" shared="$2"
  if [ ! -f "$shared" ]; then
    printf '\nShared file not found: %s\n' "$shared"
    return 0
  fi
  if [ "$shared" -ef "$ledger" ]; then
    return 0
  fi
  printf '\n'
  if ! pulled_with "$ledger" "$shared"; then
    pull_file "$shared" "Shared file"
  fi
  cat -- "$shared"
}

main() {
  local ledger
  ledger="$(ledger_path)"
  if [ ! -f "$ledger" ]; then
    printf 'No ledger yet: a coordinating session creates it at %s\n' "$ledger"
    return 0
  fi
  pull_file "$ledger" "Ledger"
  cat -- "$ledger"
  local shared
  shared="$(linked_shared_file "$ledger")"
  [ -n "$shared" ] || return 0
  print_shared_file "$ledger" "$shared"
}

main "$@"
