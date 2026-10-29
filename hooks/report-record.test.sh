#!/usr/bin/env bash
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RECORD="$HERE/report-record.sh"

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
source "$HERE/jq-past-shims.test-harness.sh"
link_jq_past_shims "$scratch"
export CLAUDE_PLUGIN_DATA="$scratch/data"
require_jq

readonly REVIEWER=cniska-skills:reviewer
readonly DESIGNER=cniska-skills:designer
readonly RESEARCHER=cniska-skills:researcher
readonly WORKER=cniska-skills:worker
readonly PREFIX=mcp__plugin_cniska-skills_report__
readonly LOG="$CLAUDE_PLUGIN_DATA/events.jsonl"

readonly LOCATION='{"path": "/repo/app.py", "line": 3}'
readonly FINDING='{"where": ['"$LOCATION"'], "rule": "Fix the cause", "severity": "major", "why": "It hides the cause.", "instead": "Inject it."}'
readonly VERDICT='{"diffs": ["/tmp/change.diff"], "judgments": [{"repo": "/repo", "verdict": "return", "findings": ['"$FINDING"'], "conflicts": [], "follow_ups": [], "clean": []}]}'
readonly RESEARCH='{"recommendation": "Go ahead.", "evidence": [{"claim": "It exists.", "source": {"kind": "file", "ref": "a.ts:1"}}], "against": "Cost.", "owner_conflicts": [], "unverified": [], "sort": "proposal"}'
readonly TASK_REPORT='{"task": "t", "outcome": "parked", "summary": "Parked.", "choices": [], "owner_questions": [], "follow_ups": [], "open": ["slice 1"], "steps_skipped": [], "plugin_update_due": false}'

fresh_agent() {
  local count
  count="$(cat "$scratch/agents" 2>/dev/null || printf '0')"
  count=$((count + 1))
  printf '%s\n' "$count" >"$scratch/agents"
  printf 'agent%s\n' "$count"
}

call() {
  local agent="$1" type="$2" tool="$3" payload="$4"
  jq -cn --arg agent "$agent" --arg type "$type" --arg tool "$PREFIX$tool" --argjson payload "$payload" '
    {hook_event_name: "PreToolUse", session_id: "parent1", tool_name: $tool, tool_input: $payload}
    + (if $agent == "" then {} else {agent_id: $agent} end)
    + (if $type == "" then {} else {agent_type: $type} end)' | "$RECORD" 2>/dev/null
}

top_level_call() {
  jq -cn --arg session "$1" --arg tool "$PREFIX$2" --argjson payload "$3" \
    '{hook_event_name: "PreToolUse", session_id: $session, agent_type: "cniska-skills:worker", tool_name: $tool, tool_input: $payload}' | "$RECORD" 2>/dev/null
}

handback() {
  jq -cn --arg agent "$1" --arg type "$2" \
    '{hook_event_name: "PreToolUse", session_id: "parent1", agent_id: $agent, agent_type: $type, tool_name: "SubagentHandback", tool_input: {message: "Done."}}' | "$RECORD" 2>/dev/null
}

subagent_stop() {
  jq -cn --arg agent "$1" --arg type "$2" --arg transcript "${3:-}" '
    {hook_event_name: "SubagentStop", session_id: "parent1", agent_id: $agent, agent_type: $type, last_assistant_message: "Done."}
    + (if $transcript == "" then {} else {agent_transcript_path: $transcript} end)' | "$RECORD" 2>/dev/null
}

session_stop() {
  jq -cn --arg session "$1" --arg type "$2" '
    {hook_event_name: "Stop", session_id: $session, stop_hook_active: false}
    + (if $type == "" then {} else {agent_type: $type} end)' | "$RECORD" 2>/dev/null
}

decision() { jq -r '.hookSpecificOutput.permissionDecision // .decision // empty' <<<"$1"; }
reason() { jq -r '.hookSpecificOutput.permissionDecisionReason // .reason // empty' <<<"$1"; }
stored() { cat "$CLAUDE_PLUGIN_DATA/reports/$1.json" 2>/dev/null; }
last_gate() { jq -sc '[.[] | select(.event == "gate")] | last | [.gate, .decision, .reason]' "$LOG"; }

