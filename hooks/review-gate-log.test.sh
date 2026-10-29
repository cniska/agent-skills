#!/usr/bin/env bash
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/review-gate.test-harness.sh"

other="$scratch/other"
mkdir -p "$other"
(cd "$other" && git init -q -b main && printf 'z = 1\n' >lib.py && git add -A && git commit -q -m base && printf 'z = 2\n' >>lib.py)

printf 'not json' | "$GATE" >/dev/null 2>&1
assert "a gate that fails refuses the commit rather than allowing it" "$?" 2

verdict_call() { jq -cn --arg tool "$VERDICT_TOOL" --argjson judgment "$1" '{hook_event_name: "PreToolUse", agent_type: "cniska-skills:reviewer", tool_name: $tool, tool_input: {diffs: [], judgments: [$judgment]}}' | jq -c "${2:-.}"; }
assert "recording a verdict without plugin data fails" \
  "$(verdict_call "$(report "$repo" accept)" '.agent_id = "n1"' | env -u CLAUDE_PLUGIN_DATA "$RECORD" >/dev/null 2>&1; echo "$?")" 1
assert "recording a verdict without plugin data names the script and the variable" \
  "$(verdict_call "$(report "$repo" accept)" '.agent_id = "n1"' | { env -u CLAUDE_PLUGIN_DATA "$RECORD" >/dev/null; } 2>&1)" "report-record.sh: CLAUDE_PLUGIN_DATA is required to keep reports"

edit app.py 'print(12)'
assert "recording a verdict without an agent or session id fails" \
  "$(verdict_call "$(report "$repo" accept)" | "$RECORD" 2>&1 >/dev/null; echo "$?")" \
  "report-record.sh: the hook input has no agent_id or session_id a report can be kept under
1"
assert "a verdict without an agent or session id approves nothing" "$(gate 'git commit -am x')" "$(denied 'app.py (working tree)')"

assert "a stop of an agent other than the report agents is not judged" \
  "$(jq -cn --arg cwd "$repo" '{hook_event_name: "SubagentStop", agent_type: "general-purpose", agent_id: "w1", cwd: $cwd, last_assistant_message: "No verdict."}' | "$RECORD" 2>/dev/null)" ""
recorder_on() { jq -r --arg event "$1" --arg matcher "${2:-}" '.hooks[$event][] | select((.matcher // "") == $matcher) | .hooks[].command' "$HERE/hooks.json" | grep -c 'report-record.sh$'; }
assert "the report recorder judges every subagent's stop" "$(recorder_on SubagentStop)" 1
assert "the report recorder judges every session's stop" "$(recorder_on Stop)" 1
assert "the report recorder judges every hand-back and report tool" \
  "$(recorder_on PreToolUse 'SubagentHandback|mcp__plugin_cniska-skills_report__(verdict|research|task_report)')" 1
assert "no hook runs the review recorder as an entry" "$(grep -c 'review-record.sh' "$HERE/hooks.json")" 0

logged="$scratch/logged"
mkdir -p "$logged"
(cd "$logged" && git init -q -b main && printf 'n = 1\n' >n.py && printf '# n\n' >NOTES.md && git add -A && git commit -q -m base)
logged_head="$(git -C "$logged" rev-parse HEAD)"
logged_repo="$(git -C "$logged" rev-parse --show-toplevel)"

gate_logged() {
  jq -cn --arg command "$1" --arg cwd "${2:-$logged}" \
    '{session_id: "s1", agent_id: "a1", hook_event_name: "PreToolUse", tool_name: "Bash", tool_input: {command: $command}, cwd: $cwd}' | "$GATE" 2>/dev/null
}

record_logged_as() {
  local transcript
  transcript="$(briefed "$(diff_of "$2")")"
  jq -cn --arg cwd "$logged" --arg agent "$1" --arg tool "$VERDICT_TOOL" --arg transcript "$(scratch_file "$transcript")" \
    --arg listed "$(reads_in "$transcript")" --argjson judgments "$(jq -sc . <<<"$2")" '
    {session_id: "s1", agent_id: $agent, hook_event_name: "PreToolUse", tool_name: $tool, tool_input: {diffs: ($listed | split("\n") | map(select(. != ""))), judgments: $judgments},
      agent_type: "cniska-skills:reviewer", cwd: $cwd, agent_transcript_path: $transcript}' | "$RECORD" 2>/dev/null
}
record_logged() { record_logged_as "$(fresh_agent)" "$1"; }

lines() { if [ -f "$log" ]; then wc -l <"$log" | tr -d ' '; else echo 0; fi; }
new_lines() { tail -n +"$(($1 + 1))" "$log" 2>/dev/null; }

decided() {
  local before
  before="$(lines)"
  "$@" >/dev/null
  new_lines "$before" | jq -c 'del(.ts, .v, .session, .agent, .cwd, .event)'
}

sha() { shasum -a 256 | cut -d ' ' -f 1; }

