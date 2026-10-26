#!/usr/bin/env bash
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/review-gate.test-harness.sh"

(cd "$repo" && printf 'y = 1\n' >other.py && git add other.py && git commit -q -m other)
edit app.py 'print(30)'
edit other.py 'y = 2'
record_reading "$(fresh_agent)" "$(report "$repo" accept)" "$(briefed "$(diff_in "$repo" app.py)")" >/dev/null
assert "an accept of one file's diff does not let a commit carry another changed file" "$(gate 'git commit -am x')" "$(denied 'other.py (working tree)')"
record_reading "$(fresh_agent)" "$(report "$repo" accept)" "$(briefed "$(diff_in "$repo" other.py)")" >/dev/null
assert "a second accept of the same tree adds the paths of the diff it read" "$(gate 'git commit -am x')" ""
edit app.py 'print(32)'
record_reading "$(fresh_agent)" "$(report "$repo" accept)" "$(brief_line "$diffs/none.diff")" >/dev/null
assert "an accept by a reviewer that read no diff file approves no code" "$(gate 'git commit -am x')" "$(denied 'app.py (working tree)')"
edit app.py 'print(33)'
diff_in "$repo" app.py other.py >"$diffs/unbriefed.diff"
record_reading "$(fresh_agent)" "$(report "$repo" accept)" "$(brief_line "$diffs/none.diff" && read_of "$diffs/unbriefed.diff")" >/dev/null
assert "a diff file the reviewer read that the brief does not name approves no code" "$(gate 'git commit -am x')" "$(denied 'app.py (working tree)')"
diff_in "$repo" app.py other.py >"$diffs/prefix.diff"
record_reading "$(fresh_agent)" "$(report "$repo" accept)" "$(brief_line "$diffs/prefix.diff.old" && read_of "$diffs/prefix.diff")" >/dev/null
assert "a diff file whose path the brief names only inside a longer path approves no code" "$(gate 'git commit -am x')" "$(denied 'app.py (working tree)')"
stale="$(diff_in "$repo" app.py other.py)"
edit app.py 'print(34)'
record_reading "$(fresh_agent)" "$(report "$repo" accept)" "$(briefed "$stale")" >/dev/null
assert "a diff file whose new content is not the path's content now does not approve that path" "$(gate 'git commit -am x')" "$(denied 'app.py (working tree)')"
first="$(transcript_of "$(diff_in "$repo" app.py other.py)")"
record_reading "$(fresh_agent)" "$(report "$repo" return)" "$(brief_line "$first" && read_of "$first")" >/dev/null
edit app.py 'print(35)'
fix="$(transcript_of "$(diff_in "$repo" app.py)")"
record_reading "$(fresh_agent)" "$(report "$repo" accept)" "$(brief_line "$fix" && read_of "$fix")" >/dev/null
assert "a re-review that read only the fix's diff does not cover the rest of the commit" "$(gate 'git commit -am x')" "$(denied 'other.py (working tree)')"
edit app.py 'print(36)'
fix="$(transcript_of "$(diff_in "$repo" app.py)")"
record_reading "$(fresh_agent)" "$(report "$repo" accept)" "$(brief_line "$fix $first" && read_of "$fix" && read_of "$first")" >/dev/null
assert "a re-review that read the fix's diff and the commit's earlier one lets the commit through" "$(gate 'git commit -am x')" ""
edit app.py 'print(37)'
fix="$(transcript_of "$(diff_in "$repo" app.py)")"
record_reading "$(fresh_agent)" "$(report "$repo" accept)" "$(brief_line "$fix;$first" && read_of "$fix" && read_of "$first")" >/dev/null
assert "diff files a brief joins with a semicolon are each named" "$(gate 'git commit -am x')" ""
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
assert "a diff that shows only a mode change does not approve its path once its content changed" "$(gate 'git commit -am x')" "$(denied 'other.py (working tree)')"
land
(cd "$repo" && ln -s app.py link.py && git add link.py)
record_reading "$(fresh_agent)" "$(report "$repo" accept)" "$(briefed "$(git -C "$repo" diff HEAD)")" >/dev/null
assert "an accept of git's own diff of a new symlink covers its path" "$(gate 'git commit -m x')" ""
land
(cd "$repo" && ln -s nowhere.py dangling.py && git add dangling.py)
record_reading "$(fresh_agent)" "$(report "$repo" accept)" "$(briefed "$(git -C "$repo" diff HEAD)")" >/dev/null
(cd "$repo" && ln -sfn elsewhere.py dangling.py && git add dangling.py)
assert "retargeting an added symlink after the accept blocks the commit" "$(gate 'git commit -m x')" "$(denied 'dangling.py (staged and working tree)')"
(cd "$repo" && git rm -q --cached dangling.py && rm dangling.py && printf 'z = 1\n' >added.py && git add added.py)
record_reading "$(fresh_agent)" "$(report "$repo" accept)" "$(briefed "$(git -C "$repo" diff HEAD)")" >/dev/null
(cd "$repo" && chmod +x added.py)
assert "a mode change to an added file after the accept blocks the commit" "$(gate 'git commit -m x')" "$(denied 'added.py (working tree)')"
land
(cd "$repo" && git rm -q added.py)
deleted="$(git -C "$repo" diff HEAD)"
(cd "$repo" && ln -s nowhere.py added.py && git add added.py)
record_reading "$(fresh_agent)" "$(report "$repo" accept)" "$(briefed "$deleted")" >/dev/null
assert "a diff deleting a path does not approve a dangling symlink put there" "$(gate 'git commit -m x')" "$(denied 'added.py (staged and working tree)')"
land
(cd "$repo" && printf 'w = 1\n' >fresh.py && git add fresh.py)
before_chmod="$(git -C "$repo" diff HEAD)"
(cd "$repo" && chmod +x fresh.py)
record_reading "$(fresh_agent)" "$(report "$repo" accept)" "$(briefed "$before_chmod")" >/dev/null
assert "a diff of a new file taken before a chmod does not approve the executable file" "$(gate 'git commit -m x')" "$(denied 'fresh.py (working tree)')"
(cd "$repo" && git rm -q -f fresh.py && printf 'app.py' >linked.py && git add linked.py)
as_file="$(git -C "$repo" diff HEAD)"
(cd "$repo" && rm linked.py && ln -s app.py linked.py && git add linked.py)
record_reading "$(fresh_agent)" "$(report "$repo" accept)" "$(briefed "$as_file")" >/dev/null
assert "a diff of a file holding a link's target text does not approve the symlink" "$(gate 'git commit -m x')" "$(denied 'linked.py (staged and working tree)')"
land
(cd "$repo" && printf 'z = 1\n' >ita.py && git add -N ita.py)
record_reading "$(fresh_agent)" "$(report "$repo" accept)" "$(briefed "$(git -C "$repo" diff HEAD)")" >/dev/null
assert "an accept of the working diff of an intent-to-add file covers its path" "$(gate 'git add -A && git commit -m x')" ""
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
land
(cd "$repo" && mkdir gen lib && printf 'a = 1\n' >gen/bundle.js && printf '* linguist-generated\n' >gen/.gitattributes &&
  printf 'b = 1\n' >lib/code.py && printf 'off.js linguist-generated=false\nunset.js -linguist-generated\n' >.gitattributes &&
  printf 'c = 1\n' >off.js && printf 'd = 1\n' >unset.js && git add -A && git commit -q -m generated)
