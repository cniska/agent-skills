#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/review-state.sh"
source "$HERE/hook-output.sh"
source "$HERE/subagent-gate.sh"
source "$HERE/event-log.sh"
source "$HERE/report-store.sh"
source "$HERE/waits.sh"
source "$HERE/runs.sh"
source "$HERE/hold.sh"
source "$HERE/review-record.sh"
source "$HERE/ruling-record.sh"

readonly SCHEMAS="$HERE/../mcp/report-schemas.json"
readonly RULE_NAMES="$HERE/rule-names.json"
readonly TOOL_PREFIX="mcp__plugin_cniska-skills_report__"
readonly CALLERS='{"verdict": ["cniska-skills:reviewer", "cniska-skills:designer"], "research": ["cniska-skills:researcher"], "task_report": ["cniska-skills:worker"]}'
readonly ALREADY_REPORTED_REASON="Your report is already stored, and a report is made once per hand-back. Hand back now with a one-line message."

readonly PAYLOAD_VIOLATIONS='
  include "report-schema";
  def when($field; $value; $named):
    if (.[$field] == $value) and (has($named) | not) then "/\($named) is required when /\($field) is \($value | tojson)"
    else empty end;
  def only_when($field; $value; $named):
    if (.[$field] != $value) and has($named) then "/\($named) is given only when /\($field) is \($value | tojson)"
    else empty end;
  def pairings($tool):
    if $tool == "research" then when("sort"; "drop"; "drop_reason"), only_when("sort"; "drop"; "drop_reason")
    elif $tool == "task_report" then
      when("outcome"; "landed"; "landed"), only_when("outcome"; "landed"; "landed"), when("outcome"; "plan_ready"; "plan")
    else empty end;
  .tool_input as $payload
  | [$payload | tool_violations($schemas[0]; $tool) | violation_text] as $shape
  | if ($shape | length) > 0 then $shape[] else $payload | pairings($tool) end'

readonly REASON_VIOLATIONS='
  .agent_type as $type
  | .tool_input.judgments | to_entries[] | .key as $i | .value
  | select(has("reason"))
  | (select(.verdict != "return") | "/judgments/\($i)/reason is given only when /judgments/\($i)/verdict is \"return\""),
    (select($type == "cniska-skills:reviewer" and .reason != "no_diff") | "/judgments/\($i)/reason must be \"no_diff\" from a reviewer")'

readonly RULE_VIOLATIONS='
  [$names[0].names[].name] as $valid
  | .tool_input.judgments | to_entries[] | .key as $i | .value
  | ("findings", "conflicts", "follow_ups") as $field
  | .[$field] | to_entries[] | select(.value.rule as $rule | any($valid[]; . == $rule) | not)
  | "/judgments/\($i)/\($field)/\(.key)/rule \(.value.rule | tojson) is not a rule name"'

readonly RULE_LIST='
  [$names[0].names[] | .name as $name | .sources[] | {source: ., name: $name}]
  | group_by(.source)[] | "\(.[0].source): \(map(.name) | join(" | "))"'

readonly ID_VIOLATIONS='include "report-schema"; {id: $id} | tool_violations($schemas[0]; "read_report")'

die() {
  printf 'report-record.sh: %s\n' "$1" >&2
  exit 1
}

field() {
  jq -r --arg name "$2" '.[$name] // empty' <<<"$1"
}

stored_report_file() {
  local input="$1" id violations
  [ -n "${CLAUDE_PLUGIN_DATA:-}" ] || die "CLAUDE_PLUGIN_DATA is required to keep reports"
  id="$(reporter_id "$input")"
  violations="$(jq -n -L "$HERE" --slurpfile schemas "$SCHEMAS" --arg id "$id" "$ID_VIOLATIONS")" ||
    die "jq could not check the id a report is kept under"
  [ -z "$violations" ] || die "the hook input has no agent_id or session_id a report can be kept under"
  report_file "$id"
}

rule_unknown_reason() {
  local names
  names="$(jq -rn --slurpfile names "$RULE_NAMES" "$RULE_LIST")" || die "jq could not list the rule names in $RULE_NAMES"
  printf '%s\n%s\n%s\n%s' "$1" \
    "Give each rule as one name from this list, exactly as written, and put any detail in why. Each line is a source file, then its names, split by |:" \
    "$names" "Call the tool again with each of these fixed."
}

