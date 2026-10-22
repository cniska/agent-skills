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

assert "a verdict with no Repo line keeps the reviewer running" "$(record_handback $'All good.\nVerdict: accept')" "$(repo_refusal)"
assert "an accept with no Repo line approves nothing" "$(gate 'git commit -am x')" "$(denied 'app.py (working tree)')"
assert "a Repo line that is not a repository keeps the reviewer running" "$(record_handback "$(report "$scratch/nowhere" accept)")" "$(repo_refusal "'$scratch/nowhere' is not a repository.")"
assert "a relative Repo path keeps the reviewer running" "$(record_handback "$(report repo accept)")" "$(repo_refusal "'repo' is not an absolute path.")"
assert "a missing Repo line on the second hand-back lets the reviewer hand back" "$(record_handback $'All good.\nVerdict: accept' again)" ""
assert "a reviewer stopped without a Repo line approved nothing" "$(gate 'git commit -am x')" "$(denied 'app.py (working tree)')"

assert "an accepting verdict records nothing to say" "$(record_handback "$(report "$repo" accept)")" ""
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

SAME_REVIEWER="$(refused "This accept is discarded: you returned this repository's change earlier, and the commit gate takes an accept only from a reviewer that has not. End your report with the line 'Start a fresh cniska-skills:reviewer on the fix's diff, with the change's earlier diff files to read as context; this one returned it.' above your verdict.")"
record_as returner "$(report "$repo" return)" >/dev/null
assert "an accept from the reviewer that returned keeps it running" "$(record_as returner "$(report "$repo" accept)")" "$SAME_REVIEWER"
assert "an accept from the reviewer that returned on its second hand-back lets it hand back" "$(record_as returner "$(report "$repo" accept)")" ""
assert "an accept from the reviewer that returned approves nothing" "$(gate 'git commit -am x')" "$(denied 'app.py (working tree)')"
assert "an accept from a fresh reviewer after the return records" "$(record_as fresh "$(report "$repo" accept)")" ""
assert "that fresh accept lets the diff commit" "$(gate 'git commit -am x')" ""

REVIEWED="$(refused "This agent gave a review verdict, and a message to it resumes the same reviewer rather than starting a fresh review. Start a fresh cniska-skills:reviewer on the fix's diff, with the change's earlier diff files to read as context.")"
message_to() {
  jq -cn --arg to "$1" '{hook_event_name: "PreToolUse", tool_name: "SendMessage", tool_input: {to: $to, message: "Please re-review the fix."}}' |
    "$HERE/reviewer-message.sh" 2>/dev/null
}
assert "a message to the reviewer that returned is refused" "$(message_to returner)" "$REVIEWED"
assert "a message to the reviewer that accepted is refused" "$(message_to fresh)" "$REVIEWED"
assert "a message to a reviewer named with its ref is refused" "$(message_to 'returner [3fa9c1]')" "$REVIEWED"
assert "a message to an agent with no verdict passes" "$(message_to worker)" ""
assert "a message to the main session passes" "$(message_to main)" ""
assert "a message passes unchecked without CLAUDE_PLUGIN_DATA" "$(CLAUDE_PLUGIN_DATA='' message_to returner)" ""
spare="$scratch/spare"
(cd "$scratch" && git init -q -b main spare)
assert "the reviewer that returned may accept another repository" "$(record_as returner "$(report "$spare" accept)")" ""
record_as returner "$(report "$repo" return)" >/dev/null

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
