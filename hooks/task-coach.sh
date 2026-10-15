#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/ledger-path.sh"
source "$HERE/transcript.sh"
source "$HERE/subagent-gate.sh"

warn() {
  printf 'task-coach.sh: %s\n' "$1" >&2
}

loaded_task() {
  tool_uses "$1" Skill | jq -r '.skill // empty' 2>/dev/null | grep -qE '(^|:)task$'
}

ran_coach() {
  tool_uses "$1" Agent | jq -r '.subagent_type // empty' 2>/dev/null | grep -qx 'cniska-skills:coach'
}

past_due_note() {
  local record
  record="$(ledger_dir)/experiments.jsonl"
  [ -f "$record" ] || return 0
  local today past
  today="$(date -u '+%Y-%m-%d')"
  if ! past="$(jq -rs --arg today "$today" '
    reduce .[] as $e ({};
      if $e.event == "open" then .[$e.sha] = $e
      elif $e.event == "close" then del(.[$e.sha])
      else . end)
    | [.[] | select((.check | type) == "string" and .check[0:10] < $today) | "\(.sha) (\(.signal // "no signal"))"]
    | join(", ")' -- "$record" 2>/dev/null)"; then
    warn "$record is not a record of experiments, one JSON line per event, so the past-due experiments are not named"
    return 0
  fi
  if [ -n "$past" ]; then
    printf ' Brief it with the experiments past their check date, %s, in the record at %s.' "$past" "$record"
  fi
}

main() {
  jq --version >/dev/null 2>&1 || {
    warn "jq is required to read the subagent's transcript"
    exit 1
  }
  local input
  input="$(cat)"
  local agent session transcript
  agent="$(jq -r '.agent_id // empty' <<<"$input")"
  session="$(jq -r '.session_id // empty' <<<"$input")"
  transcript="$(agent_transcript "$input")"
  [ -n "$transcript" ] && [ -f "$transcript" ] || return 0
  loaded_task "$transcript" || return 0
  ran_coach "$transcript" && return
  ! left_to_handback "$input" || return 0

  local reason
  reason="Before you hand back, run cniska-skills:coach in the foreground over this task alone: your own run, agent $agent of session $session, with its transcript at $transcript, and the subagents you started.$(past_due_note) Hand back its report with yours, so your caller applies its proposals except conflicts, which go to the owner, opening an experiment for each change where cniska-skills:coordinate calls for one."
  if at_handback "$input"; then
    deny_once "$input" coach_not_run "$reason" || return 0
    return
  fi
  ! was_denied "$input" coach_not_run || return 0
  deny_once "$input" coach_reminder "$reason" || return 0
}

main "$@"
