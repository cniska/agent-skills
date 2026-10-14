#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/ledger-path.sh"

readonly COACH_DUE_AFTER_SECONDS=86400
readonly NEVER_RUN="the past week's sessions"
readonly REPO_PATTERN='^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$'
readonly UPSTREAM_DEADLINE_SECONDS=5

warn() {
  printf 'coach-due.sh: %s\n' "$1" >&2
}

utc_time() {
  local epoch="$1"
  date -u -d "@$epoch" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -u -r "$epoch" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null
}

ask_remote() {
  GIT_TERMINAL_PROMPT=0 exec git ls-remote "https://github.com/$1" HEAD
}

upstream_note() (
  local list
  list="$(dirname -- "$(ledger_path)")/upstreams.json"
  [ -f "$list" ] || return 0
  local entries
  if ! entries="$(jq -r '.[] | [.repo, .reviewed] | @tsv' -- "$list" 2>/dev/null)"; then
    warn "$list is not a list of upstreams with a repo and a reviewed commit, so the upstream count is skipped"
    return 0
  fi
  local answers repo reviewed count=0
  local -a pids=() reviews=()
  answers="$(mktemp -d)"
  trap 'rm -rf -- "$answers"' EXIT
  while IFS=$'\t' read -r repo reviewed; do
    [[ $repo =~ $REPO_PATTERN ]] || continue
    (ask_remote "$repo") >"$answers/$count" 2>/dev/null </dev/null &
    pids+=("$!")
    reviews+=("$reviewed")
    count=$((count + 1))
  done <<<"$entries"
  if ((count == 0)); then
    return 0
  fi
  { sleep "$UPSTREAM_DEADLINE_SECONDS" && kill "${pids[@]}"; } >/dev/null 2>&1 </dev/null &
  local watchdog="$!"
  wait "${pids[@]}" 2>/dev/null || true
  kill "$watchdog" 2>/dev/null || true
  wait "$watchdog" 2>/dev/null || true
  local i head answered=0 moved=0
  for ((i = 0; i < count; i++)); do
    head="$(cat -- "$answers/$i" 2>/dev/null)" || head=""
    head="${head%%[[:space:]]*}"
    [[ $head =~ ^[0-9a-f]{40}$ ]] || continue
    answered=$((answered + 1))
    if [ "$head" != "${reviews[$i]}" ]; then
      moved=$((moved + 1))
    fi
  done
  if ((moved > 0)); then
    printf 'Upstreams moved since their last review: %d of the %d that answered.\n' "$moved" "$answered"
  fi
)

main() {
  if [ -z "${CLAUDE_PLUGIN_DATA:-}" ]; then
    warn "CLAUDE_PLUGIN_DATA is not set, so the coach's last run is unknown"
    exit 1
  fi
  local record="$CLAUDE_PLUGIN_DATA/coach/last-run"
  local content=""
  if [ -e "$record" ] && ! content="$(<"$record")" 2>/dev/null; then
    warn "$record cannot be read, so whether the coach is due is unknown"
    exit 1
  fi

  local since now when
  if ! [[ $content =~ ^[0-9]+$ ]]; then
    since="$NEVER_RUN"
  else
    now="$(date +%s)"
    if ((now - content <= COACH_DUE_AFTER_SECONDS)); then
      return
    fi
    if ! when="$(utc_time "$content")"; then
      warn "the last run time $content cannot be formatted as a date, so the coach due note is skipped"
      exit 1
    fi
    since="the sessions since $when"
  fi
  printf 'The coach is due. At the next break, run cniska-skills:coach over %s, then apply its proposals except conflicts, which go to the owner.\n' "$since"
  upstream_note
}

main "$@"