agent="$(fresh_agent)"
out="$(call "$agent" "$DESIGNER" verdict "$VERDICT")"
assert "a designer's well-formed verdict is allowed without a prompt" "$(decision "$out")" allow
assert "the verdict is stored with who made it" "$(stored "$agent" | jq -c '[.tool, .agent_type, .agent_id, .session_id, .gate]')" \
  '["verdict","cniska-skills:designer","'"$agent"'","parent1",{"recorded":true}]'
assert "the stored payload is the call's input" "$(stored "$agent" | jq -c .payload)" "$(jq -c . <<<"$VERDICT")"
out="$(call "$agent" "$DESIGNER" verdict "$VERDICT")"
assert "a second report is refused" "$(decision "$out")" deny
assert "the refusal says to hand back" "$(reason "$out")" "Your report is already stored, and a report is made once. Hand back now with a one-line message."
assert "an already_reported refusal is logged" "$(last_gate)" '["verdict","deny","already_reported"]'
assert "a third report is refused too, with no bound" "$(decision "$(call "$agent" "$DESIGNER" verdict "$VERDICT")")" deny
assert "the first report stays as stored" "$(stored "$agent" | jq -c .payload)" "$(jq -c . <<<"$VERDICT")"

read_back() {
  jq -cn --arg id "$1" '{jsonrpc: "2.0", id: 1, method: "tools/call", params: {name: "read_report", arguments: {id: $id}}}' |
    "$HERE/../mcp/report-server.sh" | jq -c '.result.structuredContent'
}
assert "the report server reads back what the hook stored" "$(read_back "$agent")" "$(stored "$agent" | jq -c .)"

agent="$(fresh_agent)"
assert "a researcher's research is allowed" "$(decision "$(call "$agent" "$RESEARCHER" research "$RESEARCH")")" allow
assert "the research is stored" "$(stored "$agent" | jq -r .tool)" research
agent="$(fresh_agent)"
assert "a worker subagent's task report is allowed" "$(decision "$(call "$agent" "$WORKER" task_report "$TASK_REPORT")")" allow
assert "a top-level worker's task report is allowed" "$(decision "$(top_level_call session9 task_report "$TASK_REPORT")")" allow
assert "a top-level worker's report is stored under its session id" "$(stored session9 | jq -c '[.agent_id, .session_id]')" '[null,"session9"]'

agent="$(fresh_agent)"
out="$(call "$agent" "$REVIEWER" verdict '{"diffs": "/tmp/x.diff", "judgments": []}')"
assert "a payload off the schema is refused" "$(decision "$out")" deny
assert "the refusal names every violation and the fix" "$(reason "$out")" \
  "The report does not match the verdict tool's schema:
/diffs must be of type array
/judgments must hold at least 1 item
Call the tool again with each of these fixed."
assert "a refused payload is not stored" "$(stored "$agent")" ""
assert "a payload_invalid refusal is logged" "$(last_gate)" '["verdict","deny","payload_invalid"]'
out="$(call "$agent" "$REVIEWER" verdict '{"diffs": "/tmp/x.diff", "judgments": []}')"
assert "past the bound, the same refusal is allowed" "$(decision "$out")" allow
assert "past the bound, the payload is stored as not recorded" "$(stored "$agent" | jq -c .gate)" '{"recorded":false,"code":"payload_invalid"}'
assert "the allow past the bound is logged" "$(last_gate)" '["verdict","allow","payload_invalid"]'

agent="$(fresh_agent)"
out="$(call "$agent" "$RESEARCHER" verdict "$VERDICT")"
assert "a verdict from a researcher is refused" "$(decision "$out")" deny
assert "the refusal names who may call the tool" "$(reason "$out")" \
  "Only cniska-skills:reviewer or cniska-skills:designer report through verdict; this session is cniska-skills:researcher. Hand back as your own instructions say."
assert "a wrong_agent refusal stores nothing" "$(stored "$agent")" ""
assert "a wrong_agent refusal is logged" "$(last_gate)" '["verdict","deny","wrong_agent"]'
out="$(call "" "" verdict "$VERDICT")"
assert "a verdict from the parent session is refused" "$(reason "$out")" \
  "Only cniska-skills:reviewer or cniska-skills:designer report through verdict; this session is not a cniska-skills agent. Hand back as your own instructions say."