edit gen/bundle.js 'a = 2'
assert "a commit carrying only a path HEAD marks generated needs no accept" "$(gate 'git commit -am x')" ""
edit app.py 'print(40)'
record_reading "$(fresh_agent)" "$(report "$repo" accept)" "$(briefed "$(diff_in "$repo" app.py)")" >/dev/null
assert "an accept need not cover a path HEAD marks generated" "$(gate 'git commit -am x')" ""
edit gen/bundle.js 'a = 3'
assert "an edit to a generated path after the accept needs no accept" "$(gate 'git commit -am x')" ""
edit other.py 'y = 5'
record_reading "$(fresh_agent)" "$(report "$repo" accept)" "$(briefed "$(diff_in "$repo" app.py)")" >/dev/null
assert "a code path beside a generated one still needs the accept to cover it" "$(gate 'git commit -am x')" "$(denied 'other.py (working tree)')"
land
edit off.js 'c = 2'
assert "a path marked linguist-generated=false still needs an accept" "$(gate 'git commit -am x')" "$(denied 'off.js (working tree)')"
land
edit unset.js 'd = 2'
assert "a path marked -linguist-generated still needs an accept" "$(gate 'git commit -am x')" "$(denied 'unset.js (working tree)')"
land
edit gen/.gitattributes 'bundle.js -diff'
assert "a change to a .gitattributes HEAD marks generated still needs an accept" "$(gate 'git commit -am x')" "$(denied 'gen/.gitattributes (working tree)')"
land
edit .gitattributes 'app.py linguist-generated'
edit app.py 'print(41)'
record_reading "$(fresh_agent)" "$(report "$repo" accept)" "$(briefed "$(diff_in "$repo" .gitattributes)")" >/dev/null
assert "a marking only in a carried .gitattributes does not exempt its path" "$(gate 'git commit -am x')" "$(denied 'app.py (working tree)')"
(cd "$repo" && git add .gitattributes && rm .gitattributes)
record_reading "$(fresh_agent)" "$(report "$repo" accept)" "$(briefed "$(git -C "$repo" diff HEAD -- .gitattributes)")" >/dev/null
assert "a marking only in a staged .gitattributes does not exempt its path" "$(gate 'git commit -m x')" "$(denied 'app.py (working tree)')"
(cd "$repo" && git checkout -q HEAD -- .gitattributes)
land
(cd "$repo" && printf '* linguist-generated\n' >lib/.gitattributes)
edit lib/code.py 'b = 2'
assert "a marking only in an untracked .gitattributes does not exempt its path" "$(gate 'git commit -am x')" "$(denied 'lib/.gitattributes (working tree)' 'lib/code.py (working tree)')"
(cd "$repo" && printf 'lib/.gitattributes\n' >>.git/info/exclude)
assert "a marking only in an ignored .gitattributes does not exempt its path" "$(gate 'git commit -am x')" "$(denied 'lib/code.py (working tree)')"
(cd "$repo" && git checkout -q -b marks && git add -f lib/.gitattributes && git commit -q -m marks && git checkout -q main)
(cd "$repo" && git config attr.tree marks)
assert "a marking reached only through attr.tree does not exempt its path" "$(gate 'git commit -am x')" "$(denied 'lib/code.py (working tree)')"
(cd "$repo" && git config --unset attr.tree)
assert "a marking reached only through GIT_ATTR_SOURCE does not exempt its path" "$(GIT_ATTR_SOURCE=marks gate 'git commit -am x')" "$(denied 'lib/code.py (working tree)')"
land
attributes="$(git -C "$repo" rev-parse --path-format=absolute --git-common-dir)/info/attributes"
printf '# none\n\n' >"$attributes"
edit gen/bundle.js 'a = 4'
assert "comments in info/attributes leave the generated marking in force" "$(gate 'git commit -am x')" ""
printf 'app.py -diff\n' >>"$attributes"
assert "a line in info/attributes exempts nothing" "$(gate 'git commit -am x')" "$(denied 'gen/bundle.js (working tree)')"
rm "$attributes"
edit app.py 'print(42)'
record_reading "$(fresh_agent)" "$(report "$repo" accept)" "$(briefed "$(diff_in "$repo" app.py)")" >/dev/null
shims="$scratch/shims"
mkdir -p "$shims"
cat >"$shims/git" <<EOF
#!/usr/bin/env bash
case " \$* " in
  *" check-attr "*) ;;
  *) exec "$(command -v git)" "\$@" ;;
