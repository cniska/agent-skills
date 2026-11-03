#!/usr/bin/env bash
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/review-gate.test-harness.sh"

top="$(cd "$repo" && git rev-parse --show-toplevel)"
(cd "$repo" && printf 'print(0)\n' >lib.py && git add lib.py && git commit -q -m lib)

returning() {
  local found severity path
  found="$(for severity in "${@:2}"; do
    for path in $1; do finding "$top/$path" 'Size everything to the need' "$severity"; done
  done | jq -sc .)"
  report "$repo" return ".findings = $found"
}
reset() { (cd "$repo" && git checkout -q -- . && git clean -qfd); }
last_cover_reason() { jq -sc '[.[] | select(.event == "gate" and .gate == "commit")] | last | [.decision, .reason]' "$log"; }

edit app.py 'print(2)'
assert "a return whose every finding is minor is allowed" "$(record_handback "$(returning app.py minor)")" "$(allowed)"
edit app.py 'print(3)'
assert "the fix to a path its reviewer read commits without another review" "$(gate 'git commit -am fix')" ""
assert "that commit logs an allow as accepted" "$(last_cover_reason)" '["allow","accepted"]'
land
edit app.py 'print(4)'
assert "a commit touching the path ends its cover" "$(gate 'git commit -am x')" "$(denied 'app.py (working tree)')"

reset
edit app.py 'print(5)'
record_handback "$(returning app.py minor minor)" >/dev/null
edit app.py 'print(6)'
edit fresh.py 'print(7)'
assert "a fix that adds a path the return did not cover needs a review for that path" \
  "$(gate 'git add -A && git commit -m fix')" "$(denied 'fresh.py (working tree)')"
reset

edit app.py 'print(8)'
record_handback "$(returning 'app.py lib.py' minor)" >/dev/null
edit lib.py 'print(9)'
assert "a path a minor finding cites, outside every diff the reviewer read, is covered" "$(gate 'git commit -m fix -- lib.py')" ""
edit README.md 'notes'
(cd "$repo" && git commit -q -m notes -- README.md)
edit lib.py 'print(12)'
assert "any later commit ends the cover of each path that commit left alone" \
  "$(gate 'git commit -m fix -- lib.py')" "$(denied 'app.py (working tree)' 'lib.py (working tree)')"
reset

edit app.py 'print(10)'
record_handback "$(report "$repo" accept)" >/dev/null
record_handback "$(returning app.py minor major)" >/dev/null
assert "a return with a major finding voids the accept and covers nothing" "$(gate 'git commit -am x')" "$(denied 'app.py (working tree)')"
record_handback "$(returning app.py critical)" >/dev/null
assert "a return with a critical finding covers nothing" "$(gate 'git commit -am x')" "$(denied 'app.py (working tree)')"
record_handback "$(returning app.py minor | jq -c '.conflicts = [.findings[0]]')" >/dev/null
assert "a minor return with a conflict covers nothing" "$(gate 'git commit -am x')" "$(denied 'app.py (working tree)')"
record_handback "$(report "$repo" return)" >/dev/null
assert "a return with no finding covers nothing" "$(gate 'git commit -am x')" "$(denied 'app.py (working tree)')"
designer="$(fresh_agent)"
record_as "$designer" "$(returning app.py minor)" cniska-skills:designer >/dev/null
assert "a designer's minor return covers nothing" "$(gate 'git commit -am x')" "$(denied 'app.py (working tree)')"
unread="$(fresh_agent)"
record_listing "$unread" "$(returning app.py minor)" "$(briefed "$(diff_of "$(report "$repo" return)")")" "$scratch/never-read.diff" >/dev/null
assert "a minor return refused for a diff its reviewer did not read covers nothing" "$(gate 'git commit -am x')" "$(denied 'app.py (working tree)')"

record_handback "$(returning app.py minor | jq -c --arg path "$scratch/elsewhere.py" '.findings[0].where += [{path: $path, line: 1}]')" >/dev/null
assert "a minor return citing a path outside the repo still covers the paths inside it" "$(gate 'git commit -am x')" ""
land
edit app.py 'print(11)'
record_handback "$(returning app.py minor)" >/dev/null
record_handback "$(returning app.py major)" >/dev/null
assert "a later return with a major finding voids the cover" "$(gate 'git commit -am x')" "$(denied 'app.py (working tree)')"

finish
