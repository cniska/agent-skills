#!/usr/bin/env bash
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$HERE/context-size.sh"

pass=0
fail=0
assert() {
  if [ "$2" = "$3" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    printf 'FAIL %s\n  want: [%s]\n  got:  [%s]\n' "$1" "$3" "$2"
  fi
}

scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
export CLAUDE_PLUGIN_DATA="$scratch/data"

readonly NOTE_250K="This session's context holds about 250k tokens. Offer a handoff at the next step boundary, as the handoff skill says."

assistant_entry() {
  jq -cn --argjson input "$1" --argjson read "$2" --argjson write "$3" --argjson side "${4:-false}" \
    '{type: "assistant", isSidechain: $side, message: {role: "assistant", usage: {input_tokens: $input, cache_read_input_tokens: $read, cache_creation_input_tokens: $write, output_tokens: 10}}}'
}

transcript_with() {
  local file="$scratch/$1.jsonl"
  shift
  : >"$file"
  local line
  for line in "$@"; do
    printf '%s\n' "$line" >>"$file"
  done
  printf '%s' "$file"
}

hook_input() {
  jq -cn --arg transcript "$1" --arg session "$2" \
    '{hook_event_name: "UserPromptSubmit", session_id: $session, transcript_path: $transcript, cwd: "/tmp", prompt: "next"}'
}

prompt() { hook_input "$1" "$2" | "$HOOK" 2>/dev/null; }
prompt_stderr() { hook_input "$1" "$2" | { "$HOOK" >/dev/null; } 2>&1; }
exit_code() {
  hook_input "$1" "$2" | "$HOOK" >/dev/null 2>&1
  echo "$?"
}

user_entry='{"type":"user","message":{"role":"user","content":"hi"}}'

fresh="$(transcript_with fresh "$user_entry")"
assert "a session with no reply yet says nothing" "$(prompt "$fresh" s-fresh)" ""

small="$(transcript_with small "$user_entry" "$(assistant_entry 2 150000 1000)")"
assert "a context under the threshold says nothing" "$(prompt "$small" s-small)" ""

large="$(transcript_with large "$user_entry" "$(assistant_entry 2 240000 9998)")"
assert "a context over the threshold suggests a handoff" "$(prompt "$large" s-large)" "$NOTE_250K"
assert "the suggestion comes once per session" "$(prompt "$large" s-large)" ""
assert "another session gets its own suggestion" "$(prompt "$large" s-other)" "$NOTE_250K"

shrunk="$(transcript_with shrunk "$user_entry" "$(assistant_entry 2 60000 0)")"
assert "a context that shrank below the threshold says nothing" "$(prompt "$shrunk" s-large)" ""
assert "growing past the threshold again suggests again" "$(prompt "$large" s-large)" "$NOTE_250K"

below="$(transcript_with below "$(assistant_entry 0 199999 0)")"
at="$(transcript_with at "$(assistant_entry 0 200000 0)")"
assert "199999 tokens is under the threshold" "$(prompt "$below" s-below)" ""
assert "200000 tokens reaches the threshold" "$(prompt "$at" s-at)" "This session's context holds about 200k tokens. Offer a handoff at the next step boundary, as the handoff skill says."

side="$(transcript_with side "$(assistant_entry 2 10000 0)" "$(assistant_entry 2 900000 0 true)")"
assert "a subagent's entry does not count toward the session's context" "$(prompt "$side" s-side)" ""

latest="$(transcript_with latest "$(assistant_entry 2 900000 0)" "$user_entry" "$(assistant_entry 2 10000 0)")"
assert "only the latest reply's usage counts" "$(prompt "$latest" s-latest)" ""

broken="$(transcript_with broken "$(assistant_entry 2 240000 9998)" 'not json {')"
assert "a malformed line is skipped" "$(prompt "$broken" s-broken)" "$NOTE_250K"

renamed="$(transcript_with renamed '{"type":"assistant","isSidechain":false,"message":{"role":"assistant","usage":{"prompt_tokens":250000}}}')"
assert "usage in an unknown shape says nothing to the model" "$(prompt "$renamed" s-renamed)" ""
assert "usage in an unknown shape warns on stderr" "$(prompt_stderr "$renamed" s-renamed | grep -c 'transcript format may have changed')" 1
assert "usage in an unknown shape never blocks the prompt" "$(exit_code "$renamed" s-renamed)" 0

assert "a missing transcript says nothing" "$(prompt "$scratch/none.jsonl" s-none)" ""
assert "a missing transcript warns on stderr" "$(prompt_stderr "$scratch/none.jsonl" s-none | grep -c 'no transcript')" 1
assert "a missing transcript never blocks the prompt" "$(exit_code "$scratch/none.jsonl" s-none)" 0

assert "no plugin data directory fails without blocking the prompt" \
  "$(jq -cn --arg t "$large" '{session_id: "s-nodata", transcript_path: $t}' | env -u CLAUDE_PLUGIN_DATA "$HOOK" >/dev/null 2>&1; echo "$?")" 1

hooks="$HERE/hooks.json"
assert "every prompt runs the context check" "$(jq -r '.hooks.UserPromptSubmit[0].hooks[0].command' "$hooks")" "\"\${CLAUDE_PLUGIN_ROOT}\"/hooks/context-size.sh"

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