reporting_tool() {
  jq -r --arg type "$1" 'to_entries[] | select(any(.value[]; . == $type)) | .key' <<<"$CALLERS"
}

callers_of() {
  jq -r --arg tool "$1" '.[$tool] | join(" or ")' <<<"$CALLERS"
}

gate_line() {
  event_log "$1" gate --arg gate verdict --arg decision "$2" --arg reason "$3" \
    --arg repo "${4:-}" --arg head "" --arg fingerprint ""
}

store() {
  local input="$1" tool="$2" file="$3" gate="$4"
  if [ "$tool" = verdict ]; then
    gate="$(jq -c --argjson returns "$(return_counts "$(reporter_id "$input")")" '. + {returns: $returns}' <<<"$gate")"
  fi
  if ! {
    mkdir -p "$(dirname "$file")" &&
      jq -c --arg tool "$tool" --argjson gate "$gate" \
        '{tool: $tool, agent_type: (.agent_type // null), agent_id: (.agent_id // null), session_id: (.session_id // null), payload: .tool_input, gate: $gate, handed_back: false}' \
        <<<"$input" >"$file.tmp" &&
      mv "$file.tmp" "$file"
  }; then
    die "the report cannot be written to $file"
  fi
}

refuse() {
  local input="$1" tool="$2" file="$3" code="$4" reason="$5"
  if deny_once "$input" "$code" "$reason"; then
    gate_line "$input" deny "$code"
    return
  fi
  store "$input" "$tool" "$file" "$(jq -cn --arg code "$code" '{recorded: false, code: $code}')"
  gate_line "$input" allow "$code"
  pre_tool_allow
}

awaits_handback() {
  [ -f "$1" ] && ! jq -e '.handed_back' "$1" >/dev/null 2>&1
}

hand_back() {
  local input="$1" file="$2"
  if ! { jq -c '.handed_back = true' "$file" >"$file.tmp" && mv "$file.tmp" "$file"; }; then
    die "the report at $file cannot be marked as handed back"
  fi
  rm -f "$(denials_file "$(reporter_id "$input")")" || die "the bound on denials cannot be reset for $file"
  end_round "$input" || die "the round cannot be ended for $file"
  release_waits "$(reporter_id "$input")" || die "the waits on and of $file cannot be released"
  rm -rf "$(runs_dir "$(reporter_id "$input")")" || die "the background commands of $file cannot be released"
}

is_report_tool() {
  jq -e --arg tool "$1" 'has($tool)' <<<"$CALLERS" >/dev/null
}

