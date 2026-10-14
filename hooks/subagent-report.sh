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

subagent_report() {
  local input="$1"
  local transcript last_message block
  transcript="$(jq -r '.agent_transcript_path // empty' <<<"$input")"
  last_message="$(jq -r '.last_assistant_message // empty' <<<"$input")"
  if [ -n "$transcript" ] && [ -f "$transcript" ]; then
    block="$(settled_block "$transcript")"
    if is_handback <<<"$block"; then
      jq -r '.input.message // empty' <<<"$block"
      return
    fi
  fi
  printf '%s\n' "$last_message"
}

tool_uses() {
  local transcript="$1" name="$2"
  if [ -z "$transcript" ] || [ ! -f "$transcript" ]; then
    return
  fi
  grep -F "\"$name\"" -- "$transcript" 2>/dev/null |
    jq -c --arg name "$name" 'select(.type == "assistant") | .message.content[]? | select(.type == "tool_use" and .name == $name) | .input' 2>/dev/null || true
}