before="$(lines)"
gate_logged 'git status' >/dev/null
assert "a command that is not a commit logs nothing" "$(new_lines "$before")" ""

(cd "$logged" && printf 'n = 2\n' >n.py)
blob="$(git -C "$logged" hash-object n.py)"
fp="$(printf 'working\t100644 %s\tn.py\n' "$blob" | sha)"
accepted_fp="$(printf '%s\t100644 %s\tn.py\n' "$logged_head" "$blob" | sha)"
before="$(lines)"
gate_logged 'git commit -am x' >/dev/null
assert "a gate decision logs one line with the common fields" \
  "$(new_lines "$before" | jq -c --arg cwd "$logged" '[.v, .event, .session, .agent, .cwd == $cwd, (.ts | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$"))]')" \
  '[1,"gate","s1","a1",true,true]'
assert "an unreviewed commit logs a deny with the diff it judged" \
  "$(new_lines "$before" | jq -c 'del(.ts, .v, .session, .agent, .cwd, .event)')" \
  "$(jq -cn --arg repo "$logged_repo" --arg head "$logged_head" --arg fp "$fp" '{gate: "commit", decision: "deny", reason: "not_accepted", repo: $repo, head: $head, fingerprint: $fp}')"

assert "an accepting verdict logs the verdict and the accept set it recorded" \
  "$(decided record_logged "$(report "$logged" accept)")" \
  "$(jq -cn --arg repo "$logged_repo" --arg fp "$accepted_fp" '{verdict: "accept", repo: $repo, fingerprint: $fp, reason: null, findings: {critical: 0, major: 0, minor: 0, fix: 0, consider: 0, unrated: 0}, conflicts: 0, follow_ups: 0, rules: []}')"
assert "the verdict line names the reviewer's agent id" "$(tail -n 1 "$log" | jq -r .agent)" "reviewer-$(cat "$scratch/agents")"
assert "the accepted commit logs an allow with the fingerprint of the sides it judged" \
  "$(decided gate_logged 'git commit -am x')" \
  "$(jq -cn --arg repo "$logged_repo" --arg head "$logged_head" --arg fp "$fp" '{gate: "commit", decision: "allow", reason: "accepted", repo: $repo, head: $head, fingerprint: $fp}')"
(cd "$logged" && printf 'n = 3\n' >n.py)
assert "an edit after the accept logs changed_since_accept" "$(decided gate_logged 'git commit -am x' | jq -r .reason)" changed_since_accept
assert "a returning verdict logs the return with the fingerprint of the cleared accept set" \
  "$(decided record_logged "$(report "$logged" return)" | jq -r --arg repo "$logged_repo" '[.verdict, .repo == $repo, .fingerprint] | @tsv')" "return	true	$(printf '' | sha)"
counts() { decided record_logged "$(report "$logged" return "$1")" | jq -c '[.findings, .conflicts, .follow_ups, .rules]'; }
at() { finding "$logged/n.py" "$1" "$2"; }
assert "a return counts its findings by severity, its conflicts, its follow-ups and each finding's rule" \
  "$(counts ".findings = [$(at 'No dead structure' critical), $(at 'Named constants' major), $(at 'No dead structure' minor)] | .conflicts = [$(at 'A settled decision' major), $(at Another minor)] | .follow_ups = [$(at Names minor)]")" \
  '[{"critical":1,"major":1,"minor":1,"fix":0,"consider":0,"unrated":0},2,1,["No dead structure","Named constants","No dead structure"]]'
assert "more than 1000 findings of a kind leave the verdict uncounted" "$(counts ".findings = [range(1001) | $(at Names minor)]")" '[null,null,null,null]'
assert "an uncounted return is still logged" "$(tail -n 1 "$log" | jq -r .verdict)" return
assert "a verdict judging two repositories counts each judgment's own findings" \
  "$(decided record_logged "$(report "$logged" return ".findings = [$(at Names minor)]")"$'\n'"$(report "$other" return)" | jq -sc 'map([.findings.minor, .conflicts, .follow_ups, .rules])')" \
  '[[1,0,0,["Names"]],[0,0,0,[]]]'
assert "a commit after a return logs not_accepted" "$(decided gate_logged 'git commit -am x' | jq -r .reason)" not_accepted

