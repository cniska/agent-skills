readonly EVENT_LOG_VERSION=1

event_log_warn() {
  printf '%s: the event log was not written: %s\n' "${0##*/}" "$1" >&2
}

event_log() {
  local input="$1" kind="$2"
  shift 2
  local line
  if ! line="$(jq -cRs --argjson v "$EVENT_LOG_VERSION" --arg event "$kind" "$@" \
    '((fromjson? | objects) // {}) as $in
      | {v: $v, ts: (now | todate), event: $event, session: ($in.session_id // null), agent: ($in.agent_id // null), cwd: ($in.cwd // null)}
      + ($ARGS.named | del(.v, .event) | map_values(if . == "" then null else . end))' <<<"$input" 2>/dev/null)"; then
    event_log_warn "jq could not build the line"
    return 0
  fi
  if [ -z "${CLAUDE_PLUGIN_DATA:-}" ]; then
    event_log_warn "CLAUDE_PLUGIN_DATA is not set"
    return 0
  fi
  { mkdir -p "$CLAUDE_PLUGIN_DATA" && printf '%s\n' "$line" >>"$CLAUDE_PLUGIN_DATA/events.jsonl"; } 2>/dev/null ||
    event_log_warn "$CLAUDE_PLUGIN_DATA/events.jsonl cannot be appended to"
  return 0
}
