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
readonly VERDICT='{"diffs": ["/tmp/change.diff"], "judgments": [{"repo": "/repo", "verdict": "return", "findings": ['"$FINDING"'], "conflicts": [], "follow_ups": []}]}'
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
  '["verdict","cniska-skills:designer","'"$agent"'","parent1",{"recorded":true,"returns":{"any_severity":1,"critical_or_major":1}}]'
assert "the stored payload is the call's input" "$(stored "$agent" | jq -c .payload)" "$(jq -c . <<<"$VERDICT")"
out="$(call "$agent" "$DESIGNER" verdict "$VERDICT")"
assert "a second report is refused" "$(decision "$out")" deny
assert "the refusal says to hand back" "$(reason "$out")" "Your report is already stored, and a report is made once per hand-back. Hand back now with a one-line message."
assert "an already_reported refusal is logged" "$(last_gate)" '["verdict","deny","already_reported"]'
assert "a third report is refused too, with no bound" "$(decision "$(call "$agent" "$DESIGNER" verdict "$VERDICT")")" deny
assert "the first report stays as stored" "$(stored "$agent" | jq -c .payload)" "$(jq -c . <<<"$VERDICT")"
assert "the stored report awaits its hand-back" "$(stored "$agent" | jq -c .handed_back)" false

resumed="$(fresh_agent)"
call "$resumed" "$WORKER" task_report "$(jq -c '.outcome = "plan_ready" | .plan = "/tmp/plan.md"' <<<"$TASK_REPORT")" >/dev/null
assert "a worker's hand-back after its report goes through" "$(handback "$resumed" "$WORKER")" ""
assert "that hand-back marks the report handed back" "$(stored "$resumed" | jq -c .handed_back)" true
LANDED_REPORT="$(jq -c '.outcome = "landed" | .landed = {repo: "/repo", branch: "main", sha: "0123456789abcdef0123456789abcdef01234567", ci_runs: []}' <<<"$TASK_REPORT")"
assert "a resumed worker's next report is allowed" "$(decision "$(call "$resumed" "$WORKER" task_report "$LANDED_REPORT")")" allow
assert "the next report replaces the handed-back one" "$(stored "$resumed" | jq -c '[.payload.outcome, .handed_back]')" '["landed",false]'
call "$resumed" "$WORKER" task_report "$LANDED_REPORT" >/dev/null
assert "a second report before that hand-back is refused" "$(last_gate)" '["verdict","deny","already_reported"]'
silent="$(fresh_agent)"
call "$silent" "$WORKER" task_report "$TASK_REPORT" >/dev/null
handback "$silent" "$WORKER" >/dev/null
assert "a resumed worker handing back with no new report is sent back" "$(decision "$(handback "$silent" "$WORKER")")" deny
assert "that refusal is missing_report" "$(last_gate)" '["verdict","deny","missing_report"]'
assert "past the bound, that resumed worker's end goes through" "$(handback "$silent" "$WORKER")" ""
assert "and its earlier hand-back's report is no longer stored" "$(stored "$silent")" ""
assert "resumed again with its bound spent and no report, it ends without being sent back" "$(handback "$silent" "$WORKER")" ""
twice_sent="$(fresh_agent)"
handback "$twice_sent" "$WORKER" >/dev/null
call "$twice_sent" "$WORKER" task_report "$TASK_REPORT" >/dev/null
handback "$twice_sent" "$WORKER" >/dev/null
assert "a worker sent back in an earlier run is sent back again after its resume" "$(decision "$(handback "$twice_sent" "$WORKER")")" deny

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
assert "past the bound, the payload is stored as not recorded" "$(stored "$agent" | jq -c 'del(.gate.returns) | .gate')" '{"recorded":false,"code":"payload_invalid"}'
assert "the allow past the bound is logged" "$(last_gate)" '["verdict","allow","payload_invalid"]'

