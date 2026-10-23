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
    def started_task:
      first(
        scan("\\ACommand running in background with ID: ([A-Za-z0-9_-]+)")[0],
        scan("\\ACommand did not complete within [^\\n]* and was moved to the background \\(ID: ([A-Za-z0-9_-]+)\\)")[0],
        scan("\\AMonitor started \\(task ([A-Za-z0-9_-]+),")[0],
        scan("\\AAsync agent launched successfully\\.[\\s\\S]*?agentId: ([A-Za-z0-9_-]+)")[0]);
    [inputs | fromjson? | objects] as $lines
    | [$lines[] | select(.type == "assistant") | .message.content[]? | select(.type == "tool_use")] as $calls
    | [$calls[] | select(.name == "Agent" or .name == "Bash" or .name == "Monitor") | .id] as $launchers
    | [$lines[] | select(.type == "user") | .message.content[]? | objects
        | select(.type == "tool_result" and (.tool_use_id | IN($launchers[])))
        | {id: .tool_use_id, task: (.content | if type == "string" then . else [.[]? | select(.type == "text") | .text] | join("\n") end | started_task)}] as $started
    | [$lines[] | select(.type != "assistant") | .. | strings
        | scan("<task-notification>\\s*<task-id>[^<]*</task-id>\\s*<tool-use-id>([^<]+)</tool-use-id>")[0]] as $notified
    | [$calls[] | select(.name == "TaskStop") | .input.task_id | strings] as $stopped
    | $started[] | select((.id | IN($notified[]) | not) and (.task | IN($stopped[]) | not)) | .id' "$transcript" 2>/dev/null || true
}
