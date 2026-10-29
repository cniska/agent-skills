#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/hook-output.sh"
source "$HERE/subagent-gate.sh"
source "$HERE/event-log.sh"
source "$HERE/report-store.sh"

readonly SCHEMAS="$HERE/../mcp/report-schemas.json"
readonly TOOL_PREFIX="mcp__plugin_cniska-skills_report__"
readonly CALLERS='{"verdict": ["cniska-skills:reviewer", "cniska-skills:designer"], "research": ["cniska-skills:researcher"], "task_report": ["cniska-skills:worker"]}'
readonly ALREADY_REPORTED_REASON="Your report is already stored, and a report is made once. Hand back now with a one-line message."

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

reporting_tool() {
  jq -r --arg type "$1" 'to_entries[] | select(any(.value[]; . == $type)) | .key' <<<"$CALLERS"
}

callers_of() {
  jq -r --arg tool "$1" '.[$tool] | join(" or ")' <<<"$CALLERS"
}

gate_line() {
  event_log "$1" gate --arg gate report --arg decision "$2" --arg reason "$3" \
    --arg repo "" --arg head "" --arg fingerprint ""
}

store() {
  local input="$1" tool="$2" file="$3" gate="$4"
  if ! {
    mkdir -p "$(dirname "$file")" &&
      jq -c --arg tool "$tool" --argjson gate "$gate" \
        '{tool: $tool, agent_type: (.agent_type // null), agent_id: (.agent_id // null), session_id: (.session_id // null), payload: .tool_input, gate: $gate}' \
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

is_report_tool() {
  jq -e --arg tool "$1" 'has($tool)' <<<"$CALLERS" >/dev/null
}

on_report_tool() {
  local input="$1" tool="$2" file violations agent_type
  is_report_tool "$tool" || return 0
  file="$(stored_report_file "$input")"
  if [ -f "$file" ]; then
    pre_tool_deny "$ALREADY_REPORTED_REASON"
    gate_line "$input" deny already_reported
    return
  fi
  violations="$(jq -r -L "$HERE" --slurpfile schemas "$SCHEMAS" --arg tool "$tool" "$PAYLOAD_VIOLATIONS" <<<"$input")" ||
    die "jq could not check the $tool report"
  if [ -n "$violations" ]; then
    refuse "$input" "$tool" "$file" payload_invalid \
      "The report does not match the $tool tool's schema:"$'\n'"$violations"$'\n'"Call the tool again with each of these fixed."
    return
  fi
  agent_type="$(field "$input" agent_type)"
  if [ "$(reporting_tool "$agent_type")" != "$tool" ]; then
    refuse "$input" "$tool" "$file" wrong_agent \
      "Only $(callers_of "$tool") report through $tool; this session is ${agent_type:-not a cniska-skills agent}. Hand back as your own instructions say."
    return
  fi
  store "$input" "$tool" "$file" '{"recorded": true}'
  pre_tool_allow
}

on_end() {
  local input="$1" tool file
  tool="$(reporting_tool "$(field "$input" agent_type)")"
  [ -n "$tool" ] || return 0
  ! left_to_handback "$input" || return 0
  file="$(stored_report_file "$input")"
  [ ! -f "$file" ] || return 0
  if deny_once "$input" missing_report "Call $TOOL_PREFIX$tool with your report before you end. Your caller reads the report from that call, not from your final message."; then
    gate_line "$input" deny missing_report
    return
  fi
  gate_line "$input" allow missing_report
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
        "$TOOL_PREFIX"*) on_report_tool "$input" "${tool_name#"$TOOL_PREFIX"}" ;;
        SubagentHandback) on_end "$input" ;;
      esac
      ;;
    SubagentStop | Stop) on_end "$input" ;;
  esac
}

main "$@"
