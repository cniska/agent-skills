#!/usr/bin/env bash
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/review-gate.test-harness.sh"

top="$(cd "$repo" && git rev-parse --show-toplevel)"
third() { refused "This is return $1 on one commit of '$top'. End your report with the line 'This commit has been returned $1 times: stop fixing it, park it, and bring whoever coordinates you what the returns show and the one decision that would end them, as step 4 of cniska-skills:task says.' above its 'Repo:' line, and keep your verdict."; }
third_at_stop() { blocked "This is return $1 on one commit of '$top'. End your report with the line 'This commit has been returned $1 times: stop fixing it, park it, and bring whoever coordinates you what the returns show and the one decision that would end them, as step 4 of cniska-skills:task says.' above its 'Repo:' line, and keep your verdict."; }
step="$(awk '/^## / { inside = ($0 == "## Pick the route") } inside && /^4\. /' "$HERE/../skills/workflow/task/SKILL.md")"
case "$step" in *"After a third return on one commit, stop fixing that commit"*) named=yes ;; *) named=no ;; esac
assert "step 4 of the task skill is the one that parks a commit after its third return" "$named" yes
new_lines() { tail -n +"$(($1 + 1))" "$log"; }
lines() { wc -l <"$log" | tr -d ' '; }

edit app.py 'print(2)'
first="$(fresh_agent)"
assert "a first return with a malformed report keeps its reviewer running" \
  "$(record_as "$first" "$(sections | grep -v '^## Clean$')"$'\nRepo: '"$repo"$'\nVerdict: return')" \
  "$(refused "The report lacks a section. The report is four sections, '## Findings', '## Conflicts', '## Follow-ups' and '## Clean', each saying 'none' when it is empty; a defect that was there before the change and does not block it goes under '## Follow-ups', never '## Findings'; each finding is five bullets, '- **Where:**', '- **Rule:** <the rule's heading>', '- **Severity:** critical, major or minor', '- **Why:**' and '- **Instead:**'; then, at the end, 'Repo: <absolute path>' with 'Verdict: accept' or 'Verdict: return' on the line below it, one such pair per repository.")"
assert "that reviewer's fixed first return gets no note" "$(record_as "$first" "$(report "$repo" return)")" ""
assert "a second return on the same commit gets no note, so the denied pass counted once" "$(record_handback "$(report "$repo" return)")" ""
edit app.py 'print(3)'
assert "an accept between returns adds nothing to the count" "$(record_handback "$(report "$repo" accept)")" ""
assert "that accept lets the change commit" "$(gate 'git commit -am x')" ""

before="$(lines)"
returner="$(fresh_agent)"
assert "a third return on the same commit keeps its reviewer running with the note" "$(record_as "$returner" "$(report "$repo" return)")" "$(third 3)"
assert "the note logs a verdict-gate deny naming the repository" \
  "$(new_lines "$before" | jq -sc 'map([.event, .gate, .decision, .reason, .repo, .head, .fingerprint])')" \
  "$(jq -cn --arg repo "$top" '[["gate", "verdict", "deny", "third_return", $repo, null, null]]')"
assert "the note records no verdict yet" "$(new_lines "$before" | jq -s 'map(select(.event == "verdict")) | length')" 0

before="$(lines)"
assert "that reviewer's next hand-back is let through" "$(record_as "$returner" "$(report "$repo" return)")" ""
assert "that hand-back records the return as the noted reviewer's own verdict" \
  "$(new_lines "$before" | jq -sc 'map([.event, .verdict, .repo, .agent])')" "$(jq -cn --arg repo "$top" --arg agent "$returner" '[["verdict", "return", $repo, $agent]]')"
assert "the third return still voids the accept" "$(gate 'git commit -am x')" "$(denied 'app.py (working tree)')"
assert "a fourth return counts the third reviewer once" "$(record_handback "$(report "$repo" return)")" "$(third 4)"
assert "an accept after the note records as any accept" "$(record_handback "$(report "$repo" accept)")" ""
assert "that accept lets the commit land" "$(gate 'git commit -am x')" ""

land
edit app.py 'print(4)'
assert "a commit that lands starts the count over" "$(record_handback "$(report "$repo" return)")" ""
assert "a second return on the new commit gets no note" "$(record_handback "$(report "$repo" return)")" ""

(cd "$repo" && git checkout -q -- app.py)
edit README.md 'other change'
assert "a change replaced by one on other paths starts the count over" "$(record_handback "$(report "$repo" return)")" ""
assert "a second return on the replacing change gets no note" "$(record_handback "$(report "$repo" return)")" ""
assert "a third return on the replacing change gets the note" "$(record_handback "$(report "$repo" return)")" "$(third 3)"

stopper="$(fresh_agent)"
stop_transcript="$(scratch_file "$(briefed "$(diff_of "$(report "$repo" return)")" && text_line "$(report "$repo" return)")")"
stop_with() {
  jq -cn --arg cwd "$repo" --arg message "$(report "$repo" return)" --arg agent "$stopper" --arg transcript "$stop_transcript" \
    '{hook_event_name: "SubagentStop", agent_type: "cniska-skills:reviewer", agent_id: $agent, cwd: $cwd, last_assistant_message: $message, agent_transcript_path: $transcript}' | "$RECORD" 2>/dev/null
}
assert "a fourth return that ends in text keeps its reviewer running with the note" "$(stop_with)" "$(third_at_stop 4)"
assert "its next stop is let through" "$(stop_with)" ""

finish
