#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/ledger-path.sh"

readonly COACH_DUE_AFTER_SECONDS=86400
readonly NEVER_RUN="the past week's sessions"

warn() {
  printf 'coach-due.sh: %s\n' "$1" >&2
}

utc_time() {
  local epoch="$1"
  date -u -d "@$epoch" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -u -r "$epoch" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null
}

experiment_note() {
  local record
  record="$(dirname -- "$(ledger_path)")/experiments.jsonl"
  [ -f "$record" ] || return 0
  local today counts
  today="$(date -u '+%Y-%m-%d')"
  if ! counts="$(jq -rs --arg today "$today" '
    reduce .[] as $e ({};
      if $e.event == "open" then .[$e.sha] = $e
      elif $e.event == "close" then del(.[$e.sha])
      else . end)
    | [.[]]
    | [length, (map(select((.check | type) == "string" and .check[0:10] < $today)) | length)]
    | @tsv' -- "$record" 2>/dev/null)"; then
    warn "$record is not a record of experiments, one JSON line per event, so the experiment count is skipped"
    return 0
  fi
  local open past
  IFS=$'\t' read -r open past <<<"$counts"
  if ((open > 0)); then
    printf 'Experiments open: %d, %d of them past their check date; brief the coach with the record at %s.\n' "$open" "$past" "$record"
  fi
}

main() {
  if [ -z "${CLAUDE_PLUGIN_DATA:-}" ]; then
    warn "CLAUDE_PLUGIN_DATA is not set, so the coach's last run is unknown"
    exit 1
  fi
  local record="$CLAUDE_PLUGIN_DATA/coach/last-run"
  local content=""
  if [ -e "$record" ] && ! content="$(cat -- "$record" 2>/dev/null)"; then
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
  printf 'The coach is due. At the next break, run cniska-skills:coach over %s, then apply its proposals except conflicts, which go to the owner, opening an experiment for each change as cniska-skills:coordinate says.\n' "$since"
  experiment_note
}

main "$@"
