#!/usr/bin/env bash
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORT="$HERE/coach-report.sh"

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

readonly PROPOSALS_REASON="End your report with a last line that is exactly 'Proposals: <n>', counting the proposals other than one-offs."
MISSING="$(jq -cn --arg reason "$PROPOSALS_REASON" '{decision: "block", reason: $reason}')"
REFUSED="$(jq -cn --arg reason "$PROPOSALS_REASON" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}}')"
readonly MISSING REFUSED

fresh_bound() {
  if [ "${1:-}" != again ]; then
    rm -rf "$CLAUDE_PLUGIN_DATA/denials"
  fi
}

report_handback() {
  fresh_bound "${2:-}"
  jq -cn --arg message "$1" --arg type "${3:-cniska-skills:coach}" \
    '{hook_event_name: "PreToolUse", tool_name: "SubagentHandback", tool_input: {message: $message}, agent_type: $type, agent_id: "c1"}' | "$REPORT" 2>/dev/null
}

report_last_message() {
  fresh_bound "${2:-}"
  jq -cn --arg message "$1" \
    '{hook_event_name: "SubagentStop", agent_type: "cniska-skills:coach", agent_id: "c1", last_assistant_message: $message}' | "$REPORT" 2>/dev/null
}

assert "a report with no Proposals line keeps the coach running" "$(report_last_message 'Nothing much.')" "$MISSING"
assert "a Proposals count that is not a number keeps the coach running" "$(report_last_message $'Done.\nProposals: some')" "$MISSING"
assert "a Proposals line not on its own line does not count" "$(report_last_message 'My Proposals: 2')" "$MISSING"
assert "a missing Proposals line on the second stop lets the coach stop" "$(report_last_message 'Still none.' again)" ""
assert "a good report in the last message says nothing" "$(report_last_message $'Two things.\nProposals: 2')" ""
assert "a good report in a hand-back says nothing" "$(report_handback $'Nothing clears the bar.\nProposals: 0')" ""
assert "a hand-back with no Proposals line is refused while the coach runs" "$(report_handback 'Forgot the count.')" "$REFUSED"
assert "a second hand-back with no Proposals line goes through" "$(report_handback 'Forgot the count.' again)" ""
assert "a stop after that hand-back is let through by the same bound" "$(report_last_message 'Forgot the count.' again)" ""
assert "a hand-back from an agent other than the coach is not judged" "$(report_handback 'No count.' '' general-purpose)" ""
assert "a stop of an agent other than the coach is not judged" \
  "$(jq -cn '{hook_event_name: "SubagentStop", agent_type: "general-purpose", agent_id: "w1", last_assistant_message: "No count."}' | "$REPORT" 2>/dev/null)" ""

hooks="$HERE/hooks.json"
stop_commands() { jq -r '.hooks.SubagentStop[] | select(has("matcher") | not) | .hooks[].command' "$hooks"; }
handback_commands() { jq -r '.hooks.PreToolUse[] | select(.matcher == "SubagentHandback") | .hooks[].command' "$hooks"; }
assert "every subagent's stop is checked by the coach report once" "$(stop_commands | grep -c '/hooks/coach-report\.sh$')" 1
assert "no subagent's stop runs a task coach" "$(stop_commands | grep -c '/hooks/task-coach\.sh$')" 0
assert "every hand-back is checked by the coach report once" "$(handback_commands | grep -c '/hooks/coach-report\.sh$')" 1
assert "no hand-back runs a task coach" "$(handback_commands | grep -c '/hooks/task-coach\.sh$')" 0
assert "no session start runs a coach schedule" "$(jq -r '.hooks.SessionStart[].hooks[].command' "$hooks" | grep -c coach)" 0

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
