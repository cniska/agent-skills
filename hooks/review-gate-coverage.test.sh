#!/usr/bin/env bash
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/review-gate.test-harness.sh"

(cd "$repo" && printf 'y = 1\n' >other.py && git add other.py && git commit -q -m other)
edit app.py 'print(30)'
edit other.py 'y = 2'
outside() {
  local pronoun=it
  [ "$#" -eq 1 ] || pronoun=them
  refused "Commit blocked: no diff cniska-skills:reviewer accepted covers $*, which this commit carries. A diff file covers a path only when the review brief names that file by its absolute path, the reviewer reads it, and the diff's new side is still the path's content. Write the current diff of $pronoun to a new file and brief a fresh reviewer naming that file by its absolute path, then commit once it ends with 'Verdict: accept', with no edits since."
}
record_reading "$(fresh_agent)" "$(report "$repo" accept)" "$(briefed "$(diff_in "$repo" app.py)")" >/dev/null
assert "an accept of one file's diff does not let a commit carry another changed file" "$(gate 'git commit -am x')" "$(outside other.py)"
record_reading "$(fresh_agent)" "$(report "$repo" accept)" "$(briefed "$(diff_in "$repo" other.py)")" >/dev/null
assert "a second accept of the same tree adds the paths of the diff it read" "$(gate 'git commit -am x')" ""
edit app.py 'print(32)'
record_reading "$(fresh_agent)" "$(report "$repo" accept)" "$(brief_line "$diffs/none.diff")" >/dev/null
assert "an accept by a reviewer that read no diff file approves no code" "$(gate 'git commit -am x')" "$(outside app.py other.py)"
edit app.py 'print(33)'
diff_in "$repo" app.py other.py >"$diffs/unbriefed.diff"
record_reading "$(fresh_agent)" "$(report "$repo" accept)" "$(brief_line "$diffs/none.diff" && read_of "$diffs/unbriefed.diff")" >/dev/null
assert "a diff file the reviewer read that the brief does not name approves no code" "$(gate 'git commit -am x')" "$(outside app.py other.py)"
stale="$(diff_in "$repo" app.py other.py)"
edit app.py 'print(34)'
record_reading "$(fresh_agent)" "$(report "$repo" accept)" "$(briefed "$stale")" >/dev/null
assert "a diff file whose new content is not the path's content now does not approve that path" "$(gate 'git commit -am x')" "$(outside app.py)"
first="$(transcript_of "$(diff_in "$repo" app.py other.py)")"
record_reading "$(fresh_agent)" "$(report "$repo" return)" "$(brief_line "$first" && read_of "$first")" >/dev/null
edit app.py 'print(35)'
fix="$(transcript_of "$(diff_in "$repo" app.py)")"
record_reading "$(fresh_agent)" "$(report "$repo" accept)" "$(brief_line "$fix" && read_of "$fix")" >/dev/null
assert "a re-review that read only the fix's diff does not cover the rest of the commit" "$(gate 'git commit -am x')" "$(outside other.py)"
edit app.py 'print(36)'
fix="$(transcript_of "$(diff_in "$repo" app.py)")"
record_reading "$(fresh_agent)" "$(report "$repo" accept)" "$(brief_line "$fix $first" && read_of "$fix" && read_of "$first")" >/dev/null
assert "a re-review that read the fix's diff and the commit's earlier one lets the commit through" "$(gate 'git commit -am x')" ""
land
(cd "$repo" && git mv other.py renamed.py)
record_reading "$(fresh_agent)" "$(report "$repo" accept)" "$(briefed "$(git -C "$repo" diff -M HEAD)")" >/dev/null
assert "an accept of git's own diff of an unedited move covers both paths" "$(gate 'git commit -m x')" ""
land
(cd "$repo" && git mv renamed.py other.py && printf 'y = 3\n' >>other.py && git add other.py)
record_reading "$(fresh_agent)" "$(report "$repo" accept)" "$(briefed "$(git -C "$repo" diff -M HEAD)")" >/dev/null
assert "an accept of git's own diff of an edited move covers both paths" "$(gate 'git commit -m x')" ""
land
(cd "$repo" && chmod +x other.py)
record_reading "$(fresh_agent)" "$(report "$repo" accept)" "$(briefed "$(git -C "$repo" diff HEAD)")" >/dev/null
assert "an accept of git's own diff of a mode change covers its path" "$(gate 'git commit -am x')" ""
mode_only="$(git -C "$repo" diff HEAD)"
edit other.py 'y = 4'
record_reading "$(fresh_agent)" "$(report "$repo" accept)" "$(briefed "$mode_only")" >/dev/null
assert "a diff that shows only a mode change does not approve its path once its content changed" "$(gate 'git commit -am x')" "$(outside other.py)"
land
(cd "$repo" && ln -s app.py link.py && git add link.py)
record_reading "$(fresh_agent)" "$(report "$repo" accept)" "$(briefed "$(git -C "$repo" diff HEAD)")" >/dev/null
assert "an accept of git's own diff of a new symlink covers its path" "$(gate 'git commit -m x')" ""
land
(cd "$repo" && ln -s nowhere.py dangling.py && git add dangling.py)
record_reading "$(fresh_agent)" "$(report "$repo" accept)" "$(briefed "$(git -C "$repo" diff HEAD)")" >/dev/null
(cd "$repo" && ln -sfn elsewhere.py dangling.py && git add dangling.py)
assert "retargeting an added symlink after the accept blocks the commit" "$(gate 'git commit -m x')" "$(denied)"
(cd "$repo" && git rm -q --cached dangling.py && rm dangling.py && printf 'z = 1\n' >added.py && git add added.py)
record_reading "$(fresh_agent)" "$(report "$repo" accept)" "$(briefed "$(git -C "$repo" diff HEAD)")" >/dev/null
(cd "$repo" && chmod +x added.py)
assert "a mode change to an added file after the accept blocks the commit" "$(gate 'git commit -m x')" "$(denied)"
land
(cd "$repo" && git rm -q added.py)
deleted="$(git -C "$repo" diff HEAD)"
(cd "$repo" && ln -s nowhere.py added.py && git add added.py)
record_reading "$(fresh_agent)" "$(report "$repo" accept)" "$(briefed "$deleted")" >/dev/null
assert "a diff deleting a path does not approve a dangling symlink put there" "$(gate 'git commit -m x')" "$(outside added.py)"
land
(cd "$repo" && printf 'w = 1\n' >fresh.py && git add fresh.py)
before_chmod="$(git -C "$repo" diff HEAD)"
(cd "$repo" && chmod +x fresh.py)
record_reading "$(fresh_agent)" "$(report "$repo" accept)" "$(briefed "$before_chmod")" >/dev/null
assert "a diff of a new file taken before a chmod does not approve the executable file" "$(gate 'git commit -m x')" "$(outside fresh.py)"
(cd "$repo" && git rm -q -f fresh.py && printf 'app.py' >linked.py && git add linked.py)
as_file="$(git -C "$repo" diff HEAD)"
(cd "$repo" && rm linked.py && ln -s app.py linked.py && git add linked.py)
record_reading "$(fresh_agent)" "$(report "$repo" accept)" "$(briefed "$as_file")" >/dev/null
assert "a diff of a file holding a link's target text does not approve the symlink" "$(gate 'git commit -m x')" "$(outside linked.py)"
land
(cd "$repo" && printf 'v = 1\n' >"$(printf 'caf\303\251 "q".py')" && git add -A)
record_reading "$(fresh_agent)" "$(report "$repo" accept)" "$(briefed "$(git -C "$repo" -c core.quotePath=true diff HEAD)")" >/dev/null
assert "an accept of git's own quoted diff of a non-ASCII path covers it" "$(gate 'git commit -m x')" ""
land
(cd "$repo" && git mv "$(printf 'caf\303\251 "q".py')" "$(printf 'd\303\251j\303\240.py')")
record_reading "$(fresh_agent)" "$(report "$repo" accept)" "$(briefed "$(git -C "$repo" -c core.quotePath=true diff -M HEAD)")" >/dev/null
assert "an accept of git's own quoted diff of a non-ASCII move covers both paths" "$(gate 'git commit -m x')" ""
land
(cd "$repo" && printf 'u = 1\n' >"$(printf 'a\\101 %% \303\251.py')" && git add -A)
record_reading "$(fresh_agent)" "$(report "$repo" accept)" "$(briefed "$(git -C "$repo" -c core.quotePath=true diff HEAD)")" >/dev/null
assert "an accept of git's own quoted diff of a name with a backslash before digits covers it" "$(gate 'git commit -m x')" ""

finish