assert "a task report from a reviewer is refused" "$(decision "$(call "$(fresh_agent)" "$REVIEWER" task_report "$TASK_REPORT")")" deny
assert "the caller is checked before the shape" \
  "$(reason "$(call "$(fresh_agent)" "$RESEARCHER" verdict '{}')")" \
  "Only cniska-skills:reviewer or cniska-skills:designer report through verdict; this session is cniska-skills:researcher. Hand back as your own instructions say."
strayed="$(fresh_agent)"
call "$strayed" "$DESIGNER" research "$RESEARCH" >/dev/null
assert "a second call with the wrong tool is still refused" "$(decision "$(call "$strayed" "$DESIGNER" research "$RESEARCH")")" deny
assert "calls with the wrong tool store nothing" "$(stored "$strayed")" ""
assert "after calls with the wrong tool, the agent's own report is allowed" "$(decision "$(call "$strayed" "$DESIGNER" verdict "$VERDICT")")" allow

pairing() { reason "$(call "$(fresh_agent)" "$1" "$2" "$(jq -c "$3" <<<"$4")")" | sed -n 2p; }
assert "a drop needs its reason" "$(pairing "$RESEARCHER" research '.sort = "drop"' "$RESEARCH")" '/drop_reason is required when /sort is "drop"'
assert "a drop reason needs a drop" "$(pairing "$RESEARCHER" research '.drop_reason = "Old."' "$RESEARCH")" '/drop_reason is given only when /sort is "drop"'
assert "a drop with its reason is allowed" \
  "$(decision "$(call "$(fresh_agent)" "$RESEARCHER" research "$(jq -c '.sort = "drop" | .drop_reason = "Old."' <<<"$RESEARCH")")")" allow
assert "a landed outcome needs the landing" "$(pairing "$WORKER" task_report '.outcome = "landed"' "$TASK_REPORT")" '/landed is required when /outcome is "landed"'
assert "a landing needs a landed outcome" \
  "$(pairing "$WORKER" task_report '.landed = {repo: "/repo", branch: "main", sha: "0123456789abcdef0123456789abcdef01234567", ci_runs: []}' "$TASK_REPORT")" \
  '/landed is given only when /outcome is "landed"'
assert "a ready plan needs its path" "$(pairing "$WORKER" task_report '.outcome = "plan_ready"' "$TASK_REPORT")" '/plan is required when /outcome is "plan_ready"'
assert "a reason on an accept is refused" \
  "$(pairing "$DESIGNER" verdict '.judgments[0] |= (.verdict = "accept" | .findings = [] | .reason = "run_short")' "$VERDICT")" \
  '/judgments/0/reason is given only when /judgments/0/verdict is "return"'
assert "a designer's no_diff return is allowed" \
  "$(decision "$(call "$(fresh_agent)" "$DESIGNER" verdict "$(jq -c '.judgments[0].reason = "no_diff"' <<<"$VERDICT")")")" allow
assert "a designer's run reason on a return is allowed" \
  "$(decision "$(call "$(fresh_agent)" "$DESIGNER" verdict "$(jq -c '.judgments[0].reason = "verify_gap"' <<<"$VERDICT")")")" allow

agent="$(fresh_agent)"
out="$(handback "$agent" "$REVIEWER")"
assert "a reviewer handing back with no report is refused" "$(decision "$out")" deny
assert "the refusal names the tool to call" "$(reason "$out")" \
  "Call ${PREFIX}verdict with your report before you end. Your caller reads the report from that call, not from your final message."
assert "a missing_report refusal is logged" "$(last_gate)" '["verdict","deny","missing_report"]'
assert "past the bound, the hand-back goes through" "$(handback "$agent" "$REVIEWER")" ""
assert "the allow past the bound is logged" "$(last_gate)" '["verdict","allow","missing_report"]'
agent="$(fresh_agent)"
call "$agent" "$DESIGNER" verdict "$VERDICT" >/dev/null
assert "a hand-back after a report goes through" "$(handback "$agent" "$DESIGNER")" ""
assert "a worker's refusal names task_report" "$(reason "$(handback "$(fresh_agent)" "$WORKER")")" \
  "Call ${PREFIX}task_report with your report before you end. Your caller reads the report from that call, not from your final message."
