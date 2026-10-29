#!/usr/bin/env bash
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/review-gate.test-harness.sh"

assert "a commit with nothing changed passes" "$(gate 'git commit -m x')" ""
edit app.py 'print(2)'
assert "an unreviewed code change blocks the commit" "$(gate 'git commit -am x')" "$(denied 'app.py (working tree)')"
assert "a command that is not a commit passes" "$(gate 'git status')" ""
assert "a commit word in another git command passes" "$(gate 'git log --grep commit')" ""
assert "a commit through an absolute git path is gated" "$(gate '/usr/bin/git -C . commit -m x')" "$(denied 'app.py (working tree)')"
assert "a commit after cd and && is gated" "$(gate "cd $repo && git commit -m x")" "$(denied 'app.py (working tree)')"

shape_refusal() { refused "The report does not match the verdict tool's schema:"$'\n'"$1"$'\n'"Call the tool again with each of these fixed."; }
no_repo="$(report "$repo" accept 'del(.repo)')"
assert "a judgment with no repo keeps the reviewer running" "$(record_handback "$no_repo")" "$(shape_refusal "/judgments/0/repo is required")"
assert "an accept with no repo approves nothing" "$(gate 'git commit -am x')" "$(denied 'app.py (working tree)')"
assert "a repo that is not a repository keeps the reviewer running" "$(record_handback "$(report "$scratch/nowhere" accept)")" \
  "$(refused "'$scratch/nowhere' is not a repository. Name the repository the change is in as the judgment's repo.")"
assert "a relative repo keeps the reviewer running" "$(record_handback "$(report repo accept)")" "$(shape_refusal "/judgments/0/repo must match the pattern ^/")"
twice="$(fresh_agent)"
record_as "$twice" "$no_repo" >/dev/null
assert "a judgment with no repo on the second call lets the reviewer hand back" "$(record_as "$twice" "$no_repo")" "$(allowed)"
assert "that call is stored as not recorded" "$(stored "$twice" | jq -c .gate)" '{"recorded":false,"code":"payload_invalid"}'
assert "a reviewer let through without a repo approved nothing" "$(gate 'git commit -am x')" "$(denied 'app.py (working tree)')"

assert "an accepting verdict is allowed" "$(record_handback "$(report "$repo" accept)")" "$(allowed)"
assert "an accepted diff commits" "$(gate 'git commit -am x')" ""
edit app.py 'print(3)'
assert "an edit after the accept blocks the commit" "$(gate 'git commit -am x')" "$(denied 'app.py (working tree)')"

land
edit app.py 'print(31)'

record_handback "$(report "$repo" accept)" >/dev/null
(cd "$repo" && printf 'x = 1\n' >new.py)
assert "a new untracked file after the accept blocks the commit" "$(gate 'git commit -am x')" "$(denied 'new.py (working tree)')"

record_handback "$(report "$repo" accept)" >/dev/null
(cd "$repo" && git add new.py)
assert "staging a new file the reviewer accepted untracked still commits" "$(gate 'git commit -am x')" ""
(cd "$repo" && git reset -q new.py)
assert "unstaging an accepted new file still commits" "$(gate 'git commit -am x')" ""

land
(cd "$repo" && mv app.py moved.py)
record_handback "$(report "$repo" accept)" >/dev/null
(cd "$repo" && git add -A)
assert "staging an accepted move still commits" "$(gate 'git commit -m x')" ""
(cd "$repo" && git mv moved.py app.py)
edit app.py 'print(4)'

record_handback "$(report "$repo" accept)" >/dev/null
record_handback "$(report "$repo" return)" >/dev/null
assert "a returning verdict clears the accept" "$(gate 'git commit -am x')" "$(denied 'app.py (working tree)')"

returner="$(fresh_agent)"
record_listing "$returner" "$(report "$repo" return)" "$(briefed "$(diff_of "$(report "$repo" return)")")" "$diffs/unread.diff" >/dev/null
assert "a return refused for a diff it did not read still clears the accept" "$(gate 'git commit -am x')" "$(denied 'app.py (working tree)')"
assert "an accept from the reviewer that returned lets it hand back" "$(record_as "$returner" "$(report "$repo" accept)")" "$(allowed)"
assert "that accept is stored with the same_reviewer note" "$(stored "$returner" | jq -c '.gate.judgments[] | [.recorded, .code, .fix]')" \
  "$(jq -cn '[false, "same_reviewer", "This accept is not recorded: its reviewer returned this repository'"'"'s change earlier. Start a fresh cniska-skills:reviewer on the fix'"'"'s diff, with the change'"'"'s earlier diff files to read for findings as for its accept."]')"
assert "an accept from the reviewer that returned approves nothing" "$(gate 'git commit -am x')" "$(denied 'app.py (working tree)')"
assert "an accept from a fresh reviewer after the return records" "$(record_handback "$(report "$repo" accept)")" "$(allowed)"
assert "that fresh accept lets the diff commit" "$(gate 'git commit -am x')" ""

spare="$scratch/spare"
(cd "$scratch" && git init -q -b main spare)
spare_reviewer="$(fresh_agent)"
record_listing "$spare_reviewer" "$(report "$repo" return)" "$(briefed "$(diff_of "$(report "$repo" return)")")" "$diffs/unread.diff" >/dev/null
assert "the reviewer that returned may accept another repository" "$(record_as "$spare_reviewer" "$(report "$spare" accept)" | jq -c . ; stored "$spare_reviewer" | jq -c '.gate.judgments[0].recorded')" "$(allowed)
true"

