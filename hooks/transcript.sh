tool_uses() {
  local transcript="$1" name="$2"
  if [ -z "$transcript" ] || [ ! -f "$transcript" ]; then
    return
  fi
  grep -F "\"$name\"" -- "$transcript" 2>/dev/null |
    jq -c --arg name "$name" 'select(.type == "assistant") | .message.content[]? | select(.type == "tool_use" and .name == $name) | .input' 2>/dev/null || true
}
