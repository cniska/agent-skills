#!/usr/bin/env bash
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/review-gate.test-harness.sh"

readonly MISSING_REASON="End your report with a last line that is exactly 'Verdict: accept' or 'Verdict: return'."
MISSING="$(refused "$MISSING_REASON")"
MISSING_AT_STOP="$(blocked "$MISSING_REASON")"
readonly MISSING MISSING_AT_STOP
readonly SHAPE="The report is three sections, '## Findings', '## Conflicts' and '## Clean', each saying 'none' when it is empty; each finding is five bullets, '- **Where:**', '- **Rule:** <the rule's heading>', '- **Severity:** critical, major or minor', '- **Why:**' and '- **Instead:**'; then, at the end, 'Repo: <absolute path>' with 'Verdict: accept' or 'Verdict: return' on the line below it, one such pair per repository."
REFERENCE="$HERE/../skills/expertise/principles/references/review-report.md"
NO_SECTIONS="$(refused "The report lacks a section. $SHAPE")"
WITH_FINDINGS="$(refused "An accept needs 'none' under '## Findings'; while any finding stands, end with 'Verdict: return'. $SHAPE")"
readonly NO_SECTIONS WITH_FINDINGS

labels="$(awk '/^```/ { inside = !inside; next } inside && /^(## |- \*\*[A-Z][a-z]*:\*\*)/' "$REFERENCE" | sed -E 's/^(- \*\*[A-Za-z]+:\*\*).*/\1/')"
assert "the review report reference holds three sections and five finding bullets" "$(printf '%s\n' "$labels" | wc -l | tr -d ' ')" 8
while IFS= read -r label; do
  case "$SHAPE" in *"'$label"*) named=yes ;; *) named=no ;; esac
  assert "the refusal names the review report's $label" "$named" yes
done <<<"$labels"

edit app.py 'print(4)'

assert "a report with no verdict keeps the reviewer running" "$(record_handback 'Looks fine to me.')" "$MISSING"
assert "a verdict not on its own line does not count" "$(record_handback 'My Verdict: accept')" "$MISSING"
assert "a missing verdict on the second hand-back lets the reviewer hand back" "$(record_handback 'Still no verdict.' again)" ""

assert "a report without the three sections keeps the reviewer running" "$(record_handback $'Fine.\nRepo: '"$repo"$'\nVerdict: accept')" "$NO_SECTIONS"
assert "a report missing one section keeps the reviewer running" "$(record_handback "$(sections | grep -v '^## Clean$')"$'\nRepo: '"$repo"$'\nVerdict: accept')" "$NO_SECTIONS"
assert "an accept without the sections approves nothing" "$(gate 'git commit -am x')" "$(denied)"
assert "an accept with a finding keeps the reviewer running" "$(record_handback "$(sections "$(finding)")"$'\nRepo: '"$repo"$'\nVerdict: accept')" "$WITH_FINDINGS"
assert "an accept with 'none' and a finding keeps the reviewer running" "$(record_handback "$(sections "none"$'\n'"$(finding)")"$'\nRepo: '"$repo"$'\nVerdict: accept')" "$WITH_FINDINGS"
assert "an accept with a finding on the second hand-back lets the reviewer hand back" "$(record_handback "$(sections "$(finding)")"$'\nRepo: '"$repo"$'\nVerdict: accept' again)" ""
assert "an accept with a finding approves nothing" "$(gate 'git commit -am x')" "$(denied)"
assert "an accept whose Findings says 'None.' counts" "$(record_handback "$(sections 'None.')"$'\nRepo: '"$repo"$'\nVerdict: accept')" ""
assert "that accept lets the diff commit" "$(gate 'git commit -am x')" ""
assert "a return with a finding records nothing to say" "$(record_handback "$(sections "$(finding)")"$'\nRepo: '"$repo"$'\nVerdict: return')" ""
assert "that return clears the accept" "$(gate 'git commit -am x')" "$(denied)"
record_handback "$(report "$repo" accept)" >/dev/null
assert "a return without the sections on the second hand-back still clears the accept" \
  "$(record_handback $'Bad.\nRepo: '"$repo"$'\nVerdict: return' again; gate 'git commit -am x')" "$(denied)"