(cd "$repo" && git reset -q --hard && printf 'a = 1\n' >a.py && printf 'b = 1\n' >b.py && printf 'c = 1\n' >c.py &&
  printf 'gen.js linguist-generated\n' >.gitattributes && printf 'g = 1\n' >gen.js && git add -A && git commit -q -m sides)
accept_of() { record_reading "$(fresh_agent)" "$(report "$repo" accept)" "$(briefed "$(diff_in "$repo" "$@")")" >/dev/null; }
last_reason() { tail -n 1 "$log" | jq -r .reason; }

edit a.py 'a = 2'
edit b.py 'b = 2'
edit c.py 'c = 2'
accept_of a.py b.py
assert "an unaccepted edit beside an accepted diff blocks the commit" "$(gate 'git commit -am x')" "$(denied 'c.py (working tree)')"
(cd "$repo" && git stash push -q -- c.py)
assert "the accepted diff commits once the unaccepted edit is stashed" "$(gate 'git commit -am x')" ""
land
(cd "$repo" && git stash pop -q && git checkout -q -- c.py)

edit a.py 'a = 3'
edit b.py 'b = 3'
accept_of a.py b.py
(cd "$repo" && git add a.py)
assert "the first of two commits of an accepted diff passes" "$(gate 'git commit -m x')" ""
(cd "$repo" && git commit -q -m a)
assert "the second commit of an accepted diff passes" "$(gate 'git commit -am x')" ""
edit b.py 'b = 4'
assert "an edit to the rest of an accepted diff between its commits blocks the second" "$(gate 'git commit -am x')" "$(denied 'b.py (working tree)')"
(cd "$repo" && git checkout -q -- b.py)

edit a.py 'a = 5'
(cd "$repo" && git add a.py && git show HEAD:a.py >a.py)
assert "an edit staged and then reverted in the working tree blocks the commit" "$(gate 'git commit -m x')" "$(denied 'a.py (staged)')"

(cd "$repo" && git checkout -q HEAD -- a.py)
edit a.py 'a = 6'
(cd "$repo" && git add a.py)
edit a.py 'a = 7'
accept_of a.py
assert "an accepted working-tree edit beside a different staged one blocks the commit" "$(gate 'git commit -m x')" "$(denied 'a.py (staged)')"
(cd "$repo" && git add a.py)
assert "staging the accepted working-tree edit lets it commit" "$(gate 'git commit -m x')" ""
(cd "$repo" && git commit -q -m a7 && git revert --no-edit HEAD >/dev/null && git show HEAD~1:a.py >a.py)
assert "accepted content landed again after a later commit touched its path is refused" "$(gate 'git commit -am x')" "$(denied 'a.py (working tree)')"
assert "that refusal says the path changed since its accept" "$(last_reason)" changed_since_accept

(cd "$repo" && git checkout -q -- a.py && git rm -q a.py)
accept_of a.py
assert "an accepted deletion commits" "$(gate 'git commit -m x')" ""
land
(cd "$repo" && git rm -q b.py)
assert "an unaccepted deletion is refused" "$(gate 'git commit -m x')" "$(denied 'b.py (staged and working tree)')"
(cd "$repo" && git reset -q --hard)

edit README.md 'more'
assert "a Markdown-only change commits without an accept" "$(gate 'git commit -am x')" ""
assert "that commit needs no code accept" "$(last_reason)" no_code_change
accept_of README.md
assert "a Markdown-only change commits with an accept" "$(gate 'git commit -am x')" ""
assert "that commit still needs no code accept" "$(last_reason)" no_code_change
land
edit gen.js 'g = 2'
assert "a generated-only change commits without an accept" "$(gate 'git commit -am x')" ""
assert "that generated commit needs no code accept" "$(last_reason)" no_code_change
accept_of gen.js
assert "a generated-only change commits with an accept" "$(gate 'git commit -am x')" ""
assert "that generated commit still needs no code accept" "$(last_reason)" no_code_change

(cd "$repo" && printf 'd = 1\n' >d.py && git add d.py && git commit -q -m d)
edit d.py 'd = 2'
(cd "$repo" && git add d.py)
edit d.py 'd = 3'
record_reading "$(fresh_agent)" "$(report "$repo" accept)" "$(briefed "$(git -C "$repo" diff --cached HEAD)")" >/dev/null
(cd "$repo" && git stash push -q --keep-index)
assert "an accepted staged part commits once the rest of its path is stashed" "$(gate 'git commit -m x')" ""
(cd "$repo" && git stash drop -q && git reset -q --hard)

edit README.md 'later'
land
edit d.py 'd = 4'
accepted="$(cat "$repo/d.py")"
accept_of d.py
(cd "$repo" && git reset -q --hard HEAD~ && printf '%s\n' "$accepted" >d.py)
assert "an accept recorded on a commit no longer behind HEAD is refused" "$(gate 'git commit -am x')" "$(denied 'd.py (working tree)')"
assert "that refusal says the path changed since its accept" "$(last_reason)" changed_since_accept

finish
