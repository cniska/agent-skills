#!/usr/bin/env bash
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/review-gate.test-harness.sh"

other="$scratch/other"
mkdir -p "$other"
(cd "$other" && git init -q -b main && printf 'z = 1\n' >lib.py && git add -A && git commit -q -m base && printf 'z = 2\n' >>lib.py)

printf 'not json' | "$GATE" >/dev/null 2>&1
assert "a gate that fails refuses the commit rather than allowing it" "$?" 2

assert "recording a verdict without plugin data fails" \
  "$(printf '{"agent_type":"cniska-skills:reviewer","last_assistant_message":""}' | env -u CLAUDE_PLUGIN_DATA "$RECORD" >/dev/null 2>&1; echo "$?")" 1
assert "recording a verdict without plugin data names the script and the variable" \
  "$(printf '{"agent_type":"cniska-skills:reviewer","last_assistant_message":""}' | { env -u CLAUDE_PLUGIN_DATA "$RECORD" >/dev/null; } 2>&1)" "review-record.sh: CLAUDE_PLUGIN_DATA is required"

edit app.py 'print(12)'
assert "recording a verdict without an agent id fails" \
  "$(jq -cn --arg cwd "$repo" --arg message "$(report "$repo" accept)" '{agent_type: "cniska-skills:reviewer", cwd: $cwd, last_assistant_message: $message}' | "$RECORD" 2>&1 >/dev/null; echo "$?")" \
  "review-record.sh: agent_id is required to tell reviewers apart
1"
assert "a verdict without an agent id approves nothing" "$(gate 'git commit -am x')" "$(denied 'app.py (working tree)')"

assert "a stop of an agent other than the reviewer is not judged" \
  "$(jq -cn --arg cwd "$repo" '{hook_event_name: "SubagentStop", agent_type: "general-purpose", agent_id: "w1", cwd: $cwd, last_assistant_message: "No verdict."}' | "$RECORD" 2>/dev/null)" ""
assert "the verdict recorder judges every subagent's stop" \
  "$(jq -r '.hooks.SubagentStop[] | select(has("matcher") | not) | .hooks[].command' "$HERE/hooks.json" | grep -c 'review-record.sh$')" 1
assert "the verdict recorder judges every hand-back" \
  "$(jq -r '.hooks.PreToolUse[] | select(.matcher == "SubagentHandback") | .hooks[].command' "$HERE/hooks.json" | grep -c 'review-record.sh$')" 1

logged="$scratch/logged"
mkdir -p "$logged"
(cd "$logged" && git init -q -b main && printf 'n = 1\n' >n.py && printf '# n\n' >NOTES.md && git add -A && git commit -q -m base)
logged_head="$(git -C "$logged" rev-parse HEAD)"
logged_repo="$(git -C "$logged" rev-parse --show-toplevel)"

gate_logged() {
  jq -cn --arg command "$1" --arg cwd "${2:-$logged}" \
    '{session_id: "s1", agent_id: "a1", hook_event_name: "PreToolUse", tool_name: "Bash", tool_input: {command: $command}, cwd: $cwd}' | "$GATE" 2>/dev/null
}

record_logged() {
  jq -cn --arg cwd "$logged" --arg message "$1" --arg agent "$reviewer" --arg transcript "$(transcript_of "$(briefed "$(diff_of "$1")")")" \
    '{session_id: "s1", agent_id: $agent, hook_event_name: "PreToolUse", tool_name: "SubagentHandback", tool_input: {message: $message}, agent_type: "cniska-skills:reviewer", cwd: $cwd, agent_transcript_path: $transcript}' | "$RECORD" 2>/dev/null
}
reviewer=r1

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
  "$(jq -cn --arg repo "$logged_repo" --arg fp "$accepted_fp" '{verdict: "accept", repo: $repo, fingerprint: $fp, reason: null, findings: {critical: 0, major: 0, minor: 0, fix: 0, consider: 0, unrated: 0}, conflicts: 0, rules: []}')"
assert "the verdict line names the reviewer's agent id" "$(tail -n 1 "$log" | jq -r .agent)" r1
assert "the accepted commit logs an allow with the fingerprint of the sides it judged" \
  "$(decided gate_logged 'git commit -am x')" \
  "$(jq -cn --arg repo "$logged_repo" --arg head "$logged_head" --arg fp "$fp" '{gate: "commit", decision: "allow", reason: "accepted", repo: $repo, head: $head, fingerprint: $fp}')"
(cd "$logged" && printf 'n = 3\n' >n.py)
reviewer=r2
assert "an edit after the accept logs changed_since_accept" "$(decided gate_logged 'git commit -am x' | jq -r .reason)" changed_since_accept
assert "a returning verdict logs the return with the fingerprint of the cleared accept set" \
  "$(decided record_logged "$(report "$logged" return)" | jq -r --arg repo "$logged_repo" '[.verdict, .repo == $repo, .fingerprint] | @tsv')" "return	true	$(printf '' | sha)"
counts() { decided record_logged "$(sections "$1" "$2")"$'\nRepo: '"$logged"$'\nVerdict: return' | jq -c '[.findings, .conflicts, .rules]'; }
readonly EVERY_SEVERITY='- **Where:** n.py:1
- **Rule:** No dead structure
- **Severity:** critical
- **Why:** a.
- **Instead:** b.

- **Where:** n.py:2
- **Rule:** Named constants
- **Severity:** Major.
- **Why:** a.
- **Instead:** b.

- **Where:** n.py:3
- **Rule:** No dead structure
- **Severity:** minor
- **Why:** a.
- **Instead:** b.

- **Where:** n.py:4
- **Severity:** severe
- **Why:** a.
- **Instead:** b.