on_report_tool() {
  local input="$1" tool="$2" file violations agent_type
  is_report_tool "$tool" || return 0
  file="$(stored_report_file "$input")"
  if awaits_handback "$file"; then
    pre_tool_deny "$ALREADY_REPORTED_REASON"
    gate_line "$input" deny already_reported
    return
  fi
  agent_type="$(field "$input" agent_type)"
  if [ "$(reporting_tool "$agent_type")" != "$tool" ]; then
    pre_tool_deny "Only $(callers_of "$tool") report through $tool; this session is ${agent_type:-not a cniska-skills agent}. Hand back as your own instructions say."
    gate_line "$input" deny wrong_agent
    return
  fi
  local reads="" round="" returned=""
  if [ "$tool" = verdict ] && [ "$agent_type" = cniska-skills:reviewer ]; then
    reads="$(read_files "$input")"
    round="$(reporter_round "$input")"
    returned="$(returned_paths "$reads")"
    void_returns "$input" "$round" "$returned"
  fi
  violations="$(jq -r -L "$HERE" --slurpfile schemas "$SCHEMAS" --arg tool "$tool" "$PAYLOAD_VIOLATIONS" <<<"$input")" ||
    die "jq could not check the $tool report"
  if [ -n "$violations" ]; then
    refuse "$input" "$tool" "$file" payload_invalid \
      "The report does not match the $tool tool's schema:"$'\n'"$violations"$'\n'"Call the tool again with each of these fixed."
    return
  fi
  local gate='{"recorded": true}'
  if [ "$tool" = verdict ]; then
    violations="$(jq -r "$REASON_VIOLATIONS" <<<"$input")" || die "jq could not check the verdict's reasons"
    if [ -n "$violations" ]; then
      refuse "$input" "$tool" "$file" payload_invalid \
        "The report gives a reason it may not:"$'\n'"$violations"$'\n'"Call the tool again with each of these fixed."
      return
    fi
  fi
  if [ "$tool" = verdict ]; then
    violations="$(jq -r --slurpfile names "$RULE_NAMES" "$RULE_VIOLATIONS" <<<"$input")" ||
      die "jq could not check the verdict's rule names against $RULE_NAMES"
    if [ -n "$violations" ]; then
      refuse "$input" "$tool" "$file" rule_unknown "$(rule_unknown_reason "$violations")"
      return
    fi
  fi
  if [ "$agent_type" = cniska-skills:reviewer ]; then
    local judged code
    judged="$(record_verdict "$input" "$reads" "$round")"
    code="$(jq -r '.code // empty' <<<"$judged")"
    if [ -n "$code" ]; then
      refuse "$input" "$tool" "$file" "$code" "$(jq -r .why <<<"$judged")"
      return
    fi
    gate="$(jq -c .gate <<<"$judged")"
    local repo
    while IFS=$'\t' read -r code repo; do
      gate_line "$input" allow "$code" "$repo"
    done < <(jq -r '.judgments[] | select(.code) | [.code, .repo] | @tsv' <<<"$gate")
  fi
  if [ "$tool" = verdict ]; then
    count_return "$input" "$gate" || die "the return cannot be counted for $file"
  fi
  store "$input" "$tool" "$file" "$gate"
  pre_tool_allow
}

on_end() {
  local input="$1" tool file
  tool="$(reporting_tool "$(field "$input" agent_type)")"
  [ -n "$tool" ] || return 0
  ! left_to_handback "$input" || return 0
  file="$(stored_report_file "$input")"
  if awaits_handback "$file"; then
    hand_back "$input" "$file"
    return 0
  fi
  drop_overdue_waits "$(reporter_id "$input")" || die "the overdue waits of $file cannot be dropped"
  local runs=""
  if [ "$(field "$input" hook_event_name)" = SubagentStop ] && can_judge_runs "$input"; then
    runs="$(recorded_runs "$input")"
  fi
  if has_waits "$(reporter_id "$input")" || [ -n "$runs" ]; then
    keep_waiting "$input" "$runs"
    return
  fi
  if deny_once "$input" missing_report "Call $TOOL_PREFIX$tool with your report before you end. Your caller reads the report from that call, not from your final message."; then
    gate_line "$input" deny missing_report
    return
  fi
  rm -f "$file" || die "the earlier hand-back's report at $file cannot be removed"
  end_round "$input" || die "the round cannot be ended for $file"
  release_waits "$(reporter_id "$input")" || die "the waits on and of $file cannot be released"
  rm -rf "$(runs_dir "$(reporter_id "$input")")" || die "the background commands of $file cannot be released"
  gate_line "$input" allow missing_report
}

keep_waiting() {
  local input="$1" id held finished still ended ran reason code=awaiting_review
  id="$(reporter_id "$input")"
  held="$(runs_in_state "$2" running)"
  finished="$(
    runs_in_state "$2" ended
    runs_in_state "$2" lapsed
  )"
  [ -n "$finished" ] || hold_wait "$id" "$held"
  still="$(waits_in_state "$id" waiting)"
  ended="$(waits_in_state "$id" ended)"
  ran="$(printf '%s\n%s' "$finished" "$(ended_runs "$held")" | sed '/^$/d')"
  [ -n "$still$ended" ] || code=awaiting_run
  if [ -n "$ended$ran" ]; then
    reason="$(ended_reason "$ended" "$ran" "$(runs_left "$held" "$ran")")"
    clear_ended_waits "$id"
    drop_runs "$id" "$ran"
  else
    reason="$(still_reason "$still" "$held")"
  fi
  reason="$reason$(stop_block_guard "$input")"
  gate_line "$input" deny "$code"
  if at_handback "$input"; then
    pre_tool_deny "$reason"
    return
  fi
  jq -cn --arg reason "$reason" '{decision: "block", reason: $reason}'
}

