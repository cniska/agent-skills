#!/usr/bin/env bash
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/review-gate.test-harness.sh"

readonly ACCEPT_WITH_FINDINGS_FIX="An accept has no findings: while a finding stands, the judgment's verdict is return. A defect that was there before the change and does not block it goes under follow_ups."
WITH_FINDINGS="$(refused "'$repo' is accepted with findings. $ACCEPT_WITH_FINDINGS_FIX")"
readonly WITH_FINDINGS
with_finding() { report "$repo" "$1" ".findings = [$(finding "$repo/app.py")]"; }
with_follow_up() { report "$repo" "$1" ".follow_ups = [$(finding "$repo/app.py")]"; }
last_gate() { jq -sc '[.[] | select(.event == "gate")] | last | [.gate, .decision, .reason]' "$log"; }

edit app.py 'print(4)'

assert "an accept with a finding keeps the reviewer running" "$(record_handback "$(with_finding accept)")" "$WITH_FINDINGS"
assert "that refusal is logged as accept_with_findings" "$(last_gate)" '["verdict","deny","accept_with_findings"]'
twice="$(fresh_agent)"
record_as "$twice" "$(with_finding accept)" >/dev/null
assert "an accept with a finding on the second call lets the reviewer hand back" "$(record_as "$twice" "$(with_finding accept)")" "$(allowed)"
assert "that call is stored as not recorded" "$(stored "$twice" | jq -c .gate)" '{"recorded":false,"code":"accept_with_findings"}'
assert "an accept with a finding approves nothing" "$(gate 'git commit -am x')" "$(denied 'app.py (working tree)')"
assert "an accept with a finding and a follow-up keeps the reviewer running" \
  "$(record_handback "$(report "$repo" accept ".findings = [$(finding "$repo/app.py")] | .follow_ups = [$(finding "$repo/README.md")]")")" "$WITH_FINDINGS"
assert "an accept with only a follow-up records" "$(record_handback "$(with_follow_up accept)")" "$(allowed)"
assert "that accept lets the diff commit" "$(gate 'git commit -am x')" ""
edit app.py 'print(41)'
assert "a return with a finding is allowed" "$(record_handback "$(with_finding return)")" "$(allowed)"
assert "that return clears the accept" "$(gate 'git commit -am x')" "$(denied 'app.py (working tree)')"

record_handback "$(report "$repo" accept)" >/dev/null
malformed="$(fresh_agent)"
bad_return="$(report "$repo" return 'del(.clean)')"
assert "a return off the schema keeps the reviewer running" "$(record_as "$malformed" "$bad_return" | jq -r .hookSpecificOutput.permissionDecision)" deny
assert "a return off the schema still clears the accept" "$(gate 'git commit -am x')" "$(denied 'app.py (working tree)')"
record_handback "$(report "$repo" accept)" >/dev/null
assert "a return off the schema on the second call lets the reviewer hand back" "$(record_as "$malformed" "$bad_return")" "$(allowed)"
assert "that return past the bound still clears the accept" "$(gate 'git commit -am x')" "$(denied 'app.py (working tree)')"

readonly NO_DIFF_ONLY="The report gives a reason it may not:
/judgments/0/reason must be \"no_diff\" from a reviewer
Call the tool again with each of these fixed."
assert "a designer's reason from a reviewer keeps it running" "$(record_handback "$(report "$repo" return '.reason = "verify_gap"')")" "$(refused "$NO_DIFF_ONLY")"
assert "that refusal is logged as payload_invalid" "$(last_gate)" '["verdict","deny","payload_invalid"]'
assert "a no_diff return from a reviewer records" "$(record_handback "$(report "$repo" return '.reason = "no_diff"')")" "$(allowed)"

assert "a verdict from an agent other than the reviewer or designer is refused" \
  "$(record_as "$(fresh_agent)" "$(report "$repo" accept)" general-purpose)" \
  "$(refused "Only cniska-skills:reviewer or cniska-skills:designer report through verdict; this session is general-purpose. Hand back as your own instructions say.")"
edit app.py 'print(5)'
designer="$(fresh_agent)"
assert "a designer's accept is allowed" "$(record_as "$designer" "$(report "$repo" accept)" cniska-skills:designer)" "$(allowed)"
assert "a designer's accept is stored without a judgment record" "$(stored "$designer" | jq -c .gate)" '{"recorded":true}'
assert "a designer's accept approves nothing" "$(gate 'git commit -am x')" "$(denied 'app.py (working tree)')"

listed="$(fresh_agent)"
unread="$(scratch_file "$(diff_in "$repo" app.py)")"
assert "a diff the reviewer lists but never read keeps it running" \
  "$(record_listing "$listed" "$(report "$repo" accept)" "$(briefed "$(diff_in "$repo" app.py)")" "$unread")" \
  "$(refused "You list '$unread' in diffs but did not read it with Read. List only the diff files you read.")"
assert "that refusal is logged as diff_not_read" "$(last_gate)" '["verdict","deny","diff_not_read"]'
assert "an accept listing an unread diff approves nothing" "$(gate 'git commit -am x')" "$(denied 'app.py (working tree)')"

land
edit README.md 'more docs'
assert "a Markdown-only change commits without a verdict" "$(gate 'git commit -am docs')" ""
(cd "$repo" && printf 'x = 1\n' >scratch.py && git add README.md)
assert "an untracked code file blocks a staged Markdown-only commit" "$(gate 'git commit -m docs')" "$(denied 'scratch.py (working tree)')"
assert "a same-command add of an untracked code file needs a verdict" "$(gate 'git add -A && git commit -m docs')" "$(denied 'scratch.py (working tree)')"
(cd "$repo" && rm scratch.py)
land
(cd "$repo" && git mv app.py app.md)
assert "a staged move of code to Markdown needs a verdict" "$(gate 'git commit -m x')" "$(denied 'app.py (staged and working tree)')"
(cd "$repo" && git mv app.md app.py)

finish
