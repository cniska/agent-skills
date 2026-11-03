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
resumed="$(fresh_agent)"
record_as "$resumed" "$(returning app.py major)" >/dev/null
rm -f "$CLAUDE_PLUGIN_DATA/reports/$resumed.json"
assert "a resumed reviewer's minor return after its own major return is still recorded" "$(record_as "$resumed" "$(returning app.py minor)")" "$(allowed)"
assert "that minor return covers nothing, so the fix waits for a fresh reviewer" "$(gate 'git commit -am x')" "$(denied 'app.py (working tree)')"
retried="$(fresh_agent)"
record_as "$retried" "$(returning app.py minor | jq -c '.findings[0].rule = "Not a rule"')" >/dev/null
assert "a reviewer's minor return refused for its rule name is corrected" "$(record_as "$retried" "$(returning app.py minor)")" "$(allowed)"
assert "and the corrected minor return covers the fix" "$(gate 'git commit -am x')" ""
record_handback "$(returning app.py major)" >/dev/null
emptied="$(fresh_agent)"
record_as "$emptied" "$(report "$repo" return)" >/dev/null
rm -f "$CLAUDE_PLUGIN_DATA/reports/$emptied.json"
record_as "$emptied" "$(returning app.py minor)" >/dev/null
assert "a reviewer's minor return after its own return with no finding covers the fix" "$(gate 'git commit -am x')" ""
record_handback "$(returning app.py major)" >/dev/null
fresh="$(fresh_agent)"
assert "a fresh reviewer's minor return still covers the fix" "$(record_as "$fresh" "$(returning app.py minor)")" "$(allowed)"
assert "and the fix commits" "$(gate 'git commit -am x')" ""

malformed="$(fresh_agent)"
record_as "$malformed" "$(returning app.py minor | jq -c '.findings = ["minor"]')" >/dev/null
rm -f "$CLAUDE_PLUGIN_DATA/reports/$malformed.json"
record_as "$malformed" "$(returning app.py minor)" >/dev/null
assert "a reviewer whose return was malformed gives no minor cover later" "$(gate 'git commit -am x')" "$(denied 'app.py (working tree)')"

land
edit app.py 'print(11)'
record_handback "$(returning app.py minor)" >/dev/null
record_handback "$(returning app.py major)" >/dev/null
assert "a later return with a major finding voids the cover" "$(gate 'git commit -am x')" "$(denied 'app.py (working tree)')"

reset
edit app.py 'print(13)'
record_handback "$(returning app.py minor)" >/dev/null
edit app.py 'print(14)'
edit README.md 'aside'
(cd "$repo" && git stash -q && git stash pop -q)
assert "a git stash and pop after a minor return keeps its cover" "$(gate 'git commit -am fix')" ""
land
edit app.py 'print(15)'
(cd "$repo" && git reset -q --soft HEAD~1)
assert "a rewind to the commit a minor return was recorded on does not bring its cover back" "$(gate 'git commit -am x')" "$(denied 'app.py (staged and working tree)')"

reset
recorded_on="$(git -C "$repo" rev-parse HEAD)"
moves() { git -C "$repo" reflog show --format=%H HEAD | uniq | wc -l | tr -d ' '; }
edit app.py 'print(17)'
record_handback "$(returning app.py minor)" >/dev/null
moves_then="$(moves)"
land
while [ "$(moves)" -ge "$moves_then" ]; do
  git -C "$repo" reflog delete "HEAD@{$(($(git -C "$repo" reflog show HEAD | wc -l) - 1))}"
done
edit app.py 'print(18)'
(cd "$repo" && GIT_COMMITTER_DATE='@4000000000 +0000' git reset -q --soft "$recorded_on")
assert "the rewind restores the move count the minor return was recorded at" "$(moves)" "$moves_then"
assert "a rewind after reflog expiry restores the move count, yet its later arrival time ends the cover" \
  "$(gate 'git commit -am x')" "$(denied 'app.py (staged and working tree)')"

other="$scratch/other"
mkdir -p "$other"
(cd "$other" && git init -q -b main && printf 'print(100)\n' >app.py && printf 'print(101)\n' >lib.py && git add -A && git commit -q -m base)
other_top="$(cd "$other" && git rev-parse --show-toplevel)"
(cd "$repo" && git reset -q --hard && printf 'print(16)\n' >>app.py)
both="$(fresh_agent)"
listed="$(scratch_file "$(diff_in "$repo" app.py)")"
record_listing "$both" "$(report "$other" return ".findings = [$(finding "$other_top/lib.py")]")" "$(read_of "$listed")" "$listed" >/dev/null
(cd "$other" && printf 'print(102)\n' >>app.py && printf 'print(103)\n' >>lib.py)
assert "a minor return on one repo covers no path a diff of another repo names" "$(gate_from 'git commit -am x' "$other")" "$(denied 'app.py (working tree)')"

unborn="$scratch/unborn"
mkdir -p "$unborn"
(cd "$unborn" && git init -q -b main && printf 'print(200)\n' >app.py && printf 'print(201)\n' >lib.py)
unborn_top="$(cd "$unborn" && git rev-parse --show-toplevel)"
listed="$(scratch_file "$(diff_in "$unborn" lib.py)")"
record_listing "$(fresh_agent)" "$(report "$unborn" accept)" "$(read_of "$listed")" "$listed" >/dev/null
first_look="$(fresh_agent)"
listed="$(scratch_file "$(diff_in "$unborn" app.py)")"
record_listing "$first_look" "$(report "$unborn" return ".findings = [$(finding "$unborn_top/app.py")]")" "$(read_of "$listed")" "$listed" >/dev/null
assert "a minor return before the first commit, with no reflog to bound it, covers nothing" "$(gate_from 'git commit -am x' "$unborn")" "$(denied 'app.py (working tree)')"

finish
