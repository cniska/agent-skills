#!/usr/bin/env bash
set -euo pipefail

readonly COACH_DUE_AFTER_SECONDS=86400
readonly NEVER_RUN="the past week's sessions"

warn() {
  printf 'coach-due.sh: %s\n' "$1" >&2
}

utc_time() {
  local epoch="$1"
  date -u -d "@$epoch" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -u -r "$epoch" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null
}

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
}

main "$@"
