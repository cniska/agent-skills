#!/usr/bin/env bash
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/review-gate.test-harness.sh"

assert "a commit with nothing changed passes" "$(gate 'git commit -m x')" ""
edit app.py 'print(2)'
assert "an unreviewed code change blocks the commit" "$(gate 'git commit -am x')" "$(denied)"
assert "a command that is not a commit passes" "$(gate 'git status')" ""
assert "a commit word in another git command passes" "$(gate 'git log --grep commit')" ""
assert "a commit through an absolute git path is gated" "$(gate '/usr/bin/git -C . commit -m x')" "$(denied)"
assert "a commit after cd and && is gated" "$(gate "cd $repo && git commit -m x")" "$(denied)"

assert "a verdict with no Repo line keeps the reviewer running" "$(record_handback $'All good.\nVerdict: accept')" "$(repo_refusal)"
assert "an accept with no Repo line approves nothing" "$(gate 'git commit -am x')" "$(denied)"
assert "a Repo line that is not a repository keeps the reviewer running" "$(record_handback "$(report "$scratch/nowhere" accept)")" "$(repo_refusal "'$scratch/nowhere' is not a repository.")"
assert "a relative Repo path keeps the reviewer running" "$(record_handback "$(report repo accept)")" "$(repo_refusal "'repo' is not an absolute path.")"
assert "a missing Repo line on the second hand-back lets the reviewer hand back" "$(record_handback $'All good.\nVerdict: accept' again)" ""
assert "a reviewer stopped without a Repo line approved nothing" "$(gate 'git commit -am x')" "$(denied)"

assert "an accepting verdict records nothing to say" "$(record_handback "$(report "$repo" accept)")" ""
assert "an accepted diff commits" "$(gate 'git commit -am x')" ""
edit app.py 'print(3)'
assert "an edit after the accept blocks the commit" "$(gate 'git commit -am x')" "$(denied)"

land
edit app.py 'print(31)'

record_handback "$(report "$repo" accept)" >/dev/null
(cd "$repo" && printf 'x = 1\n' >new.py)
assert "a new untracked file after the accept blocks the commit" "$(gate 'git commit -am x')" "$(denied)"

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
assert "a returning verdict clears the accept" "$(gate 'git commit -am x')" "$(denied)"

SAME_REVIEWER="$(refused "This accept is discarded: you returned this repository's change earlier, and the commit gate takes an accept only from a reviewer that has not. End your report with the line 'Start a fresh cniska-skills:reviewer on the fix's diff, with the change's earlier diff files to read as context; this one returned it.' above your verdict.")"
record_as returner "$(report "$repo" return)" >/dev/null
assert "an accept from the reviewer that returned keeps it running" "$(record_as returner "$(report "$repo" accept)")" "$SAME_REVIEWER"
assert "an accept from the reviewer that returned on its second hand-back lets it hand back" "$(record_as returner "$(report "$repo" accept)")" ""
assert "an accept from the reviewer that returned approves nothing" "$(gate 'git commit -am x')" "$(denied)"
assert "an accept from a fresh reviewer after the return records" "$(record_as fresh "$(report "$repo" accept)")" ""
assert "that fresh accept lets the diff commit" "$(gate 'git commit -am x')" ""
spare="$scratch/spare"
(cd "$scratch" && git init -q -b main spare)
assert "the reviewer that returned may accept another repository" "$(record_as returner "$(report "$spare" accept)")" ""
record_as returner "$(report "$repo" return)" >/dev/null

finish