assert "an agent with no report tool hands back freely" "$(handback "$(fresh_agent)" general-purpose)" ""

agent="$(fresh_agent)"
out="$(subagent_stop "$agent" "$RESEARCHER")"
assert "a researcher stopping with no report is blocked" "$(decision "$out")" block
assert "the block names research" "$(reason "$out")" \
  "Call ${PREFIX}research with your report before you end. Your caller reads the report from that call, not from your final message."
handed="$scratch/handed.jsonl"
jq -cn '{type: "assistant", message: {content: [{type: "tool_use", name: "SubagentHandback", input: {message: "Done."}}]}}' >"$handed"
assert "a stop after a hand-back the hook already judged is left alone" "$(subagent_stop "$(fresh_agent)" "$RESEARCHER" "$handed")" ""

late="$scratch/late.jsonl"
readonly HANDBACK_LINE='{"type": "assistant", "message": {"content": [{"type": "tool_use", "name": "SubagentHandback", "input": {"message": "Done."}}]}}'
readonly TEXT_LINE='{"type": "assistant", "message": {"content": [{"type": "text", "text": "Looking again."}]}}'
stop_late() {
  (sleep 0.5 && printf '%s\n' "$1" >>"$late") &
  subagent_stop "$(fresh_agent)" "$RESEARCHER" "$late"
  wait
}
printf '%s\n' '{"type": "assistant", "message": {"content": [{"type": "tool_use", "name": "Read", "input": {"file_path": "/tmp/a"}}]}}' >"$late"
assert "a stop whose hand-back reaches the transcript late is left to the hand-back hook" "$(stop_late "$HANDBACK_LINE")" ""
printf '%s\n%s\n' "$HANDBACK_LINE" '{"type": "attachment", "attachment": {"type": "hook_blocking_error"}}' >"$late"
assert "a text end after a blocked hand-back is judged, not left to the earlier hand-back" "$(decision "$(stop_late "$TEXT_LINE")")" block
printf '%s\n%s\n' "$HANDBACK_LINE" '{"type": "user", "message": {"content": "Look again."}}' >"$late"
assert "a text end after a resume is judged, not left to the earlier hand-back" "$(decision "$(stop_late "$TEXT_LINE")")" block

out="$(session_stop session7 "$WORKER")"
assert "a top-level worker stopping with no report is blocked" "$(decision "$out")" block
assert "past the session's bound, it stops" "$(session_stop session7 "$WORKER")" ""
top_level_call session8 task_report "$TASK_REPORT" >/dev/null
assert "a top-level worker with a report stops" "$(session_stop session8 "$WORKER")" ""
assert "a session with no agent type stops" "$(session_stop session6 "")" ""

assert "read_report is not judged" "$(call "$(fresh_agent)" "$REVIEWER" read_report '{"id": "a1"}')" ""
assert "another tool is not judged" \
  "$(jq -cn '{hook_event_name: "PreToolUse", agent_id: "x1", agent_type: "cniska-skills:reviewer", tool_name: "Bash", tool_input: {command: "ls"}}' | "$RECORD" 2>/dev/null)" ""

err="$(jq -cn --arg tool "${PREFIX}verdict" --argjson payload "$VERDICT" \
  '{hook_event_name: "PreToolUse", agent_id: "../escape", agent_type: "cniska-skills:reviewer", tool_name: $tool, tool_input: $payload}' | "$RECORD" 2>&1 >/dev/null)"
assert "an id that cannot be a file name fails loudly" "$err" \
  "report-record.sh: the hook input has no agent_id or session_id a report can be kept under"
assert "nothing is stored outside the reports folder" "$(find "$CLAUDE_PLUGIN_DATA" -name 'escape*' | wc -l | tr -d ' ')" 0

assert "every logged line is one JSON object" "$(jq -s 'all(type == "object")' "$LOG")" true
assert "every gate line has the same fields" "$(jq -s '[.[] | select(.event == "gate") | keys] | unique | length' "$LOG")" 1

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
