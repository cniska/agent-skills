readonly WAIT_HOLD_SECONDS="${CNISKA_WAIT_HOLD_SECONDS:-240}"
readonly WAIT_POLL_SECONDS=2
readonly HOST_STOP_BLOCK_CAP=8
readonly STOP_BLOCK_GUARD=$((HOST_STOP_BLOCK_CAP - 2))

still_held() {
  local id="$1" runs="$2"
  [ -z "$(ended_runs "$runs")" ] || return 1
  [ -z "$(waits_in_state "$id" waiting)" ] || return 0
  [ -n "$runs" ] && [ -z "$(waits_in_state "$id" ended)" ]
}

hold_wait() {
  local id="$1" runs="$2" started
  started="$(date +%s)"
  while still_held "$id" "$runs" && [ "$(($(date +%s) - started))" -lt "$WAIT_HOLD_SECONDS" ]; do
    sleep "$WAIT_POLL_SECONDS"
  done
}

stop_blocks_in_a_row() {
  local transcript="$1"
  [ -n "$transcript" ] && [ -f "$transcript" ] || {
    printf '0\n'
    return
  }
  jq -nR 'reduce (inputs | fromjson? | objects) as $line (0;
    if $line.type == "assistant" and any($line.message.content[]?; .type == "tool_use") then 0
    elif $line.type == "attachment" and $line.attachment.type == "hook_blocking_error" and $line.attachment.hookEvent == "SubagentStop" then . + 1
    else . end)' "$transcript"
}

stop_block_guard() {
  local input="$1" blocks
  [ "$(jq -r '.hook_event_name // empty' <<<"$input")" = SubagentStop ] || return 0
  blocks="$(stop_blocks_in_a_row "$(agent_transcript "$input")")"
  [ "$blocks" -ge "$STOP_BLOCK_GUARD" ] || return 0
  printf ' Your last %s stops were blocked in a row, and the host ends a turn after %s: make one tool call, such as reading the output so far, before you end your turn again.' "$blocks" "$HOST_STOP_BLOCK_CAP"
}