(cd "$logged" && git checkout -q n.py && printf 'more\n' >>NOTES.md)
assert "a Markdown-only commit logs an allow" "$(decided gate_logged 'git commit -am x' | jq -c '[.decision, .reason, .fingerprint]')" '["allow","no_code_change",null]'
assert "a commit outside any repository logs an allow" "$(decided gate_logged 'git commit -am x' "$scratch" | jq -c '[.decision, .reason, .repo]')" '["allow","outside_repo",null]'
assert "two commits in one command log multiple_commits" "$(decided gate_logged 'git commit -m x && git commit -m y' | jq -r .reason)" multiple_commits
assert "a commit that creates its repo logs repo_created" "$(decided gate_logged 'git init -q && git commit -m x' / | jq -r .reason)" repo_created
assert "a commit to a scratch repo logs an allow" "$(decided gate_logged 'git init -q && git commit -m x' | jq -c '[.decision, .reason, .repo]')" '["allow","scratch_repo",null]'
assert "a commit reaching its repo unclearly logs repo_unclear" "$(decided gate_logged '(cd ~/project && git commit -am x)' | jq -r .reason)" repo_unclear
assert "a commit naming no repository logs repo_not_found" "$(decided gate_logged 'cd ~/nowhere && git commit -am x' | jq -r .reason)" repo_not_found
assert "a gate that fails logs gate_error" "$(decided sh -c "printf 'not json' | '$GATE' 2>/dev/null" | jq -r '[.decision, .reason] | @tsv')" "deny	gate_error"

twice="$(fresh_agent)"
no_repo="$(report "$logged" accept 'del(.repo)')"
assert "a verdict off the schema logs payload_invalid" "$(decided record_logged_as "$twice" "$no_repo" | jq -r '[.gate, .decision, .reason] | @tsv')" "verdict	deny	payload_invalid"
assert "its second call logs an allow" "$(decided record_logged_as "$twice" "$no_repo" | jq -r '[.decision, .reason] | @tsv')" "allow	payload_invalid"
assert "a call after the stored report logs already_reported" "$(decided record_logged_as "$twice" "$(report "$logged" accept)" | jq -r '[.decision, .reason] | @tsv')" "deny	already_reported"
assert "a relative repo logs payload_invalid" "$(decided record_logged "$(report logged accept)" | jq -r .reason)" payload_invalid
assert "an accept with a finding logs accept_with_findings" "$(decided record_logged "$(report "$logged" accept ".findings = [$(at Names minor)]")" | jq -r .reason)" accept_with_findings
assert "an accept with only a follow-up logs the accept and counts the follow-up" \
  "$(decided record_logged "$(report "$logged" accept ".follow_ups = [$(at Names minor)]")" | jq -r '[.verdict, .follow_ups] | @tsv')" "accept	1"
assert "a return for a brief with no diff logs reason no_diff" "$(decided record_logged "$(report "$logged" return '.reason = "no_diff"')" | jq -r '[.verdict, .reason] | @tsv')" "return	no_diff"
assert "a no_diff return beside an accept for another repo logs the reason on its own judgment only" \
  "$(decided record_logged "$(report "$logged" return '.reason = "no_diff"')"$'\n'"$(report "$other" accept)" | jq -sc 'map(.reason)')" '["no_diff",null]'
assert "a verdict with no reason logs a null reason" "$(decided record_logged "$(report "$logged" return)" | jq -c .reason)" null
assert "two judgments of one repository log repo_repeated" "$(decided record_logged "$(report "$logged" return)"$'\n'"$(report "$logged" accept)" | jq -r .reason)" repo_repeated
returner="$(fresh_agent)"
listed="$(scratch_file "$(diff_in "$logged" n.py)")"
jq -cn --arg agent "$returner" --arg tool "$VERDICT_TOOL" --arg listed "$listed" --argjson judgment "$(report "$logged" return)" \
  '{session_id: "s1", agent_id: $agent, hook_event_name: "PreToolUse", tool_name: $tool, tool_input: {diffs: [$listed], judgments: [$judgment]}, agent_type: "cniska-skills:reviewer"}' | "$RECORD" >/dev/null 2>&1
assert "an accept from the reviewer that returned logs a same_reviewer note and no verdict" \
  "$(decided record_logged_as "$returner" "$(report "$logged" accept)" | jq -sc 'map([.gate, .decision, .reason])')" '[["verdict","allow","same_reviewer"]]'
assert "a repo that is not a repository logs repo_not_found" "$(decided record_logged "$(report "$scratch/nowhere" accept)" | jq -r .reason)" repo_not_found

(cd "$logged" && git checkout -q NOTES.md && printf 'n = 4\n' >n.py)
mv "$log" "$log.kept"
mkdir "$log"
assert "an unwritable log leaves a deny unchanged" "$(gate_logged 'git commit -am x')" "$(denied 'n.py (working tree)')"
assert "an unwritable log leaves the deny's exit code at 0" "$(gate_logged 'git commit -am x' >/dev/null; echo "$?")" 0
assert "an unwritable log warns on stderr" \
  "$(jq -cn --arg cwd "$logged" '{tool_input: {command: "git commit -am x"}, cwd: $cwd}' | { "$GATE" >/dev/null; } 2>&1 | grep -c '^commit-gate.sh: the event log was not written')" 1
assert "an unwritable log still records an accept" "$(record_logged "$(report "$logged" accept)")" "$(allowed)"
assert "an unwritable log leaves an allow unchanged" "$(gate_logged 'git commit -am x')" ""
rmdir "$log"
mv "$log.kept" "$log"

finish
