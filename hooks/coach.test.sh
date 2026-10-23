#!/usr/bin/env bash
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORT="$HERE/coach-report.sh"
TASK_COACH="$HERE/task-coach.sh"

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
export AGENT_LEDGER="$scratch/ledger/ledger.md" CLAUDE_PLUGIN_DATA="$scratch/data"
source "$HERE/jq-past-shims.test-harness.sh"
require_jq
mkdir -p "$scratch/ledger"

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

worker="$scratch/worker.jsonl"
tool_use() {
  jq -cn --arg name "$1" --argjson input "$2" '{type: "assistant", message: {content: [{type: "tool_use", name: $name, input: $input}]}}'
}
done_line() { jq -cn '{type: "assistant", message: {content: [{type: "text", text: "Done."}]}}'; }
stop_worker() {
  fresh_bound "${2:-}"
  jq -cn --arg transcript "$worker" --arg type "${1:-general-purpose}" \
    '{hook_event_name: "SubagentStop", session_id: "s1", agent_id: "a1", agent_type: $type, agent_transcript_path: $transcript, last_assistant_message: "Done."}' | "$TASK_COACH" 2>/dev/null
}
reason() { stop_worker "$@" | jq -r '.reason // empty'; }
decision() { stop_worker | jq -r '.decision // empty'; }

readonly ASK="Before you hand back, state your report in a message, so your transcript keeps it if the run is cut short, then run cniska-skills:coach in the foreground over this task alone: your own run, agent a1 of session s1, with its transcript at $worker, and the subagents you started. Hand back its report with yours, so your caller applies its proposals except conflicts, which go to the owner, opening an experiment for each change where cniska-skills:coordinate calls for one."

{ tool_use Skill '{"skill": "cniska-skills:task"}' && done_line; } >"$worker"
assert "a worker that ran a task is asked to run the coach over it before handing back" "$(reason)" "$ASK"
assert "the ask keeps the worker running" "$(decision)" block
assert "the ask is made once" "$(reason general-purpose again)" ""

{ tool_use Skill '{"skill": "task"}' && done_line; } >"$worker"
assert "a task skill installed without the plugin prefix counts" "$(decision)" block

done_line >"$worker"
assert "a worker agent, which preloads task, is asked with no Skill use" "$(reason cniska-skills:worker)" "$ASK"

tool_use Skill '{"skill": "cniska-skills:review"}' >"$worker"
assert "a subagent that never loaded task is not asked" "$(reason)" ""

: >"$worker"
assert "an empty transcript is not asked" "$(reason)" ""
assert "a missing transcript is not asked" "$(printf '{"agent_type":"general-purpose","agent_transcript_path":"%s/none.jsonl"}' "$scratch" | "$TASK_COACH" 2>/dev/null)" ""

{
  tool_use Skill '{"skill": "cniska-skills:task"}'
  tool_use Agent '{"subagent_type": "cniska-skills:coach", "prompt": "x"}'
  done_line
} >"$worker"
assert "a worker that already ran the coach is not asked again" "$(reason)" ""

experiments="$scratch/ledger/experiments.jsonl"
{ tool_use Skill '{"skill": "cniska-skills:task"}' && done_line; } >"$worker"
{
  jq -cn '{v: 1, event: "open", sha: "a1", signal: "owner interrupts", check: "2020-01-01"}'
  jq -cn '{v: 1, event: "open", sha: "b2", signal: "time to land", check: "2020-01-01"}'
  jq -cn '{v: 1, event: "open", sha: "b2", signal: "time to land", check: "2999-01-01"}'
  jq -cn '{v: 1, event: "open", sha: "c3", signal: "review loops", check: "2020-01-01"}'
  jq -cn '{v: 1, event: "close", sha: "c3", outcome: "keep"}'
  jq -cn '{v: 1, event: "open", sha: "d4", signal: "stranded work", check: "2020-02-01T00:00:00Z"}'
} >"$experiments"
assert "the ask names the open experiments past their check date and the record" "$(reason)" \
  "${ASK/ you started./ you started. Brief it with the experiments past their check date, a1 (owner interrupts), d4 (stranded work), in the record at $experiments.}"

mkdir -p "$scratch/split/ledgers"
printf '[Shared](../LEDGER.md)\n' >"$scratch/split/ledgers/loop.md"
jq -cn '{v: 1, event: "open", sha: "e5", signal: "split", check: "2020-01-01"}' >"$scratch/split/experiments.jsonl"
assert "the record sits beside the shared file the ledger links" "$(AGENT_LEDGER="$scratch/split/ledgers/loop.md" reason)" \
  "${ASK/ you started./ you started. Brief it with the experiments past their check date, e5 (split), in the record at $scratch/split/ledgers/../experiments.jsonl.}"

