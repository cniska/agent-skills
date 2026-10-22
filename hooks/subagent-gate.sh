readonly REPORT_SETTLE_TRIES=30
readonly REPORT_SETTLE_INTERVAL=0.1

final_block() {
  jq -nRc '
    def turn_start:
      (.type == "user" and (.message.content | type == "string" or any(.[]?; .type != "tool_result")))
      or (.type == "attachment" and .attachment.type == "hook_blocking_error");
    [inputs | fromjson? | objects] as $lines
    | ([range(0; $lines | length) | select($lines[.] | turn_start)] | last // -1) as $start
    | [$lines[$start + 1:][] | select(.type == "assistant") | .message.content[]? | select(.type != "thinking")]
    | last // empty' "$1" 2>/dev/null || true
}

is_handback() {
  jq -e '.type == "tool_use" and .name == "SubagentHandback"' >/dev/null 2>&1
}

is_text() {
  jq -e '.type == "text"' >/dev/null 2>&1
}

settled_block() {
  local transcript="$1" block tries=0
  while :; do
    block="$(final_block "$transcript")"
    if is_handback <<<"$block" || is_text <<<"$block"; then
      break
    fi
    tries=$((tries + 1))
    [ "$tries" -lt "$REPORT_SETTLE_TRIES" ] || break
    sleep "$REPORT_SETTLE_INTERVAL"
  done
  printf '%s\n' "$block"
}

at_handback() {
  [ "$(jq -r '.hook_event_name // empty' <<<"$1")" = PreToolUse ]
}

judges() {
  [ "$(jq -r '.agent_type // empty' <<<"$1")" = "$2" ]
}

agent_transcript() {
  local input="$1"
  local path session_transcript agent
  path="$(jq -r '.agent_transcript_path // empty' <<<"$input")"
  if [ -n "$path" ]; then
    printf '%s\n' "$path"
    return
  fi
  session_transcript="$(jq -r '.transcript_path // empty' <<<"$input")"
  agent="$(jq -r '.agent_id // empty' <<<"$input")"
  if [ -n "$session_transcript" ] && [ -n "$agent" ]; then
    printf '%s/subagents/agent-%s.jsonl\n' "${session_transcript%.jsonl}" "$agent"
  fi
}

left_to_handback() {
  local input="$1"
  local transcript
  ! at_handback "$input" || return 1
  transcript="$(agent_transcript "$input")"
  [ -n "$transcript" ] && [ -f "$transcript" ] || return 1
  settled_block "$transcript" | is_handback
}

subagent_report() {
  local input="$1"
  local transcript last_message block
  if at_handback "$input"; then
    jq -r '.tool_input.message // empty' <<<"$input"
    return
  fi
  transcript="$(agent_transcript "$input")"
  last_message="$(jq -r '.last_assistant_message // empty' <<<"$input")"
  if [ -n "$transcript" ] && [ -f "$transcript" ]; then
    block="$(settled_block "$transcript")"
    if [ -z "$last_message" ] && is_text <<<"$block"; then
      jq -r '.text' <<<"$block"
      return
    fi
  fi
  printf '%s\n' "$last_message"
}

denials_file() {
  printf '%s/denials/%s\n' "$CLAUDE_PLUGIN_DATA" "$(printf '%s' "$1" | shasum -a 256 | cut -d ' ' -f 1)"
}

was_denied() {
  local input="$1" code="$2"
  local agent denials
  agent="$(jq -r '.agent_id // empty' <<<"$input")"
  [ -n "${CLAUDE_PLUGIN_DATA:-}" ] && [ -n "$agent" ] || return 1
  denials="$(denials_file "$agent")"
  [ -f "$denials" ] && grep -qxF "$code" "$denials"
}

deny_once() {
  local input="$1" code="$2" reason="$3"
  local agent denials
  agent="$(jq -r '.agent_id // empty' <<<"$input")"
  if [ -z "${CLAUDE_PLUGIN_DATA:-}" ] || [ -z "$agent" ]; then
    printf '%s: allowed %s unchecked: the bound on denials needs CLAUDE_PLUGIN_DATA and agent_id\n' "${0##*/}" "$code" >&2
    return 1
  fi
  if was_denied "$input" "$code"; then
    return 1
  fi
  denials="$(denials_file "$agent")"
  if ! { mkdir -p "$(dirname "$denials")" && printf '%s\n' "$code" >>"$denials"; } 2>/dev/null; then
    printf '%s: allowed %s unchecked: %s cannot be appended to\n' "${0##*/}" "$code" "$denials" >&2
    return 1
  fi
  if at_handback "$input"; then
    pre_tool_deny "$reason"
    return
  fi
  jq -cn --arg reason "$reason" '{decision: "block", reason: $reason}'
}
