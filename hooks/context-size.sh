#!/usr/bin/env bash
set -euo pipefail

readonly SUGGEST_HANDOFF_AT_TOKENS=300000
readonly TRANSCRIPT_TAIL_LINES=400

warn() {
  printf 'context-size.sh: %s\n' "$1" >&2
}

latest_reply() {
  tail -n "$TRANSCRIPT_TAIL_LINES" "$1" |
    jq -cR 'fromjson? | select(.type == "assistant" and .isSidechain != true)' |
    tail -n 1
}

context_tokens() {
  jq '.message.usage // {} | [.input_tokens, .cache_read_input_tokens, .cache_creation_input_tokens] | if all(type == "number") then add else empty end' <<<"$1"
}

main() {
  if ! command -v jq >/dev/null; then
    warn "jq is not installed, so the context size cannot be read"
    exit 1
  fi
  if [ -z "${CLAUDE_PLUGIN_DATA:-}" ]; then
    warn "CLAUDE_PLUGIN_DATA is not set, so a suggestion cannot be remembered"
    exit 1
  fi
  local input transcript session
  input="$(cat)"
  transcript="$(jq -r '.transcript_path // empty' <<<"$input")"
  session="$(jq -r '.session_id // empty' <<<"$input")"
  if [ -z "$transcript" ] || [ ! -f "$transcript" ] || [ -z "$session" ]; then
    warn "no transcript or session id in the hook input, so the context size is unknown"
    return
  fi

  local reply tokens
  reply="$(latest_reply "$transcript")"
  if [ -z "$reply" ]; then
    return
  fi
  tokens="$(context_tokens "$reply")"
  if [ -z "$tokens" ]; then
    warn "the latest reply has no message.usage input_tokens, cache_read_input_tokens and cache_creation_input_tokens; the transcript format may have changed"
    return
  fi

  local marker="$CLAUDE_PLUGIN_DATA/handoff-suggested/$session"
  if ((tokens < SUGGEST_HANDOFF_AT_TOKENS)); then
    rm -f "$marker"
    return
  fi
  if [ -e "$marker" ]; then
    return
  fi
  mkdir -p "${marker%/*}"
  : >"$marker"
  printf "This session's context holds about %dk tokens. Offer a handoff at the next step boundary, as the handoff skill says.\n" $((tokens / 1000))
}

main "$@"