ended_reason() {
  local ended="$1" ran="$2" left="$3" task output state parts=()
  [ -z "$ended" ] || parts+=("Agent $ended has handed back. Read its verdict with ${TOOL_PREFIX}read_report.")
  while IFS=$'\t' read -r task output state; do
    case "$state" in
      ended) parts+=("Background command $task has ended; read its output in $output.") ;;
      lapsed) parts+=("Background command $task has run past the $((RUN_LIMIT_SECONDS / 60))-minute limit and no longer holds your end; stop it with TaskStop if you no longer need it, and read its output so far in $output.") ;;
    esac
  done <<<"$ran"
  if [ -n "$left" ]; then
    parts+=("Background command $(run_tasks "$left") is still running: end your turn to wait for it once you have read this, and do not hand back before it ends.")
  else
    parts+=("Carry on with the task.")
  fi
  printf '%s\n' "${parts[*]}"
}

still_reason() {
  local still="$1" runs="$2" parts=()
  [ -z "$still" ] || parts+=("Agent $still is still judging what you sent it.")
  [ -z "$runs" ] || parts+=("Background command $(run_tasks "$runs") is still running; stop one you no longer need with TaskStop.")
  printf '%s The task is still yours. End your turn again to keep waiting; you are woken when it ends. Do not hand back while you wait.\n' "${parts[*]}"
}

sent_to() {
  local input="$1" target violations
  [ -n "$(reporting_tool "$(field "$input" agent_type)")" ] || return 0
  [ -n "${CLAUDE_PLUGIN_DATA:-}" ] || return 0
  target="$(jq -r '.tool_input.to // empty' <<<"$input")"
  violations="$(jq -n -L "$HERE" --slurpfile schemas "$SCHEMAS" --arg id "$target" "$ID_VIOLATIONS")" ||
    die "jq could not check the agent a message goes to"
  [ -z "$violations" ] && [ -f "$(report_file "$target")" ] || return 0
  printf '%s\n' "$target"
}

on_send() {
  local input="$1" target
  target="$(sent_to "$input")"
  [ -n "$target" ] || return 0
  wait_on "$(reporter_id "$input")" "$target" || die "the wait on $target cannot be recorded"
}

on_bash_done() {
  local input="$1" task output
  [ -n "$(reporting_tool "$(field "$input" agent_type)")" ] || return 0
  [ -n "${CLAUDE_PLUGIN_DATA:-}" ] || return 0
  [ -n "$(field "$input" agent_id)" ] || return 0
  task="$(jq -r '.tool_response.backgroundTaskId? // empty' <<<"$input")"
  output="$(jq -r '.tool_response.backgroundOutputPath? // empty' <<<"$input")"
  [ -n "$task" ] && [ -n "$output" ] || return 0
  record_run "$(reporter_id "$input")" "$task" "$output" || die "the background command $task cannot be recorded"
}

on_send_failed() {
  local input="$1" target
  target="$(sent_to "$input")"
  [ -n "$target" ] || return 0
  drop_wait "$(reporter_id "$input")" "$target" || die "the wait on $target cannot be dropped"
}

main() {
  jq --version >/dev/null 2>&1 || die "jq is required to check reports"
  local input event tool_name
  input="$(cat)"
  event="$(field "$input" hook_event_name)"
  tool_name="$(field "$input" tool_name)"
  case "$event" in
    PreToolUse)
      case "$tool_name" in
        "$TOOL_PREFIX"ruling) on_ruling "$input" ;;
        "$TOOL_PREFIX"*) on_report_tool "$input" "${tool_name#"$TOOL_PREFIX"}" ;;
        SubagentHandback) on_end "$input" ;;
        SendMessage) on_send "$input" ;;
      esac
      ;;
    SubagentStop | Stop) on_end "$input" ;;
    PostToolUse)
      [ "$tool_name" != Bash ] || on_bash_done "$input"
      ;;
    PostToolUseFailure | PermissionDenied)
      [ "$tool_name" != SendMessage ] || on_send_failed "$input"
      ;;
  esac
}

main "$@"
