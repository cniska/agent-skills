tool_uses() {
  local transcript="$1" name="$2"
  if [ -z "$transcript" ] || [ ! -f "$transcript" ]; then
    return
  fi
  grep -F "\"$name\"" -- "$transcript" 2>/dev/null |
    jq -c --arg name "$name" 'select(.type == "assistant") | .message.content[]? | select(.type == "tool_use" and .name == $name) | .input' 2>/dev/null || true
}

pending_launches() {
  local transcript="$1"
  if [ -z "$transcript" ] || [ ! -f "$transcript" ]; then
    return
  fi
  jq -nRr '
    [inputs | fromjson? | objects] as $lines
    | [$lines[] | select(.type == "assistant") | .message.content[]? | select(.type == "tool_use")] as $calls
    | [$calls[]
        | select(
            (.name == "Agent" and .input.run_in_background != false)
            or (.name == "Bash" and .input.run_in_background == true)
            or .name == "Monitor")
        | .id] as $launched
    | [$lines[] | select(.type != "assistant") | .. | strings
        | scan("<task-notification>\\s*<task-id>[^<]*</task-id>\\s*<tool-use-id>([^<]+)</tool-use-id>")[0]] as $notified
    | [$calls[] | select(.name == "TaskStop") | .input.task_id | strings] as $stopped
    | [$lines[] | select(.type == "user") | .message.content[]? | objects | select(.type == "tool_result")
        | {id: .tool_use_id, text: ([.content | .. | strings] | join("\n"))}
        | select(.text as $text | any($stopped[]; . as $task | $text | test("\\b\($task)\\b")))
        | .id] as $halted
    | ($launched - $notified - $halted)[]' "$transcript" 2>/dev/null || true
}