esac
case "\$GIT_SHIM" in
  exit) "$(command -v git)" "\$@"; exit 1 ;;
  short) "$(command -v git)" "\$@" | tr '\\0' '\\n' | tail -n +4 | tr '\\n' '\\0' ;;
  *) exec "$(command -v git)" "\$@" ;;
esac
EOF
chmod +x "$shims/git"
assert "the git shim passes a whole check-attr through" "$(GIT_SHIM=none PATH="$shims:$PATH" gate 'git commit -am x')" ""
assert "a check-attr that exits non-zero exempts nothing" "$(GIT_SHIM=exit PATH="$shims:$PATH" gate 'git commit -am x')" "$(denied 'gen/bundle.js (working tree)')"
assert "a check-attr that prints fewer lines than paths exempts nothing" "$(GIT_SHIM=short PATH="$shims:$PATH" gate 'git commit -am x')" "$(denied 'gen/bundle.js (working tree)')"
unborn="$scratch/unborn"
mkdir -p "$unborn"
(cd "$unborn" && git init -q -b main && printf '* linguist-generated\n' >.gitattributes && printf 'print(1)\n' >app.py && git add app.py)
assert "a code change in a repo with no commit yet still needs an accept" "$(gate_from 'git commit -m x' "$unborn")" "$(denied '.gitattributes (working tree)' 'app.py (staged and working tree)')"
(cd "$repo" && chmod -x other.py)
land
edit app.py 'print(50)'
edit other.py 'y = 6'
record_reading "$(fresh_agent)" "$(report "$repo" accept)" "$(briefed "$(diff_in "$repo" app.py)")" >/dev/null
record_reading "$(fresh_agent)" "$(report "$repo" accept)" "$(briefed "$(diff_in "$repo" other.py)")" >/dev/null
record_reading "$(fresh_agent)" "$(report "$repo" return)" "$(briefed "$(diff_in "$repo" other.py)")" >/dev/null
assert "a return voids the accept of the paths its diff covers and no other" "$(gate 'git commit -am x')" "$(denied 'other.py (working tree)')"
record_reading "$(fresh_agent)" "$(report "$repo" accept)" "$(briefed "$(diff_in "$repo" other.py)")" >/dev/null
unread="$(transcript_of "$(diff_in "$repo" app.py)")"
record_reading "$(fresh_agent)" "$(report "$repo" return)" "$(brief_line "$unread")" >/dev/null
assert "a return voids the paths of a diff its brief names that its reviewer never read" "$(gate 'git commit -am x')" "$(denied 'app.py (working tree)')"
record_reading "$(fresh_agent)" "$(report "$repo" accept)" "$(briefed "$(diff_in "$repo" app.py)")" >/dev/null
record_reading "$(fresh_agent)" "$(report "$repo" return)" "$(brief_line "$diffs/none.diff")" >/dev/null
assert "a return whose brief names no diff voids no accept" "$(gate 'git commit -am x')" ""

finish