assert "a verdict in the last message counts when there is no handback" "$(record_last_message "$(report "$repo" accept)")" ""
assert "that verdict lets the diff commit" "$(gate 'git commit -am x')" ""

assert "a hand-back from an agent other than the reviewer is not judged" "$(record_as worker 'No verdict.' general-purpose)" ""
edit app.py 'print(5)'
assert "an accept handed back by another agent approves nothing" "$(record_as worker "$(report "$repo" accept)" general-purpose; gate 'git commit -am x')" "$(denied)"

transcript="$scratch/late.jsonl"
stop_as() {
  jq -cn --arg cwd "$repo" --arg transcript "$transcript" --arg agent "$1" --arg message "${2:-}" \
    '{hook_event_name: "SubagentStop", agent_type: "cniska-skills:reviewer", agent_id: $agent, cwd: $cwd, agent_transcript_path: $transcript, last_assistant_message: $message}' | "$RECORD" 2>/dev/null
}
stop_on() { stop_as "$(fresh_agent)" "${1:-}"; }
stop_late() {
  local message="$1"
  shift
  (sleep 0.5 && "$@" >>"$transcript") &
  stop_on "$message"
  wait
}

record_handback "$(report "$repo" accept)" >/dev/null
read_line >"$transcript"
assert "a stop whose hand-back reaches the transcript late leaves it to the hand-back hook" "$(stop_late '' handback_line "$(report "$repo" return)")" ""
assert "that stop records nothing from the hand-back" "$(gate 'git commit -am x')" ""

{ handback_line "$(report "$repo" accept)" && jq -cn '{type: "attachment", attachment: {type: "hook_blocking_error"}}'; } >"$transcript"
assert "a text end after a block is judged by the text, not the earlier hand-back" "$(stop_late 'Looking again.' text_line 'Looking again.')" "$MISSING_AT_STOP"

{ handback_line "$(report "$repo" accept)" && jq -cn '{type: "user", message: {content: "Look again."}}'; } >"$transcript"
assert "a text end after a resume is judged by the text, not the earlier hand-back" "$(stop_late 'Looking again.' text_line 'Looking again.')" "$MISSING_AT_STOP"

record_handback "$(report "$repo" return)" >/dev/null
{ briefed "$(diff_of "$(report "$repo" accept)")" && text_line "$(report "$repo" accept)"; } >"$transcript"
assert "a text end with no last message is judged by its final text" "$(stop_on)" ""
assert "that text accept lets the diff commit" "$(gate 'git commit -am x')" ""

edit app.py 'print(6)'
assert "a denied hand-back keeps the reviewer running" "$(record_as texter 'No verdict.')" "$MISSING"
text_line 'No verdict.' >"$transcript"
assert "a run that then ends in text with the same fault stops through the same bound" "$(stop_as texter 'No verdict.')" ""
text_line $'Fine.\nRepo: '"$repo"$'\nVerdict: accept' >"$transcript"
assert "a text end with a fault not yet denied keeps the reviewer running" "$(stop_as texter $'Fine.\nRepo: '"$repo"$'\nVerdict: accept')" "$(blocked "The report lacks a section. $SHAPE")"
assert "neither end approves anything" "$(gate 'git commit -am x')" "$(denied)"

assert "a text stop after an accepting handback is judged by the text alone" "$(stop_on 'Looking again.')" "$MISSING_AT_STOP"

land
edit README.md 'more docs'
assert "a Markdown-only change commits without a verdict" "$(gate 'git commit -am docs')" ""
(cd "$repo" && printf 'x = 1\n' >scratch.py && git add README.md)
assert "a staged Markdown-only change commits beside an untracked code file" "$(gate 'git commit -m docs')" ""
assert "a same-command add of an untracked code file needs a verdict" "$(gate 'git add -A && git commit -m docs')" "$(denied)"
(cd "$repo" && rm scratch.py)
land
(cd "$repo" && git mv app.py app.md)
assert "a staged move of code to Markdown needs a verdict" "$(gate 'git commit -m x')" "$(denied)"
(cd "$repo" && git mv app.md app.py)

finish
