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

read_files() {
  local transcript
  transcript="$(agent_transcript "$1")"
  [ -n "$transcript" ] && [ -f "$transcript" ] || return 0
  jq -nrR '[inputs | fromjson? | objects | select(.type == "assistant") | .message.content[]?
    | select(.type == "tool_use" and .name == "Read") | .input.file_path? | select(type == "string" and . != "")] | unique[]' "$transcript"
}

left_to_handback() {
  local input="$1"
  local transcript
  ! at_handback "$input" || return 1
  transcript="$(agent_transcript "$input")"
  [ -n "$transcript" ] && [ -f "$transcript" ] || return 1
  settled_block "$transcript" | is_handback
}

denials_file() {
  printf '%s/denials/%s\n' "$CLAUDE_PLUGIN_DATA" "$(printf '%s' "$1" | shasum -a 256 | cut -d ' ' -f 1)"
}

reporter_id() {
  jq -r '.agent_id // .session_id // empty' <<<"$1"
}

was_denied() {
  local input="$1" code="$2"
  local key denials
  key="$(reporter_id "$input")"
  [ -n "${CLAUDE_PLUGIN_DATA:-}" ] && [ -n "$key" ] || return 1
  denials="$(denials_file "$key")"
  [ -f "$denials" ] && grep -qxF "$code" "$denials"
}

deny_once() {
  local input="$1" code="$2" reason="$3"
  local key denials
  key="$(reporter_id "$input")"
  if [ -z "${CLAUDE_PLUGIN_DATA:-}" ] || [ -z "$key" ]; then
    printf '%s: allowed %s unchecked: the bound on denials needs CLAUDE_PLUGIN_DATA and agent_id or session_id\n' "${0##*/}" "$code" >&2
    return 1
  fi
  if was_denied "$input" "$code"; then
    return 1
  fi
  denials="$(denials_file "$key")"
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