unnamed() { jq -c --arg field "$1" --arg rule "$2" '.judgments[0][$field] = [.judgments[0].findings[0] | .rule = $rule]' <<<"$VERDICT"; }
agent="$(fresh_agent)"
out="$(call "$agent" "$REVIEWER" verdict "$(unnamed findings "Drift: roadmap written as shipped")")"
assert "a finding whose rule is no rule name is refused" "$(decision "$out")" deny
assert "the refusal names the finding and its rule" "$(reason "$out" | sed -n 1p)" \
  '/judgments/0/findings/0/rule "Drift: roadmap written as shipped" is not a rule name'
assert "the refusal lists the names by source file" \
  "$(reason "$out" | grep -c '^skills/expertise/doc-review/SKILL.md: Brevity | No drift | Shape$')" 1
assert "the refusal ends with the fix" "$(reason "$out" | tail -n 1)" "Call the tool again with each of these fixed."
assert "a refused rule name stores nothing" "$(stored "$agent")" ""
assert "a rule_unknown refusal is logged" "$(last_gate)" '["verdict","deny","rule_unknown"]'
out="$(call "$agent" "$REVIEWER" verdict "$(unnamed findings "Drift")")"
assert "past the bound, a wrong rule name is allowed" "$(decision "$out")" allow
assert "past the bound, it is stored as not recorded" "$(stored "$agent" | jq -c 'del(.gate.returns) | .gate')" '{"recorded":false,"code":"rule_unknown"}'
assert "a wrong rule name in a conflict is refused" \
  "$(reason "$(call "$(fresh_agent)" "$DESIGNER" verdict "$(unnamed conflicts "Owner taste")")" | sed -n 1p)" \
  '/judgments/0/conflicts/0/rule "Owner taste" is not a rule name'
assert "a wrong rule name in a follow-up is refused" \
  "$(decision "$(call "$(fresh_agent)" "$DESIGNER" verdict "$(unnamed follow_ups "No drift (principles)")")")" deny
assert "a rule name from the set is allowed in each field" \
  "$(decision "$(call "$(fresh_agent)" "$DESIGNER" verdict "$(unnamed follow_ups "No drift" | jq -c '.judgments[0].conflicts = .judgments[0].follow_ups')")")" allow
assert "a task report's follow-up names its rule freely" \
  "$(decision "$(call "$(fresh_agent)" "$WORKER" task_report "$(jq -c --argjson finding "$FINDING" '.follow_ups = [$finding | .rule = "Tool defect"]' <<<"$TASK_REPORT")")")" allow

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

send() {
  jq -cn --arg agent "$1" --arg to "$2" --arg event "${3:-PreToolUse}" '
    {hook_event_name: $event, session_id: "parent1", agent_id: $agent, agent_type: "cniska-skills:worker",
      tool_name: "SendMessage", tool_input: {to: $to, summary: "Fix", message: "Judge the fix."}}' | "$RECORD" 2>/dev/null
}
reported_reviewer() {
  local reviewer
  reviewer="$(fresh_agent)"
  call "$reviewer" "$DESIGNER" verdict "$VERDICT" >/dev/null
  handback "$reviewer" "$DESIGNER" >/dev/null
  printf '%s\n' "$reviewer"
}

