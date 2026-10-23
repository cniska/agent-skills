#!/usr/bin/env bash
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RECORD="$HERE/permission-record.sh"

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

scratch="$(mktemp -d)" || exit 1
trap 'rm -rf "$scratch"' EXIT
export CLAUDE_PLUGIN_DATA="$scratch/data"
source "$HERE/jq-past-shims.test-harness.sh"
require_jq
log="$CLAUDE_PLUGIN_DATA/events.jsonl"
readonly HOOK_COMMAND="\"\${CLAUDE_PLUGIN_ROOT}\"/hooks/permission-record.sh"

request() {
  jq -cn --arg agent "${1:-}" \
    '{session_id: "s1", cwd: "/work", hook_event_name: "PermissionRequest", tool_name: "Bash", tool_input: {command: "rm -rf build SECRET=hunter2"}}
      + (if $agent == "" then {} else {agent_id: $agent} end)' | "$RECORD"
}

denied() {
  jq -cn --arg reason "$1" \
    '{session_id: "s1", agent_id: "a1", cwd: "/work", hook_event_name: "PermissionDenied", tool_name: "Bash", tool_use_id: "toolu_1", tool_input: {command: "git push --force"}, reason: $reason}' | "$RECORD"
}

last() { tail -n 1 "$log" | jq -c 'del(.ts)'; }

assert "a permission request prints nothing, so the prompt shows as usual" "$(request 2>&1)" ""
assert "a permission request logs the prompt and the tool, not its input" "$(last)" \
  '{"v":1,"event":"permission_prompt","session":"s1","agent":null,"cwd":"/work","tool":"Bash"}'
request a1 >/dev/null 2>&1
assert "a request in a subagent names the agent" "$(last | jq -r .agent)" a1
assert "no line holds the tool's input" "$(grep -c 'hunter2\|push --force' "$log")" 0

denied '[Irreversible Local Destruction]' >/dev/null 2>&1
assert "a classifier denial logs the rule" "$(last)" \
  '{"v":1,"event":"permission_denied","session":"s1","agent":"a1","cwd":"/work","tool":"Bash","tool_use":"toolu_1","reason":"rule","rule":"Irreversible Local Destruction"}'
denied 'Auto mode could not evaluate this action and is blocking it for safety.' >/dev/null 2>&1
assert "a denial without a verdict logs unevaluated" "$(last | jq -c '[.reason, .rule]')" '["unevaluated",null]'
denied 'Classifier unavailable' >/dev/null 2>&1
assert "a denial with no classifier logs classifier_unavailable" "$(last | jq -c '[.reason, .rule]')" '["classifier_unavailable",null]'
denied 'Something new' >/dev/null 2>&1
assert "an unknown denial reason logs other, without its text" "$(last | jq -c '[.reason, .rule]')" '["other",null]'
assert "no line holds a denial's free text" "$(grep -c 'Something new' "$log")" 0
assert "a denial prints nothing, so auto mode decides alone" "$(denied '[Rule]' 2>&1)" ""

assert "every line is one JSON object" "$(jq -s 'all(type == "object")' "$log")" true
assert "every line of a kind has the same fields" "$(jq -s 'group_by(.event) | all(map(keys) | unique | length == 1)' "$log")" true

mv "$log" "$log.kept"
mkdir "$log"
assert "an unwritable log prints nothing on stdout" "$(request 2>/dev/null)" ""
assert "an unwritable log exits 0" "$(request >/dev/null 2>&1; echo "$?")" 0
assert "an unwritable log warns on stderr" "$(request 2>&1 >/dev/null | grep -c '^permission-record.sh: the event log was not written')" 1
rmdir "$log"
mv "$log.kept" "$log"

assert "no plugin data exits 0" "$(env -u CLAUDE_PLUGIN_DATA bash -c "printf '{}' | '$RECORD'" >/dev/null 2>&1; echo "$?")" 0
assert "input that is not JSON exits 0" "$(printf 'not json' | "$RECORD" >/dev/null 2>&1; echo "$?")" 0

assert "the recorder listens to permission requests" "$(jq -r '.hooks.PermissionRequest[0].hooks[0].command' "$HERE/hooks.json")" "$HOOK_COMMAND"
assert "the recorder listens to auto mode denials" "$(jq -r '.hooks.PermissionDenied[0].hooks[0].command' "$HERE/hooks.json")" "$HOOK_COMMAND"

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