- **Where:** n.py:5
- **Rule:** Names
- **Why:** a.
- **Instead:** b.'
readonly TWO_CONFLICTS='- **Where:** n.py:6
- **Rule:** A settled decision
- **Severity:** major
- **Why:** a.
- **Instead:** b.

- **Where:** n.py:7
- **Rule:** Another
- **Severity:** minor
- **Why:** a.
- **Instead:** b.'
assert "a return counts its findings by severity, its conflicts and each finding's rule" \
  "$(counts "$EVERY_SEVERITY" "$TWO_CONFLICTS")" \
  '[{"critical":1,"major":1,"minor":1,"fix":0,"consider":0,"unrated":2},2,["No dead structure","Named constants","No dead structure","Names"]]'
assert "findings in prose rather than bullets leave the verdict uncounted" \
  "$(counts 'The constant on line 2 is unused.' none)" '[null,null,null]'
assert "a conflict in prose rather than bullets leaves the verdict uncounted" \
  "$(counts "$(finding)" 'The brief settles this the other way.')" '[null,null,null]'
assert "an uncounted return is still logged" "$(tail -n 1 "$log" | jq -r .verdict)" return
many="$(for _ in $(seq 1001); do printf -- '- **Where:** n.py:1\n- **Severity:** minor\n'; done)"
assert "more than 1000 findings of a kind leave the verdict uncounted" "$(counts "$many" none)" '[null,null,null]'
assert "a report naming two repositories leaves each verdict uncounted" \
  "$(decided record_logged "$(sections)"$'\nRepo: '"$logged"$'\nVerdict: return\nRepo: '"$other"$'\nVerdict: return' | jq -sc 'map([.findings, .conflicts, .rules])')" \
  '[[null,null,null],[null,null,null]]'
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

assert "a report with no verdict logs a deny" "$(decided record_logged 'No verdict.' | jq -r '[.gate, .decision, .reason] | @tsv')" "verdict	deny	missing_verdict"
assert "the second hand-back without a verdict logs an allow" "$(decided record_logged 'No verdict.' | jq -r '[.decision, .reason] | @tsv')" "allow	missing_verdict"
assert "a report with no Repo line logs missing_repo" "$(decided record_logged $'Fine.\nVerdict: accept' | jq -r .reason)" missing_repo
assert "a relative Repo path logs repo_relative" "$(decided record_logged "$(report logged accept)" | jq -r .reason)" repo_relative
assert "a report without the sections logs missing_findings" "$(decided record_logged $'Fine.\nRepo: '"$logged"$'\nVerdict: return' | jq -r '[.gate, .decision, .reason] | @tsv')" "verdict	deny	missing_findings"
reviewer=r3
assert "an accept with a finding logs accept_with_findings" "$(decided record_logged "$(sections "$(finding)")"$'\nRepo: '"$logged"$'\nVerdict: accept' | jq -r .reason)" accept_with_findings
assert "a return for a brief with no diff logs reason no_diff" "$(decided record_logged "$(sections)"$'\nReason: no_diff\nRepo: '"$logged"$'\nVerdict: return' | jq -r '[.verdict, .reason] | @tsv')" "return	no_diff"
assert "a no_diff return beside an accept for another repo logs the reason on its own pair only" \
  "$(decided record_logged "$(sections)"$'\nReason: no_diff\nRepo: '"$logged"$'\nVerdict: return\nRepo: '"$other"$'\nVerdict: accept' | jq -sc 'map(.reason)')" '["no_diff",null]'
assert "a verdict with no Reason line logs a null reason" "$(decided record_logged "$(report "$logged" return)" | jq -c .reason)" null
assert "two pairs naming one repository log repo_repeated" "$(decided record_logged "$(sections)"$'\nRepo: '"$logged"$'\nVerdict: return\nRepo: '"$logged"$'\nVerdict: accept' | jq -r .reason)" repo_repeated
record_logged "$(report "$logged" return)" >/dev/null
assert "an accept from the reviewer that returned logs same_reviewer" "$(decided record_logged "$(report "$logged" accept)" | jq -r '[.gate, .decision, .reason] | @tsv')" "verdict	deny	same_reviewer"
before="$(lines)"
record_logged "$(report "$logged" accept)" >/dev/null
assert "its second hand-back logs an allow and no verdict" "$(new_lines "$before" | jq -sc 'map([.event, .decision, .reason])')" '[["gate","allow","same_reviewer"]]'
assert "a Repo path that is not a repository logs repo_not_found" "$(decided record_logged "$(report "$scratch/nowhere" accept)" | jq -r .reason)" repo_not_found

(cd "$logged" && git checkout -q NOTES.md && printf 'n = 4\n' >n.py)
mv "$log" "$log.kept"
mkdir "$log"
assert "an unwritable log leaves a deny unchanged" "$(gate_logged 'git commit -am x')" "$(denied 'n.py (working tree)')"
assert "an unwritable log leaves the deny's exit code at 0" "$(gate_logged 'git commit -am x' >/dev/null; echo "$?")" 0
assert "an unwritable log warns on stderr" \
  "$(jq -cn --arg cwd "$logged" '{tool_input: {command: "git commit -am x"}, cwd: $cwd}' | { "$GATE" >/dev/null; } 2>&1 | grep -c '^commit-gate.sh: the event log was not written')" 1
reviewer=r4
assert "an unwritable log still records an accept" "$(record_logged "$(report "$logged" accept)")" ""
assert "an unwritable log leaves an allow unchanged" "$(gate_logged 'git commit -am x')" ""
rmdir "$log"
mv "$log.kept" "$log"

finish