jq -cn '{v: 1, event: "open", sha: "b2", check: "2999-01-01"}' >"$experiments"
assert "no experiment past its check date leaves the ask as it is" "$(reason)" "$ASK"

printf 'not json\n' >"$experiments"
assert "an unreadable experiment record leaves the ask as it is" "$(reason)" "$ASK"
assert "an unreadable experiment record warns on stderr" \
  "$(jq -cn --arg t "$worker" '{agent_type: "general-purpose", agent_transcript_path: $t}' | "$TASK_COACH" 2>&1 >/dev/null | grep -c '^task-coach.sh: .*not named')" 1
rm -f "$experiments"

session_transcript="$scratch/s2.jsonl"
handback_transcript="$scratch/s2/subagents/agent-a2.jsonl"
mkdir -p "$(dirname "$handback_transcript")"
tool_use Skill '{"skill": "cniska-skills:task"}' >"$handback_transcript"
hand_back() {
  fresh_bound "${1:-}"
  jq -cn --arg transcript "$session_transcript" \
    '{hook_event_name: "PreToolUse", tool_name: "SubagentHandback", tool_input: {message: "Done."}, session_id: "s2", agent_id: "a2", agent_type: "general-purpose", transcript_path: $transcript}' | "$TASK_COACH" 2>/dev/null
}
HANDBACK_ASK="Before you hand back, state your report in a message, so your transcript keeps it if the run is cut short, then run cniska-skills:coach in the foreground over this task alone: your own run, agent a2 of session s2, with its transcript at $handback_transcript, and the subagents you started. Hand back its report with yours, so your caller applies its proposals except conflicts, which go to the owner, opening an experiment for each change where cniska-skills:coordinate calls for one."
assert "a worker's hand-back is refused with the ask, naming the transcript found from the session's" \
  "$(hand_back)" "$(jq -cn --arg reason "$HANDBACK_ASK" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}}')"
assert "the worker's second hand-back goes through" "$(hand_back again)" ""
done_line >>"$handback_transcript"
assert "the stop after that hand-back is let through by the same bound" \
  "$(jq -cn --arg transcript "$handback_transcript" '{hook_event_name: "SubagentStop", agent_id: "a2", agent_transcript_path: $transcript, last_assistant_message: "Done."}' | "$TASK_COACH" 2>/dev/null)" ""
waiter="$scratch/waiter.jsonl"
{ tool_use Skill '{"skill": "cniska-skills:task"}' && done_line; } >"$waiter"
waiter_event() {
  jq -cn --arg event "$1" --arg transcript "$waiter" \
    '{hook_event_name: $event, tool_name: "SubagentHandback", tool_input: {message: "Done."}, session_id: "s3", agent_id: "a3", agent_type: "general-purpose", agent_transcript_path: $transcript, last_assistant_message: "Waiting."}' | "$TASK_COACH" 2>/dev/null
}
WAITER_ASK="Before you hand back, state your report in a message, so your transcript keeps it if the run is cut short, then run cniska-skills:coach in the foreground over this task alone: your own run, agent a3 of session s3, with its transcript at $waiter, and the subagents you started. Hand back its report with yours, so your caller applies its proposals except conflicts, which go to the owner, opening an experiment for each change where cniska-skills:coordinate calls for one."
fresh_bound
assert "a stop before any coach run reminds the worker once" "$(waiter_event SubagentStop)" "$(jq -cn --arg reason "$WAITER_ASK" '{decision: "block", reason: $reason}')"
assert "a second stop is let through by the reminder's bound" "$(waiter_event SubagentStop)" ""
assert "the hand-back after those stops is still refused with the ask" \
  "$(waiter_event PreToolUse)" "$(jq -cn --arg reason "$WAITER_ASK" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}}')"
assert "the hand-back after its refusal goes through" "$(waiter_event PreToolUse)" ""

launch() {
  jq -cn --arg id "$1" --arg name "$2" --argjson input "$3" '{type: "assistant", message: {content: [{type: "tool_use", id: $id, name: $name, input: $input}]}}'
}
notification() {
  jq -cn --arg id "$1" '{type: "attachment", attachment: {type: "queued_command", commandMode: "task-notification", prompt: "<task-notification>\n<task-id>b1</task-id>\n<tool-use-id>\($id)</tool-use-id>\n<status>completed</status>\n<summary>Background command \"wait\" completed (exit code 0)</summary>\n</task-notification>"}}'
}
monitor_event() {
  jq -cn '{type: "user", message: {role: "user", content: "<task-notification>\n<task-id>m1</task-id>\n<summary>Monitor event: \"ci\"</summary>\n<event>run: in_progress</event>\n</task-notification>"}}'
}
denials_of_waiter() { cat "$CLAUDE_PLUGIN_DATA/denials/"* 2>/dev/null; }
WAITER_REMINDER="$(jq -cn --arg reason "$WAITER_ASK" '{decision: "block", reason: $reason}')"

