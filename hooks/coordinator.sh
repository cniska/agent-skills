#!/usr/bin/env bash
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/deadline.sh"

export AGENT_TASK_NO_UPDATE_CHECK=1

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
  printf 'Project directory %s not pulled: %s\n\n' "$1" "$2"
}

pull_dir() {
  local dir="$1"
  if ! git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    not_pulled "$dir" "it is not a git checkout."
    return 0
  fi
  local upstream
  if ! upstream="$(git -C "$dir" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null)"; then
    not_pulled "$dir" "its branch tracks no remote branch, so the remote may hold newer work."
    return 0
  fi
  local status=0
  fetch_within_deadline "$dir" || status=$?
  if ((status == KILLED_STATUS)); then
    not_pulled "$dir" "fetching $upstream took over ${FETCH_DEADLINE_SECONDS}s; $(stale_since_last_fetch "$dir")"
    return 0
  fi
  if ((status != 0)); then
    not_pulled "$dir" "could not fetch $upstream; $(stale_since_last_fetch "$dir")"
    return 0
  fi
  local behind ahead
  if ! behind="$(commits_between "$dir" 'HEAD..@{upstream}')" || ! ahead="$(commits_between "$dir" '@{upstream}..HEAD')"; then
    not_pulled "$dir" "after fetching, git could not compare it with $upstream."
    return 0
  fi
  if ((behind == 0)); then
    return 0
  fi
  if ((ahead > 0)); then
    not_pulled "$dir" "its branch has diverged from $upstream; it is $behind commits behind and $ahead ahead."
    return 0
  fi
  if [ -n "$(git -C "$dir" status --porcelain --untracked-files=no 2>/dev/null)" ]; then
    not_pulled "$dir" "it has uncommitted changes; it is $behind commits behind $upstream."
    return 0
  fi
  if ! git -C "$dir" merge --ff-only --quiet '@{upstream}' >/dev/null 2>&1; then
    not_pulled "$dir" "could not fast-forward to $upstream; it is $behind commits behind."
  fi
}

project_dir() {
  local projects
  projects="$(agent-task project list 2>/dev/null)" || return 1
  jq -Rsr --arg id "$1" -f "$HERE/project-dir.jq" 2>/dev/null <<<"$projects"
}

commands() {
  printf 'This session coordinates the agent-task project %s, and its tasks are its state. ' "$1"
  printf 'Read them with `agent-task list --project %s --full`. ' "$1"
  printf 'Queue one with `agent-task add <name> --project %s --repo <path> --goal <text>`, giving its plan with `--plan <file>` and what it waits on with `--waits <text>`. ' "$1"
  printf 'Start one with `agent-task start <name> --project %s --repo <path> --brief <file>`, replace all that one waits on with `agent-task wait <name> [--after <name>]... [--waits <text>] [--until <command>]`, and close one with `agent-task done <name>`.\n\n' "$1"
}

main() {
  local project="${AGENT_TASK_PROJECT:-}"
  [ -n "${project//[[:space:]]/}" ] || return 0
  commands "$project"
  if ! agent-task --version >/dev/null 2>&1; then
    printf 'Tasks not read: agent-task is not on PATH or does not run.\n'
    return 0
  fi
  local dir
  if ! dir="$(project_dir "$project")"; then
    printf 'Project directory not pulled: agent-task project list could not be read with jq.\n\n'
  elif [ -z "$dir" ]; then
    printf 'Project directory not pulled: agent-task project list names no directory for %s.\n\n' "$project"
  elif [ ! -d "$dir" ]; then
    not_pulled "$dir" "it does not exist."
  else
    pull_dir "$dir"
  fi
  agent-task list --project "$project" --full 2>&1
}

main "$@"
exit 0