export CNISKA_WAIT_HOLD_SECONDS=0
waiter="$(fresh_agent)"
rereviewer="$(reported_reviewer)"
assert "a worker's message to its reviewer passes untouched" "$(send "$waiter" "$rereviewer")" ""
waiting="$(subagent_stop "$waiter" "$WORKER")"
assert "a worker ending its turn while that reviewer re-reviews is kept running" "$(decision "$waiting")" block
assert "and told to keep waiting on it" "$(reason "$waiting" | grep -c "$rereviewer is still judging")" 1
assert "that wait logs its own gate line" "$(last_gate)" '["verdict","deny","awaiting_review"]'
assert "and spends no bound: the next end waits again" "$(reason "$(subagent_stop "$waiter" "$WORKER")" | grep -c "still judging")" 1
eager="$(fresh_agent)"
send "$eager" "$rereviewer" >/dev/null
assert "a hand-back with no report while waiting is sent back to wait" "$(reason "$(handback "$eager" "$WORKER")" | grep -c "Do not hand back while you wait")" 1
call "$rereviewer" "$DESIGNER" verdict "$VERDICT" >/dev/null
handback "$rereviewer" "$DESIGNER" >/dev/null
assert "once its reviewer hands back, the waiter is told to read the verdict" "$(reason "$(subagent_stop "$waiter" "$WORKER")" | grep -c "has handed back")" 1
assert "and its next end is judged again" "$(reason "$(subagent_stop "$waiter" "$WORKER")" | grep -c "with your report before you end")" 1
waited="$(fresh_agent)"
send "$waited" "$(reported_reviewer)" >/dev/null
assert "a waiting worker is not released by another reviewer's hand-back" "$(reason "$(subagent_stop "$waited" "$WORKER")" | grep -c "still judging")" 1
held="$(fresh_agent)"
held_reviewer="$(reported_reviewer)"
send "$held" "$held_reviewer" >/dev/null
(sleep 1 && call "$held_reviewer" "$DESIGNER" verdict "$VERDICT" >/dev/null && handback "$held_reviewer" "$DESIGNER" >/dev/null) &
assert "a worker held at its end hears of the hand-back that lands meanwhile" \
  "$(CNISKA_WAIT_HOLD_SECONDS=10 subagent_stop "$held" "$WORKER" | jq -r .reason | grep -c "has handed back")" 1
wait
quiet="$(fresh_agent)"
quiet_reviewer="$(reported_reviewer)"
send "$quiet" "$quiet_reviewer" >/dev/null
handback "$quiet_reviewer" "$DESIGNER" >/dev/null
assert "a reviewer sent back for no report keeps its waiter waiting" "$(reason "$(subagent_stop "$quiet" "$WORKER")" | grep -c "still judging")" 1
handback "$quiet_reviewer" "$DESIGNER" >/dev/null
assert "one that ends past its bound with no report releases it" "$(reason "$(subagent_stop "$quiet" "$WORKER")" | grep -c "has handed back")" 1
unreported="$(fresh_agent)"
send "$unreported" "$(fresh_agent)" >/dev/null
assert "a message to an agent with no stored report starts no wait" "$(reason "$(subagent_stop "$unreported" "$WORKER")" | grep -c "with your report before you end")" 1
coordinated="$(fresh_agent)"
send "$coordinated" main >/dev/null
assert "a message to its coordinator starts no wait" "$(reason "$(subagent_stop "$coordinated" "$WORKER")" | grep -c "with your report before you end")" 1
for event in PostToolUseFailure PermissionDenied; do
  refused_send="$(fresh_agent)"
  refused_target="$(reported_reviewer)"
  send "$refused_send" "$refused_target" >/dev/null
  assert "a send that fails at $event leaves nothing to report" "$(send "$refused_send" "$refused_target" "$event")" ""
  assert "and drops its wait, so the next end is judged" "$(reason "$(subagent_stop "$refused_send" "$WORKER")" | grep -c "with your report before you end")" 1
done
gone="$(fresh_agent)"
send "$gone" "$(reported_reviewer)" >/dev/null
call "$gone" "$WORKER" task_report "$TASK_REPORT" >/dev/null
handback "$gone" "$WORKER" >/dev/null
assert "a waiter's own hand-back drops its waits" "$(reason "$(subagent_stop "$gone" "$WORKER")" | grep -c "with your report before you end")" 1
overdue="$(fresh_agent)"
send "$overdue" "$(reported_reviewer)" >/dev/null
assert "a wait on an agent that never ends lapses at its limit, so the end is judged" \
  "$(CNISKA_WAIT_LIMIT_SECONDS=0 subagent_stop "$overdue" "$WORKER" | jq -r .reason | grep -c "with your report before you end")" 1