for pending in \
  "Agent {\"subagent_type\":\"cniska-skills:reviewer\",\"prompt\":\"x\"}" \
  "Agent {\"subagent_type\":\"cniska-skills:reviewer\",\"prompt\":\"x\",\"run_in_background\":true}" \
  "Bash {\"command\":\"sleep 1\",\"run_in_background\":true}" \
  "Monitor {\"command\":\"true\",\"description\":\"ci\",\"timeout_ms\":1000}"; do
  { tool_use Skill '{"skill": "cniska-skills:task"}' && launch toolu_bg "${pending%% *}" "${pending#* }" && done_line; } >"$waiter"
  fresh_bound
  assert "a stop that waits on a background ${pending%% *} launch gets no reminder" "$(waiter_event SubagentStop)" ""
  assert "a stop that waits on a background ${pending%% *} launch records no denial" "$(denials_of_waiter)" ""
done

{ tool_use Skill '{"skill": "cniska-skills:task"}' && launch toolu_mon Monitor '{"command":"true","description":"ci","timeout_ms":1000}' && monitor_event && done_line; } >"$waiter"
fresh_bound
assert "a Monitor event short of its end leaves the launch pending" "$(waiter_event SubagentStop)" ""

{ tool_use Skill '{"skill": "cniska-skills:task"}' && launch toolu_fg Agent '{"subagent_type":"cniska-skills:reviewer","prompt":"x","run_in_background":false}' && launch toolu_sh Bash '{"command":"true"}' && done_line; } >"$waiter"
fresh_bound
assert "a stop after foreground launches only gets the reminder" "$(waiter_event SubagentStop)" "$WAITER_REMINDER"

{
  tool_use Skill '{"skill": "cniska-skills:task"}'
  launch toolu_bg Bash '{"command":"sleep 1","run_in_background":true}'
  done_line
} >"$waiter"
fresh_bound
waiter_event SubagentStop >/dev/null
{ notification toolu_bg && done_line; } >>"$waiter"
assert "the stop after every launch's notification gets the reminder" "$(waiter_event SubagentStop again)" "$WAITER_REMINDER"
assert "the reminder after the wait is made once" "$(waiter_event SubagentStop again)" ""

launch_result() {
  jq -cn --arg id "$1" --arg text "$2" '{type: "user", message: {role: "user", content: [{type: "tool_result", tool_use_id: $id, content: $text}]}}'
}
{
  tool_use Skill '{"skill": "cniska-skills:task"}'
  launch toolu_bg Bash '{"command":"sleep 1","run_in_background":true}'
  launch_result toolu_bg "Command running in background with ID: b2946a28k. Output is being written to: /tmp/tasks/b2946a28k.output."
  launch toolu_other Bash '{"command":"sleep 1","run_in_background":true}'
  launch_result toolu_other "Command running in background with ID: b2946a28kx. Output is being written to: /tmp/tasks/b2946a28kx.output."
  launch toolu_stop TaskStop '{"task_id":"b2946a28k"}'
  done_line
} >"$waiter"
fresh_bound
assert "a stop that waits on one launch while another was stopped gets no reminder" "$(waiter_event SubagentStop)" ""
{ notification toolu_other && done_line; } >>"$waiter"
assert "a launch stopped by TaskStop, which sends no notification, no longer holds the reminder" "$(waiter_event SubagentStop again)" "$WAITER_REMINDER"

{ tool_use Skill '{"skill": "cniska-skills:task"}' && tool_use SubagentHandback '{"message": "Done."}'; } >"$worker"
assert "a stop whose run ended in a hand-back is left to the hand-back hook" "$(reason)" ""

hooks="$HERE/hooks.json"
assert "every subagent's stop is checked by the coach report and the task coach" \
  "$(jq -r '.hooks.SubagentStop[] | select(has("matcher") | not) | .hooks[].command' "$hooks" | grep -cE '/hooks/(coach-report|task-coach)\.sh$')" 2
assert "every hand-back is checked by the coach report and the task coach" \
  "$(jq -r '.hooks.PreToolUse[] | select(.matcher == "SubagentHandback") | .hooks[].command' "$hooks" | grep -cE '/hooks/(coach-report|task-coach)\.sh$')" 2
assert "no session start runs a coach schedule" "$(jq -r '.hooks.SessionStart[].hooks[].command' "$hooks" | grep -c coach)" 0

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
