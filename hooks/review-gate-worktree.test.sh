#!/usr/bin/env bash
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/review-gate.test-harness.sh"

worktree="$scratch/topic"
(cd "$repo" && git worktree add -q -b topic "$worktree")
other="$scratch/other"
mkdir -p "$other/sub"
(cd "$other" && git init -q -b main && printf 'z = 1\n' >lib.py && git add -A && git commit -q -m base && printf 'z = 2\n' >>lib.py)

(cd "$worktree" && printf 'print(9)\n' >>app.py)
assert "a commit after cd into a worktree is gated against that worktree" "$(gate_from "cd $worktree && git add -A && git commit -m x" "$repo")" "$(denied 'app.py (working tree)')"
assert "a commit through git -C on a worktree is gated against that worktree" "$(gate_from "git -C $worktree commit -am x" "$repo")" "$(denied 'app.py (working tree)')"
record_handback "$(report "$worktree" accept)" >/dev/null
assert "an accept naming a worktree lets that worktree commit" "$(gate_from "cd $worktree && git add -A && git commit -m x" "$repo")" ""
assert "an accept naming a worktree approves nothing in another repo" "$(gate_from 'git commit -am x' "$other")" "$(denied 'lib.py (working tree)')"
(cd "$worktree" && printf 'print(11)\n' >>app.py)
record_handback "$(report "$other/sub" accept)" >/dev/null
assert "an accept naming a path outside the session's repo lets that repo commit" "$(gate_from 'git commit -am x' "$other")" ""
assert "an accept naming one repo approves nothing in another" "$(gate_from "cd $worktree && git add -A && git commit -m x" "$repo")" "$(denied 'app.py (working tree)')"
edit app.py 'print(10)'
assert "an accept for a worktree does not approve the main checkout" "$(gate 'git commit -am x')" "$(denied 'app.py (working tree)')"
mismatch="$(refused "The report cites files in '$(cd "$worktree" && pwd -P)', another worktree of '$repo', and none in '$repo'. Put the path of the worktree the change is in on the 'Repo:' line, not another checkout of its repository.")"
assert "an accept naming the main checkout while citing only a worktree's files keeps the reviewer running" \
  "$(record_handback "$(sections)"$'\nRead '"$worktree"$'/app.py:2.\nRepo: '"$repo"$'\nVerdict: accept')" "$mismatch"
assert "an accept citing a worktree's files approves nothing in the main checkout" "$(gate 'git commit -am x')" "$(denied 'app.py (working tree)')"
assert "a cited file that does not exist yet still places the worktree" \
  "$(record_handback "$(sections)"$'\nRead '"$worktree"$'/new/file.py.\nRepo: '"$repo"$'\nVerdict: accept')" "$mismatch"
assert "an accept citing files in both the main checkout and a worktree records" \
  "$(record_handback "$(sections)"$'\nRead '"$worktree"$'/app.py and '"$repo"$'/app.py.\nRepo: '"$repo"$'\nVerdict: accept')" ""
assert "an accept naming the worktree it cites records" \
  "$(record_handback "$(sections)"$'\nRead '"$worktree"$'/app.py.\nRepo: '"$worktree"$'\nVerdict: accept')" ""
(cd "$repo" && git tag v0.1.0)
assert "an accept for a worktree citing the repository's git dir records" \
  "$(record_handback "$(sections)"$'\nRead '"$repo"$'/.git/refs/tags/v0.1.0.\nRepo: '"$worktree"$'\nVerdict: accept')" ""
assert "an accept naming a worktree while citing only a main-checkout file records" \
  "$(record_handback "$(sections)"$'\nRead '"$repo"$'/README.md.\nRepo: '"$worktree"$'\nVerdict: accept')" ""
second="$scratch/second"
(cd "$repo" && git worktree add -q -b second "$second")
assert "an accept naming one linked worktree while citing only another's files keeps the reviewer running" \
  "$(record_handback "$(sections)"$'\nRead '"$second"$'/app.py.\nRepo: '"$worktree"$'\nVerdict: accept')" \
  "$(refused "The report cites files in '$(cd "$second" && pwd -P)', another worktree of '$worktree', and none in '$worktree'. Put the path of the worktree the change is in on the 'Repo:' line, not another checkout of its repository.")"