mkdir -p "$scratch/bin" "$scratch/runs"
printf '#!/usr/bin/env bash\n[ -e "${@: -1}.open" ]\n' >"$scratch/bin/lsof"
chmod +x "$scratch/bin/lsof"
export PATH="$scratch/bin:$PATH"
bash_done() {
  jq -cn --arg agent "$1" --arg type "$2" --arg task "$3" --arg output "$4" '
    {hook_event_name: "PostToolUse", session_id: "parent1", agent_id: $agent, tool_name: "Bash",
      tool_input: {command: "mise run test", run_in_background: true},
      tool_response: ({stdout: "", stderr: "", interrupted: false}
        + (if $task == "" then {} else {backgroundTaskId: $task, backgroundOutputPath: $output} end))}
    + (if $type == "" then {} else {agent_type: $type} end)' | "$RECORD" 2>/dev/null
}
run_stop() {
  jq -cn --arg agent "$1" --argjson tasks "$2" --arg transcript "${3:-}" '
    {hook_event_name: "SubagentStop", session_id: "parent1", agent_id: $agent, agent_type: "cniska-skills:worker", last_assistant_message: "Waiting.",
      background_tasks: [$tasks | to_entries[] | {id: .key, type: "local_bash", status: .value, command: "mise run test"}]}
    + (if $transcript == "" then {} else {agent_transcript_path: $transcript} end)' | "$RECORD" 2>/dev/null
}
run_output() {
  : >"$scratch/runs/$1.output"
  [ "${2:-}" != open ] || : >"$scratch/runs/$1.output.open"
  printf '%s/runs/%s.output\n' "$scratch" "$1"
}
runs_named() { cat "$CLAUDE_PLUGIN_DATA"/runs/*/* 2>/dev/null | grep -c "^$1	"; }
runs_kept() { find "$CLAUDE_PLUGIN_DATA/runs" -type f 2>/dev/null | wc -l | tr -d ' '; }

runner="$(fresh_agent)"
assert "a background command's start records its run and passes untouched" \
  "$(bash_done "$runner" "$WORKER" brun1 "$(run_output brun1 open)")" ""
running="$(run_stop "$runner" '{"brun1": "running"}')"
assert "a worker ending its turn while that command runs is kept running" "$(decision "$running")" block
assert "and told the command is still running" "$(reason "$running" | grep -c "Background command brun1 is still running")" 1
assert "that wait logs its own gate line" "$(last_gate)" '["verdict","deny","awaiting_run"]'
rm "$scratch/runs/brun1.output.open"
assert "once the command's output is closed, the worker is told it ended and where its output is" \
  "$(reason "$(run_stop "$runner" '{"brun1": "running"}')" | grep -c "Background command brun1 has ended; read its output in $scratch/runs/brun1.output")" 1
assert "and the next end, with that command still listed as running, is judged" \
  "$(reason "$(run_stop "$runner" '{"brun1": "running"}')" | grep -c "with your report before you end")" 1

completed="$(fresh_agent)"
bash_done "$completed" "$WORKER" brun2 "$(run_output brun2 open)" >/dev/null
assert "a command the host lists as completed is told as ended, though a child keeps its output open" \
  "$(reason "$(run_stop "$completed" '{"brun2": "completed"}')" | grep -c "Background command brun2 has ended; read its output in $scratch/runs/brun2.output")" 1
assert "and its run is dropped" "$(runs_named brun2)" 0
assert "so the next end is judged" "$(reason "$(run_stop "$completed" '{"brun2": "completed"}')" | grep -c "with your report before you end")" 1

unlisted="$(fresh_agent)"
bash_done "$unlisted" "$WORKER" brun3 "$(run_output brun3 open)" >/dev/null
assert "a stop that lists no background tasks holds nothing" \
  "$(reason "$(subagent_stop "$unlisted" "$WORKER")" | grep -c "with your report before you end")" 1

held_runner="$(fresh_agent)"
bash_done "$held_runner" "$WORKER" brun4 "$(run_output brun4 open)" >/dev/null
(sleep 1 && rm "$scratch/runs/brun4.output.open") &
assert "a worker held at its end hears of the command that ends meanwhile" \
  "$(CNISKA_WAIT_HOLD_SECONDS=10 run_stop "$held_runner" '{"brun4": "running"}' | jq -r .reason | grep -c "brun4 has ended")" 1
wait

bash_done "$(fresh_agent)" "" brun5 "$(run_output brun5 open)" >/dev/null
assert "an agent with no report tool records no run" "$(runs_named brun5)" 0
before="$(runs_kept)"
bash_done "$(fresh_agent)" "$WORKER" "" "" >/dev/null
assert "a command that ran in the foreground records no run" "$(runs_kept)" "$before"

both="$(fresh_agent)"
send "$both" "$(reported_reviewer)" >/dev/null
bash_done "$both" "$WORKER" brun6 "$(run_output brun6 open)" >/dev/null
assert "a worker waiting on a reviewer and a command is told of both" \
  "$(reason "$(run_stop "$both" '{"brun6": "running"}')" | grep -c "is still judging what you sent it. Background command brun6 is still running; stop one you no longer need with TaskStop.")" 1
assert "and the wait logs as a review's" "$(last_gate)" '["verdict","deny","awaiting_review"]'
both_reviewer="$(reported_reviewer)"
send "$both" "$both_reviewer" >/dev/null
call "$both_reviewer" "$DESIGNER" verdict "$VERDICT" >/dev/null
handback "$both_reviewer" "$DESIGNER" >/dev/null
assert "a review that ends while the command runs says to wait for the command after reading the verdict" \
  "$(reason "$(run_stop "$both" '{"brun6": "running"}')" | grep -c "has handed back.*Background command brun6 is still running: end your turn to wait for it")" 1

overdue_runner="$(fresh_agent)"
bash_done "$overdue_runner" "$WORKER" brun10 "$(run_output brun10 open)" >/dev/null
lapsed="$(CNISKA_RUN_LIMIT_SECONDS=0 CNISKA_WAIT_HOLD_SECONDS=10 run_stop "$overdue_runner" '{"brun10": "running"}' | jq -r .reason)"
assert "a command running past the run limit is told as lapsed, with its output" \
  "$(grep -c "Background command brun10 has run past the 0-minute limit and no longer holds your end; stop it with TaskStop if you no longer need it, and read its output so far in $scratch/runs/brun10.output" <<<"$lapsed")" 1
assert "and its run is dropped" "$(runs_named brun10)" 0
assert "so the next end is judged" "$(reason "$(run_stop "$overdue_runner" '{"brun10": "running"}')" | grep -c "with your report before you end")" 1

guarded="$(fresh_agent)"
bash_done "$guarded" "$WORKER" brun7 "$(run_output brun7 open)" >/dev/null
blocks="$scratch/blocks.jsonl"
blocked_stop() { jq -cn '{type: "attachment", attachment: {type: "hook_blocking_error", hookEvent: "SubagentStop"}}' >>"$blocks"; }
jq -cn '{type: "assistant", message: {content: [{type: "tool_use", name: "Bash", input: {}}]}}' >"$blocks"
for _ in 1 2 3 4 5; do blocked_stop; done
assert "a fifth blocked stop in a row asks for nothing more" \
  "$(reason "$(run_stop "$guarded" '{"brun7": "running"}' "$blocks")" | grep -c "make one tool call")" 0
blocked_stop
assert "a sixth asks for one tool call, so the host's cap does not end the turn" \
  "$(reason "$(run_stop "$guarded" '{"brun7": "running"}' "$blocks")" | grep -c "make one tool call")" 1
jq -cn '{type: "assistant", message: {content: [{type: "tool_use", name: "Read", input: {}}]}}' >>"$blocks"
assert "a tool call after them starts the count again" \
  "$(reason "$(run_stop "$guarded" '{"brun7": "running"}' "$blocks")" | grep -c "make one tool call")" 0

released="$(fresh_agent)"
bash_done "$released" "$WORKER" brun8 "$(run_output brun8 open)" >/dev/null
handback "$released" "$WORKER" >/dev/null
assert "a hand-back is not held by a running command" "$(runs_named brun8)" 1
handback "$released" "$WORKER" >/dev/null
assert "and the end it lets through drops the agent's runs" "$(runs_named brun8)" 0
unset CNISKA_WAIT_HOLD_SECONDS

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
