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

scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
export AGENT_LEDGER="$scratch/ledger/ledger.md"
mkdir -p "$scratch/ledger"

readonly MISSING='{"decision":"block","reason":"End your report with a last line that is exactly '"'"'Proposals: <n>'"'"', counting the proposals other than one-offs."}'

report_handback() {
  local transcript="$scratch/coach-transcript.jsonl"
  jq -cn --arg message "$1" '{type: "assistant", message: {content: [{type: "tool_use", name: "SubagentHandback", input: {message: $message}}]}}' >"$transcript"
  jq -cn --arg transcript "$transcript" --arg active "${2:-false}" \
    '{hook_event_name: "SubagentStop", agent_type: "cniska-skills:coach", agent_transcript_path: $transcript, last_assistant_message: "", stop_hook_active: ($active == "true")}' | "$REPORT" 2>/dev/null
}

report_last_message() {
  jq -cn --arg message "$1" --arg active "${2:-false}" \
    '{hook_event_name: "SubagentStop", agent_type: "cniska-skills:coach", last_assistant_message: $message, stop_hook_active: ($active == "true")}' | "$REPORT" 2>/dev/null
}

assert "a report with no Proposals line keeps the coach running" "$(report_last_message 'Nothing much.')" "$MISSING"
assert "a Proposals count that is not a number keeps the coach running" "$(report_last_message $'Done.\nProposals: some')" "$MISSING"
assert "a Proposals line not on its own line does not count" "$(report_last_message 'My Proposals: 2')" "$MISSING"
assert "a missing Proposals line on the second stop lets the coach stop" "$(report_last_message 'Still none.' true)" ""
assert "a good report in the last message says nothing" "$(report_last_message $'Two things.\nProposals: 2')" ""
assert "a good report in a handback says nothing" "$(report_handback $'Nothing clears the bar.\nProposals: 0')" ""
assert "a handback with no Proposals line keeps the coach running" "$(report_handback 'Forgot the count.')" "$MISSING"

worker="$scratch/worker.jsonl"
tool_use() {
  jq -cn --arg name "$1" --argjson input "$2" '{type: "assistant", message: {content: [{type: "tool_use", name: $name, input: $input}]}}'
}
stop_worker() {
  jq -cn --arg transcript "$worker" --arg type "${1:-general-purpose}" --arg active "${2:-false}" \
    '{hook_event_name: "SubagentStop", session_id: "s1", agent_id: "a1", agent_type: $type, agent_transcript_path: $transcript, last_assistant_message: "Done.", stop_hook_active: ($active == "true")}' | "$TASK_COACH" 2>/dev/null
}
reason() { stop_worker "$@" | jq -r '.reason // empty'; }
decision() { stop_worker | jq -r '.decision // empty'; }

readonly ASK="Before you hand back, run cniska-skills:coach in the foreground over this task alone: your own run, agent a1 of session s1, with its transcript at $worker, and the subagents you started. Hand back its report with yours, so your caller applies its proposals except conflicts, which go to the owner, opening an experiment for each change where cniska-skills:coordinate calls for one."

tool_use Skill '{"skill": "cniska-skills:task"}' >"$worker"
assert "a worker that ran a task is asked to run the coach over it before handing back" "$(reason)" "$ASK"
assert "the ask keeps the worker running" "$(decision)" block
assert "the ask is made once" "$(reason general-purpose true)" ""

tool_use Skill '{"skill": "task"}' >"$worker"
assert "a task skill installed without the plugin prefix counts" "$(decision)" block

tool_use Skill '{"skill": "cniska-skills:review"}' >"$worker"
assert "a subagent that never loaded task is not asked" "$(reason)" ""

: >"$worker"
assert "an empty transcript is not asked" "$(reason)" ""
assert "a missing transcript is not asked" "$(printf '{"agent_type":"general-purpose","agent_transcript_path":"%s/none.jsonl"}' "$scratch" | "$TASK_COACH" 2>/dev/null)" ""

{
  tool_use Skill '{"skill": "cniska-skills:task"}'
  tool_use Agent '{"subagent_type": "cniska-skills:coach", "prompt": "x"}'
} >"$worker"
assert "a worker that already ran the coach is not asked again" "$(reason)" ""

experiments="$scratch/ledger/experiments.jsonl"
tool_use Skill '{"skill": "cniska-skills:task"}' >"$worker"
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

jq -cn '{v: 1, event: "open", sha: "b2", check: "2999-01-01"}' >"$experiments"
assert "no experiment past its check date leaves the ask as it is" "$(reason)" "$ASK"

printf 'not json\n' >"$experiments"
assert "an unreadable experiment record leaves the ask as it is" "$(reason)" "$ASK"
assert "an unreadable experiment record warns on stderr" \
  "$(jq -cn --arg t "$worker" '{agent_type: "general-purpose", agent_transcript_path: $t}' | "$TASK_COACH" 2>&1 >/dev/null | grep -c '^task-coach.sh: .*not named')" 1
rm -f "$experiments"

hooks="$HERE/hooks.json"
assert "the report check listens to the coach agent" \
  "$(jq -r '.hooks.SubagentStop[] | select(.matcher == "^cniska-skills:coach$") | .hooks[].command' "$hooks")" "\"\${CLAUDE_PLUGIN_ROOT}\"/hooks/coach-report.sh"
assert "every subagent's stop is checked for an ended task" \
  "$(jq -r '.hooks.SubagentStop[] | select(has("matcher") | not) | .hooks[].command' "$hooks")" "\"\${CLAUDE_PLUGIN_ROOT}\"/hooks/task-coach.sh"
assert "no session start runs a coach schedule" "$(jq -r '.hooks.SessionStart[].hooks[].command' "$hooks" | grep -c coach)" 0

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
