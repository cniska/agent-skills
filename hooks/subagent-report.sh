# shellcheck shell=bash
handback_report() {
  local transcript="$1"
  if [ -z "$transcript" ] || [ ! -f "$transcript" ]; then
    return
  fi
  grep -F '"SubagentHandback"' "$transcript" | jq -r 'select(.type == "assistant") | .message.content[]? | select(.type == "tool_use" and .name == "SubagentHandback") | .input.message // empty' || true
}

subagent_report() {
  local input="$1"
  local transcript last_message
  transcript="$(jq -r '.agent_transcript_path // empty' <<<"$input")"
  last_message="$(jq -r '.last_assistant_message // empty' <<<"$input")"
  printf '%s\n%s\n' "$(handback_report "$transcript")" "$last_message"
}