two_repos() { printf '%s\nRepo: %s\nVerdict: %s\nRepo: %s\n\nVerdict: %s' "$(sections)" "$1" "$2" "$3" "$4"; }
record_handback "$(two_repos "$worktree" accept "$other" accept)" >/dev/null
assert "a report naming two repos lets the first commit" "$(gate_from "cd $worktree && git add -A && git commit -m x" "$repo")" ""
assert "a report naming two repos lets the second commit" "$(gate_from 'git commit -am x' "$other")" ""
record_handback "$(two_repos "$worktree" return "$other" accept)" >/dev/null
assert "a return for the first of two repos clears its accept" "$(gate_from "cd $worktree && git add -A && git commit -m x" "$repo")" "$(denied 'app.py (working tree)')"
assert "an accept for the second of two repos still stands" "$(gate_from 'git commit -am x' "$other")" ""
assert "a Repo line with text between it and the verdict pairs with nothing" "$(record_handback "$(sections)"$'\nRepo: '"$repo"$'\nAll good.\nVerdict: accept')" "$(repo_refusal)"
assert "a verdict with no Repo line above it beside a paired one keeps the reviewer running" \
  "$(record_handback "$(sections)"$'\nRepo: '"$repo"$'\nVerdict: accept\nAll good.\nVerdict: return')" "$(repo_refusal)"
assert "two pairs naming one repository keep the reviewer running" \
  "$(record_handback "$(two_repos "$repo" return "$repo" accept)")" \
  "$(refused "'$repo' has more than one verdict. Give each repository one verdict: name it in one 'Repo:' line only.")"
record_handback "$(report "$repo" accept)" >/dev/null
record_handback "$(sections)"$'\nRepo: '"$repo"$'\nVerdict: return\nAll good.\nVerdict: return' >/dev/null
assert "a return beside an unpaired verdict still clears its accept" "$(gate 'git commit -am x')" "$(denied 'app.py (working tree)')"
record_handback "$(report "$repo" accept)" >/dev/null
record_handback "$(two_repos "$repo" return "$repo" accept)" >/dev/null
assert "a return beside a second pair for its repository still clears its accept" "$(gate 'git commit -am x')" "$(denied 'app.py (working tree)')"
record_handback "$(report "$repo" accept)" >/dev/null
record_handback "$(two_repos "$scratch/nowhere" accept "$repo" return)" >/dev/null
assert "a return after a pair naming no repository still clears its accept" "$(gate 'git commit -am x')" "$(denied 'app.py (working tree)')"
record_handback "$(report "$repo" accept)" >/dev/null
record_handback "$(sections)"$'\nAll good.\nVerdict: accept\nRepo: '"$repo"$'\nVerdict: return' >/dev/null
assert "a return after an unpaired verdict still clears its accept" "$(gate 'git commit -am x')" "$(denied 'app.py (working tree)')"
assert "a report with two bad pairs is denied for the first" \
  "$(record_handback "$(two_repos relative accept "$scratch/nowhere" accept)")" \
  "$(repo_refusal "'relative' is not an absolute path.")"
assert "a second pair naming no repository keeps the reviewer running" \
  "$(record_handback "$(two_repos "$worktree" accept "$scratch/nowhere" accept)")" \
  "$(repo_refusal "'$scratch/nowhere' is not a repository.")"
(cd "$worktree" && printf 'print(12)\n' >>app.py)
assert "an accept naming a checkout that holds none of its diff names the worktree that does" \
  "$(record_reading "$(fresh_agent)" "$(report "$repo" accept)" "$(briefed "$(diff_in "$worktree" app.py)")")" \
  "$(refused "None of app.py in the diff files you read matches what is staged or in the working tree of '$(cd "$repo" && pwd -P)', so this accept would cover nothing; they match the worktree '$(cd "$worktree" && pwd -P)'. Put the path of the worktree the change is in on the 'Repo:' line, not another checkout of its repository.")"
redirected="$(fresh_agent)"
staged_brief="$(briefed "$(diff_in "$worktree" app.py)")"
record_reading "$redirected" "$(report "$repo" accept)" "$staged_brief" >/dev/null
assert "a refused accept naming the wrong checkout lets the worktree commit nothing" "$(gate_from "cd $worktree && git add -A && git commit -m x" "$repo")" "$(denied 'app.py (working tree)')"
assert "that reviewer's accept naming the worktree it was pointed to records" \
  "$(record_reading "$redirected" "$(report "$worktree" accept)" "$staged_brief")" ""
assert "that accept lets the worktree commit" "$(gate_from "cd $worktree && git add -A && git commit -m x" "$repo")" ""

finish
